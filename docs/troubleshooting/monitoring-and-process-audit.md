# 实时监控与进程审计

本文介绍实验室计算平台如何通过实时进程监控、Linux Audit 和 Slurm
作业记录，发现并追查疑似绕过 Slurm 直接运行计算程序的行为。

当前方案分为两部分：

-   **实时监控**：定期检查高 CPU、高内存和 GPU
    计算进程，并记录疑似不属于 Slurm 作业的进程。
-   **进程审计**：通过 `auditd`
    记录学生登录会话启动的程序，便于事后查询。

> **重要说明：** 监控或审计发现的进程不一定就是违规进程。VS
> Code、Shell、数据预处理等进程也可能在 Slurm
> 作业之外运行。需要结合进程的 cgroup、Slurm
> 作业记录和实际用途综合判断。本方案用于发现和追查，不会自动终止进程，也不会自动禁止用户绕过
> Slurm。

## 1. 工作原理

  ----------------------------------------------------------------------------------------------------------------------------------
  机制                主要用途                     记录内容                                     局限
  ------------------- ---------------------------- -------------------------------------------- ------------------------------------
  实时监控脚本        发现当前正在运行的可疑进程   PID、用户、资源使用率、进程名、cgroup 等     定时采样可能漏掉短时进程；cgroup
                                                                                                识别需要核实

  Linux               追查用户执行过哪些程序       执行事件、登录身份、程序路径和相关参数等     不直接判断是否违反 Slurm 使用规范
  Audit（`auditd`）                                                                             

  Slurm 作业记录      核实进程是否属于已提交作业   JobID、用户、账户、QOS、资源申请和作业状态   直接启动的普通进程通常不会自动成为
                                                                                                Slurm 作业记录
  ----------------------------------------------------------------------------------------------------------------------------------

实时监控和进程审计的职责不同，建议同时使用。

## 2. 实时监控

### 2.1 监控规则

监控脚本建议放在：

``` text
/usr/local/sbin/slurm-bypass-watch.sh
```

当前方案采用以下检查条件：

  -----------------------------------------------------------------------
  检查项                              条件
  ----------------------------------- -----------------------------------
  CPU                                 单个进程 CPU 使用率达到 30%

  内存                                单个进程内存占用达到系统内存的 5%

  GPU                                 检测到 NVIDIA GPU 计算进程

  用户范围                            UID 不小于 1001；管理员 `huang` 的
                                      UID 为 1000，不在该范围内

  检查频率                            每分钟执行一次

  告警位置                            systemd journal，标签为
                                      `slurm-bypass-watch`
  -----------------------------------------------------------------------

脚本会尝试根据 `/proc/<PID>/cgroup` 判断进程是否属于 Slurm
作业。未能识别到 Slurm 作业归属且符合资源阈值的进程会被记录为
**SUSPECT（疑似）**，并不代表已经确认违规。

> UID 范围是按当前服务器用户规划设置的。增加用户或调整 UID
> 分配规则后，应重新检查监控范围，避免遗漏学生或把服务账号纳入监控。

### 2.2 创建监控脚本

执行以下命令创建脚本：

``` bash
sudo tee /usr/local/sbin/slurm-bypass-watch.sh >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
set -eo pipefail

MIN_UID=1001
CPU_THRESHOLD=30
MEM_THRESHOLD=5

declare -A SEEN=()

is_slurm_job_pid() {
    local pid="$1"
    local cg
    cg="$(cat "/proc/${pid}/cgroup" 2>/dev/null)" || return 1

    grep -Eq \
      '(/slurm/uid_[0-9]+/job_[0-9]+/step_[^/]+|/job_[0-9]+/step_[^/]+|slurmstepd[^/]*/[^/]+/step_[^/]+)' \
      <<< "$cg"
}

report_if_suspicious() {
    local pid="$1"
    local reason="$2"
    local sample_cpu="${3:-n/a}"
    local sample_mem="${4:-n/a}"

    [[ "$pid" =~ ^[0-9]+$ ]] || return
    [[ -r "/proc/${pid}/status" ]] || return
    [[ -z "${SEEN[$pid]:-}" ]] || return

    local info uid user avgcpu mem elapsed comm cg
    info="$(ps -p "$pid" -o uid=,user=,%cpu=,%mem=,etime=,comm= 2>/dev/null)" || return
    read -r uid user avgcpu mem elapsed comm <<< "$info"

    [[ "${uid:-}" =~ ^[0-9]+$ ]] || return
    (( uid >= MIN_UID )) || return

    # 属于已识别 Slurm 作业 cgroup 的进程不作为候选告警
    if is_slurm_job_pid "$pid"; then
        return
    fi

    SEEN["$pid"]=1
    cg="$(tr '\n' ';' < "/proc/${pid}/cgroup" 2>/dev/null | cut -c1-180 || true)"

    logger -p daemon.warning -t slurm-bypass-watch \
      "SUSPECT user=$user uid=$uid pid=$pid reason=$reason sampled_cpu=${sample_cpu}% sampled_mem=${sample_mem}% avg_cpu=${avgcpu}% mem=${mem}% elapsed=$elapsed comm=$comm cgroup=$cg"
}

mapfile -t CPU_ROWS < <(
    LC_ALL=C top -b -n 2 -d 1 -w 200 2>/dev/null |
    awk -v cpu="$CPU_THRESHOLD" -v mem="$MEM_THRESHOLD" '
      /^top - / { snapshot++; next }
      snapshot >= 2 &&
      $1 ~ /^[0-9]+$/ &&
      (($9 + 0) >= cpu || ($10 + 0) >= mem) {
          printf "%s|%s|%s\n", $1, $9, $10
      }
    ' |
    sort -t'|' -k1,1n -u
)

for row in "${CPU_ROWS[@]}"; do
    IFS='|' read -r pid cpu mem <<< "$row"
    report_if_suspicious "$pid" "CPU_OR_MEMORY" "$cpu" "$mem"
done

if command -v nvidia-smi >/dev/null 2>&1; then
    while IFS=',' read -r pid process_name gpu_mem; do
        pid="${pid//[[:space:]]/}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        report_if_suspicious "$pid" "GPU" "n/a" "n/a"
    done < <(
        nvidia-smi \
          --query-compute-apps=pid,process_name,used_memory \
          --format=csv,noheader 2>/dev/null || true
    )
fi
SCRIPT

sudo chmod 750 /usr/local/sbin/slurm-bypass-watch.sh
```

该脚本只读取进程信息并写入日志，不会自动终止进程，也不会修改 Slurm
配置。

### 2.3 配置每分钟自动检查

创建 systemd 服务：

``` bash
sudo tee /etc/systemd/system/slurm-bypass-watch.service >/dev/null <<'EOF'
[Unit]
Description=Detect suspicious user processes outside Slurm
After=slurmd.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/slurm-bypass-watch.sh
EOF
```

创建定时器：

``` bash
sudo tee /etc/systemd/system/slurm-bypass-watch.timer >/dev/null <<'EOF'
[Unit]
Description=Run Slurm bypass monitor every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
AccuracySec=15s
Unit=slurm-bypass-watch.service

[Install]
WantedBy=timers.target
EOF
```

启用定时器：

``` bash
sudo systemctl daemon-reload
sudo systemctl enable --now slurm-bypass-watch.timer
```

检查是否启用：

``` bash
systemctl list-timers slurm-bypass-watch.timer
sudo systemctl status slurm-bypass-watch.timer --no-pager
```

### 2.4 查看实时监控日志

查看今天的告警：

``` bash
sudo journalctl -t slurm-bypass-watch --since today --no-pager
```

持续观察新告警：

``` bash
sudo journalctl -t slurm-bypass-watch -f
```

手动执行一次检查：

``` bash
sudo /usr/local/sbin/slurm-bypass-watch.sh
```

没有输出不一定代表配置失败：可能当前没有满足阈值的可疑进程，也可能采样时进程已经结束。

### 2.5 查看并核实进程

查看 CPU 使用率较高的进程：

``` bash
ps -eo user,pid,ppid,etime,%cpu,%mem,args --sort=-%cpu | head -30
```

查看 GPU 计算进程：

``` bash
nvidia-smi
```

也可以只列出 GPU 计算进程：

``` bash
nvidia-smi \
  --query-compute-apps=pid,process_name,used_memory \
  --format=csv
```

拿到 PID 后，查看用户和命令行：

``` bash
sudo ps -ww -p <PID> -o user,pid,ppid,etime,%cpu,%mem,args
```

将 `<PID>` 替换为实际进程号。

查看当前 Slurm 作业：

``` bash
squeue -o "%.18i %.12u %.12P %.10T %.30j"
```

查看今天的作业记录：

``` bash
sacct -S today \
  --format=JobID,User,Account,Partition,QOS,State,Elapsed,AllocCPUS
```

查看目标进程的 cgroup：

``` bash
sudo cat /proc/<PID>/cgroup
```

如果已找到对应的 JobID，可以查看作业进程：

``` bash
scontrol listpids <JOBID>
```

Slurm 不同版本、cgroup v1/v2 和 systemd 集成方式可能导致 cgroup
路径不同。因此，不要只凭路径中是否出现某个固定字符串就认定违规；应结合
`squeue`、`sacct`、进程用户和作业状态进行确认。

### 2.6 调整监控阈值

编辑脚本：

``` bash
sudo nano /usr/local/sbin/slurm-bypass-watch.sh
```

脚本开头的参数为：

``` bash
MIN_UID=1001
CPU_THRESHOLD=30
MEM_THRESHOLD=5
```

例如，将 CPU 阈值提高到 50%，可以改为：

``` bash
CPU_THRESHOLD=50
```

阈值越低，越容易发现轻负载进程，但也可能产生更多无关告警。修改后保存即可，下次定时执行时会使用新配置。

## 3. 进程审计（auditd）

### 3.1 安装并启动

在 Ubuntu 服务器上执行：

``` bash
sudo apt update
sudo apt install -y auditd audispd-plugins
sudo systemctl enable --now auditd
sudo systemctl status auditd --no-pager
```

`auditd` 负责把内核审计事件写入日志；`auditctl`
用于查看或管理当前审计规则，`ausearch` 和 `aureport`
用于查询与汇总审计记录。

### 3.2 当前审计规则

规则文件：

``` text
/etc/audit/rules.d/50-lab-user-exec.rules
```

当前规则内容：

``` text
# 64-bit program execution
-a always,exit -F arch=b64 -S execve -F auid>=1001 -F auid!=4294967295 -k lab_user_exec
-a always,exit -F arch=b64 -S execveat -F auid>=1001 -F auid!=4294967295 -k lab_user_exec

# 32-bit program execution on x86_64
-a always,exit -F arch=b32 -S execve -F auid>=1001 -F auid!=4294967295 -k lab_user_exec
-a always,exit -F arch=b32 -S execveat -F auid>=1001 -F auid!=4294967295 -k lab_user_exec
```

规则对审计登录 UID（`auid`）不小于 1001 的程序执行事件进行记录，并使用
`lab_user_exec` 作为查询键。`auid!=4294967295` 用于排除未设置登录 UID
的事件。

检查规则是否已加载：

``` bash
sudo auditctl -l | grep lab_user_exec
```

查看审计子系统状态：

``` bash
sudo auditctl -s
```

重新加载规则文件：

``` bash
sudo augenrules --load
```

> 规则文件中的规则在重新加载后生效。若系统使用不可变审计模式或规则加载失败，应先检查
> `auditctl -s`、`augenrules --load`
> 的输出和系统日志，不要直接反复追加重复规则。

### 3.3 查询执行记录

查询今天的学生程序执行事件：

``` bash
sudo ausearch -k lab_user_exec -ts today -i | less
```

查询 `wlc`（当前 UID 为 1001）的审计登录身份对应的事件：

``` bash
sudo ausearch -ua 1001 -k lab_user_exec -ts today -i
```

查询某个时间段：

``` bash
sudo ausearch -k lab_user_exec \
  -ts 10:00:00 -te 12:00:00 -i
```

查看程序执行事件汇总：

``` bash
sudo aureport -x --summary -i
```

查看程序执行报告：

``` bash
sudo aureport -x --start today -i
```

审计日志通常保存在：

``` text
/var/log/audit/audit.log
```

应限制该目录的读取权限，只允许授权管理员查看，因为日志可能包含程序参数或其他敏感信息。

### 3.4 为什么查询结果是 `<no matches>`？

例如：

``` text
sudo ausearch -ua 1001 -k lab_user_exec -ts today -i
<no matches>
```

这表示在指定条件和时间范围内没有找到匹配事件，不一定意味着审计规则没有生效。按顺序检查：

**第一步：确认规则已经加载**

``` bash
sudo auditctl -l | grep lab_user_exec
```

**第二步：确认 auditd 正在运行**

``` bash
sudo systemctl status auditd --no-pager
sudo auditctl -s
```

查看 `auditctl -s` 输出中的 `lost` 和 `backlog`。`lost`
非零表示有审计记录丢失，需要进一步调查；`backlog`
表示当前等待处理的事件数量。`backlog_wait_time_actual 0`
本身不是"规则没有生效"的结论，应结合完整状态输出判断。

**第三步：通过真实的学生 SSH 会话产生一条新事件**

不要仅使用管理员会话中的 `sudo -iu wlc` 来验证基于 `auid` 的规则。`auid`
是登录审计身份，切换有效用户通常不会把原始登录身份改成目标用户。

使用学生自己的 SSH 账号登录服务器后，执行：

``` bash
id
cat /proc/self/loginuid
/usr/bin/id
```

如果 `wlc` 的 UID 为 1001，正常的登录审计身份通常应显示为
`1001`。如果显示 `4294967295`，表示登录 UID
未设置，这类会话不会匹配当前规则。

**第四步：重新查询刚刚产生的事件**

``` bash
sudo ausearch -k lab_user_exec -ts recent -i
```

也可以检查原始审计日志：

``` bash
sudo grep 'lab_user_exec' /var/log/audit/audit.log | tail -20
```

如果仍然没有记录，请检查 `auditctl -l`
中规则的架构、系统是否支持相应系统调用，以及 `auditd` 和规则加载日志。

### 3.5 审计范围与限制

当前规则审计的是 `execve` 和 `execveat`
系统调用，也就是程序执行事件。它可以记录常见的
`python`、`bash`、`srun`、`git` 等外部程序启动，但不等于记录 Shell
中的每一条内建命令，也不记录程序内部发生的所有操作。

另外：

-   规则只匹配符合 `auid` 条件的会话。
-   短时程序也可能被审计记录，但前提是规则已生效且事件没有丢失。
-   审计记录不会自动判断程序是否属于违规计算。
-   进程审计可能增加日志量，需要定期检查日志占用和轮转设置。

## 4. 进程记账（可选）

如果还希望查询已经结束的进程及其 CPU 时间，可以启用 Linux
进程记账。它是补充功能，不代替 `auditd`。

安装：

``` bash
sudo apt install -y acct
```

查看近期进程记账记录：

``` bash
sudo lastcomm | head -50
```

进程记账主要提供已结束进程的命令名、用户和资源使用统计等信息，不等同于完整命令行审计。启用前应确认本机
`acct` 服务状态及其记账文件配置。

## 5. 发现疑似绕过 Slurm 时的排查流程

建议按照以下顺序处理：

1.  从实时监控日志中获取用户、PID、进程名和触发原因。
2.  使用 `ps`、`nvidia-smi` 查看进程当前的实际资源使用情况。
3.  查看 `/proc/<PID>/cgroup`，并用 `squeue`、`sacct` 和
    `scontrol listpids` 核对 Slurm 作业归属。
4.  使用 `ausearch -k lab_user_exec` 查询该用户在相关时间启动的程序。
5.  核对是否属于 VS
    Code、交互式开发、数据预处理或其他获准的非计算作业进程，再判断是否需要处理。

**不要仅凭一个监控告警或一条审计记录就认定用户违规。**
如果确实需要限制学生只能通过 Slurm
运行高负载任务，应另外规划会话限制、cgroup
和权限策略；本页的监控与审计配置本身不会阻止程序执行。

## 6. 常用命令速查

  -----------------------------------------------------------------------------------------------------
  目的                                命令
  ----------------------------------- -----------------------------------------------------------------
  查看监控定时器                      `systemctl list-timers slurm-bypass-watch.timer`

  查看实时监控告警                    `sudo journalctl -t slurm-bypass-watch --since today`

  查看高 CPU 进程                     `ps -eo user,pid,etime,%cpu,%mem,args --sort=-%cpu \| head -30`

  查看 GPU 进程                       `nvidia-smi`

  查看当前 Slurm 作业                 `squeue`

  查看今天的作业记录                  `sacct -S today`

  查看审计规则                        `sudo auditctl -l`

  查看审计状态                        `sudo auditctl -s`

  查询学生程序执行事件                `sudo ausearch -k lab_user_exec -ts today -i`

  查看执行事件汇总                    `sudo aureport -x --summary -i`

  查看近期进程记账（如已启用）        `sudo lastcomm`
  -----------------------------------------------------------------------------------------------------

## 7. 参考资料

-   [实验室计算平台：Slurm QOS
    与分级资源管理](https://willantern.github.io/lab-handbook/cluster/slurm-qos/)
-   [Slurm cgroups 文档](https://slurm.schedmd.com/cgroups.html)
-   [Linux `auditctl`
    手册](https://man7.org/linux/man-pages/man8/auditctl.8.html)
-   [Linux `auditd`
    手册](https://man7.org/linux/man-pages/man8/auditd.8.html)
-   [Linux `ausearch`
    手册](https://man7.org/linux/man-pages/man8/ausearch.8.html)

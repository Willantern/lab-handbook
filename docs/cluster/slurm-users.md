# Slurm 用户管理与账户配置

本文介绍实验室计算平台的用户体系、现有用户、账户层级，以及新增用户和分配 Slurm 资源权限的流程。

## 1. 用户管理的基本概念

Slurm 用户管理涉及两个相互关联但彼此独立的体系。

### 1.1 Linux 系统用户

Linux 系统用户用于：

- SSH 登录服务器。
- 拥有个人主目录。
- 管理个人文件和实验代码。
- 在授权范围内执行程序。
- 使用 Slurm 提交作业。

创建 Linux 用户通常使用：

```bash
sudo adduser USERNAME
```

### 1.2 Slurm 记账用户

Slurm 记账用户用于管理：

- 用户所属账户。
- 默认 QOS。
- 可以使用的 QOS。
- 作业资源限制。
- 作业优先级及资源使用统计。

创建 Slurm 记账用户不会自动创建 Linux 系统用户，反之亦然。

因此，新用户需要分别完成 Linux 用户创建和 Slurm 账户关联。

## 2. 查看当前 Linux 用户

学生账户不应默认获得 sudo 权限。系统管理任务应由经过授权的管理员执行。

查看 Linux 用户：

```bash
getent passwd | awk -F: \
  '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {
    printf "%-16s UID=%-6s HOME=%-25s SHELL=%s\n",
           $1, $3, $6, $7
  }'
```

查看单个用户：

```bash
id hzx
id wlc
```

## 3. Slurm 账户层级

当前账户结构如下：

```text
root
└── lab
    ├── admin
    │   └── huang
    ├── undergrad
    │   └── 本科生用户
    ├── master
    │   └── 硕士生用户
    └── phd
        ├── hzx
        └── wlc
```

其中，`undergrad`、`master` 和 `phd` 是按照学生等级划分的 Slurm 账户。实际学生用户需要关联到相应账户。

账户层级与 Fairshare 配置：

| 账户 | 父账户 | Fairshare |
|---|---|---:|
| `lab` | `root` | 默认 |
| `admin` | `lab` | 1 |
| `undergrad` | `lab` | 1 |
| `master` | `lab` | 2 |
| `phd` | `lab` | 4 |

Fairshare 是调度公平性计算的一个因素。上述数值表达不同账户的相对权重，并不直接保证固定的 CPU 或 GPU 配额。

## 4. 新增用户的完整流程

以新增本科生 `student01` 为例。

### 4.1 创建 Linux 用户

```bash
sudo adduser student01
```

按照提示设置密码和用户信息。该命令通常会创建用户的个人主目录。

如需生成 24 位十六进制临时密码，可使用：

```bash
openssl rand -hex 12
```

该命令输出 24 个十六进制字符。应通过安全渠道交付临时密码，不要将其写入公开文档或代码仓库。

确认用户创建成功：

```bash
id student01
```

### 4.2 创建 Slurm 用户关联

为本科生创建 Slurm 账户关联，并设置默认 QOS：

```bash
sudo sacctmgr -i add user \
  Name=student01 \
  Account=undergrad \
  Cluster=lab-cluster \
  QOS=undergrad_qos \
  DefaultQOS=undergrad_qos
```

### 4.3 授予弹性 QOS 权限

本科生还可以在需要更多资源时主动选择 `undergrad_burst`：

```bash
sudo sacctmgr -i modify user \
  where name=student01 \
  set QOS+=undergrad_burst
```

完成后，用户默认仍使用 `undergrad_qos`，只有明确指定弹性 QOS 时才使用更高的资源上限。

### 4.4 硕士生和博士生的配置

| 学生等级 | Slurm 账户 | 默认 QOS | 弹性 QOS |
|---|---|---|---|
| 本科生 | `undergrad` | `undergrad_qos` | `undergrad_burst` |
| 硕士生 | `master` | `master_qos` | `master_burst` |
| 博士生 | `phd` | `phd_qos` | `phd_burst` |

创建硕士生时，将上面本科生命令中的账户与 QOS 替换为：

```bash
sudo sacctmgr -i add user \
  Name=student02 \
  Account=master \
  Cluster=lab-cluster \
  QOS=master_qos \
  DefaultQOS=master_qos

sudo sacctmgr -i modify user \
  where name=student02 \
  set QOS+=master_burst
```

创建博士生时：

```bash
sudo sacctmgr -i add user \
  Name=student03 \
  Account=phd \
  Cluster=lab-cluster \
  QOS=phd_qos \
  DefaultQOS=phd_qos

sudo sacctmgr -i modify user \
  where name=student03 \
  set QOS+=phd_burst
```

将 `student02`、`student03` 替换为真实用户名。

以上 `add user` 命令适用于尚未建立 Slurm 关联的新用户。如果 Linux 用户或 Slurm 关联已经存在，应先检查现有状态，再使用 `modify user` 更新，不要重复创建。

### 4.5 自动开户

创建脚本

```bash

cat > ~/create-lab-user.sh <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ==========================================
# 实验室用户管理配置
# ==========================================
CLUSTER="lab-cluster"
ADMIN="huang"
CRED_DIR="/home/huang/lab-user-credentials"

# 磁盘配额：50 GiB
QUOTA_MOUNT="/"
QUOTA_GIB=50
QUOTA_KIB=$((QUOTA_GIB * 1024 * 1024))

# 必须使用 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "错误：请使用 sudo 执行此脚本。" >&2
    exit 1
fi

# ==========================================
# 参数检查
# ==========================================
if [[ $# -ne 2 ]]; then
    echo "用法：sudo ~/create-lab-user.sh <用户名> <等级>"
    echo
    echo "等级：undergrad | master | phd"
    echo "示例：sudo ~/create-lab-user.sh zyh phd"
    exit 1
fi

USERNAME="$1"
LEVEL="${2,,}"

if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "错误：用户名格式不合法。"
    exit 1
fi

# ==========================================
# 学生等级与 Slurm 配置映射
# ==========================================
case "$LEVEL" in
    undergrad|本科生)
        LEVEL_NAME="本科生"
        ACCOUNT="undergrad"
        DEFAULT_QOS="undergrad_qos"
        BURST_QOS="undergrad_burst"
        ;;
    master|硕士生)
        LEVEL_NAME="硕士生"
        ACCOUNT="master"
        DEFAULT_QOS="master_qos"
        BURST_QOS="master_burst"
        ;;
    phd|博士生)
        LEVEL_NAME="博士生"
        ACCOUNT="phd"
        DEFAULT_QOS="phd_qos"
        BURST_QOS="phd_burst"
        ;;
    *)
        echo "错误：等级必须是 undergrad、master 或 phd。" >&2
        exit 1
        ;;
esac

# ==========================================
# 检查依赖
# ==========================================
for cmd in useradd userdel chpasswd chage openssl \
           sacctmgr setquota quotaon install; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "错误：找不到必要命令 $cmd" >&2
        exit 1
    fi
done

if ! getent passwd "$ADMIN" >/dev/null; then
    echo "错误：管理员 Linux 用户 $ADMIN 不存在。" >&2
    exit 1
fi

# ==========================================
# 检查磁盘用户配额是否已启用
# ==========================================
QUOTA_STATUS="$(quotaon -p "$QUOTA_MOUNT" 2>&1 || true)"

if ! grep -Eq '^user quota on / .* is on$' \
    <<< "$QUOTA_STATUS"; then
    echo "错误：根文件系统 / 的用户磁盘配额尚未启用。" >&2
    echo "请先检查 /etc/fstab、挂载参数和 quotaon 状态。" >&2
    printf '%s\n' "$QUOTA_STATUS" >&2
    exit 1
fi

# ==========================================
# 检查 Linux 用户及 Slurm 用户关联
# ==========================================
if getent passwd "$USERNAME" >/dev/null; then
    echo "错误：Linux 用户 $USERNAME 已存在。" >&2
    exit 1
fi

if sacctmgr -nP show assoc where user="$USERNAME" format=User |
    grep -Fxq "$USERNAME"; then
    echo "错误：Slurm 中已存在用户 $USERNAME 的关联。" >&2
    exit 1
fi

# ==========================================
# 检查 Slurm 集群、账户和 QOS
# ==========================================
check_entry() {
    local expected="$1"
    shift

    local result
    result="$("$@")"

    if ! grep -Fxq -- "$expected" <<< "$result"; then
        echo "错误：Slurm 配置中不存在 $expected。" >&2
        exit 1
    fi
}

check_entry "$CLUSTER" \
    sacctmgr -nP show cluster format=Cluster

check_entry "$ACCOUNT" \
    sacctmgr -nP show account format=Account

check_entry "$DEFAULT_QOS" \
    sacctmgr -nP show qos format=Name

check_entry "$BURST_QOS" \
    sacctmgr -nP show qos format=Name

# ==========================================
# 初始化失败清理状态
# ==========================================
USER_CREATED=0
SLURM_ASSOC_CREATED=0
CRED_FILE=""

cleanup_failed_creation() {
    local reason="$1"

    echo "错误：${reason}" >&2
    echo "正在清理本次创建的资源……" >&2

    if [[ -n "$CRED_FILE" ]]; then
        rm -f -- "$CRED_FILE" || true
    fi

    if [[ "$SLURM_ASSOC_CREATED" -eq 1 ]]; then
        sacctmgr -i delete user \
            where name="$USERNAME" \
            cluster="$CLUSTER" \
            account="$ACCOUNT" >/dev/null 2>&1 || true
    fi

    if [[ "$USER_CREATED" -eq 1 ]]; then
        setquota -u "$USERNAME" 0 0 0 0 \
            "$QUOTA_MOUNT" >/dev/null 2>&1 || true

        userdel -r "$USERNAME" >/dev/null 2>&1 || true
    fi

    echo "清理流程已执行；请检查系统状态确认清理结果。" >&2
    exit 1
}

# ==========================================
# 生成 24 位随机初始密码
# ==========================================
PASSWORD="$(openssl rand -hex 12)"

# 创建密码记录目录
if ! install -d -o "$ADMIN" -g "$ADMIN" -m 0700 "$CRED_DIR"; then
    echo "错误：无法创建密码记录目录。" >&2
    exit 1
fi

# ==========================================
# 创建 Linux 用户
# ==========================================
if ! useradd -m -s /bin/bash "$USERNAME"; then
    echo "错误：Linux 用户创建失败。" >&2
    exit 1
fi
USER_CREATED=1

if ! printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd; then
    cleanup_failed_creation "设置初始密码失败。"
fi

# 首次登录时要求修改密码
if ! chage -d 0 "$USERNAME"; then
    cleanup_failed_creation "设置首次登录改密策略失败。"
fi

# ==========================================
# 设置个人磁盘配额
# 软限制和硬限制均为 50 GiB
# 管理员 huang 不设置个人配额
# ==========================================
if [[ "$USERNAME" != "$ADMIN" ]]; then
    if ! setquota -u "$USERNAME" \
        "$QUOTA_KIB" "$QUOTA_KIB" 0 0 "$QUOTA_MOUNT"; then
        cleanup_failed_creation "设置 ${QUOTA_GIB} GiB 磁盘配额失败。"
    fi
fi

# ==========================================
# 创建 Slurm 用户关联
# ==========================================
if ! sacctmgr -i add user \
    Name="$USERNAME" \
    Account="$ACCOUNT" \
    Cluster="$CLUSTER" \
    QOS="$DEFAULT_QOS" \
    DefaultQOS="$DEFAULT_QOS"; then
    cleanup_failed_creation "Slurm 用户关联创建失败。"
fi
SLURM_ASSOC_CREATED=1

# 授权使用该等级的弹性 QOS
if ! sacctmgr -i modify user \
    where name="$USERNAME" \
    set QOS+="$BURST_QOS"; then
    cleanup_failed_creation "弹性 QOS 授权失败。"
fi

# ==========================================
# 保存初始密码
# ==========================================
CRED_FILE="${CRED_DIR}/${USERNAME}_$(date +%Y%m%d_%H%M%S).txt"

if ! {
    printf '用户名：%s\n' "$USERNAME"
    printf '密码：%s\n' "$PASSWORD"
    printf '学生等级：%s\n' "$LEVEL_NAME"
    printf 'Slurm账户：%s\n' "$ACCOUNT"
    printf '默认QOS：%s\n' "$DEFAULT_QOS"
    printf '弹性QOS：%s\n' "$BURST_QOS"
    printf '磁盘配额：%s GiB\n' "$QUOTA_GIB"
} > "$CRED_FILE"; then
    cleanup_failed_creation "写入密码记录失败。"
fi

if ! chown "$ADMIN:$ADMIN" "$CRED_FILE" ||
   ! chmod 600 "$CRED_FILE"; then
    cleanup_failed_creation "设置密码记录文件权限失败。"
fi

# ==========================================
# CLI 输出
# ==========================================
echo
echo "=========================================="
echo "             用户创建成功"
echo "=========================================="
echo
echo "【账号凭据】"
printf "用户名：%s\n" "$USERNAME"
printf "密码：%s\n" "$PASSWORD"
echo
echo "【用户信息】"
printf "学生等级：%s\n" "$LEVEL_NAME"
printf "Linux 家目录：/home/%s\n" "$USERNAME"
printf "磁盘配额：%s GiB\n" "$QUOTA_GIB"
echo
echo "【Slurm 配置】"
printf "集群：%s\n" "$CLUSTER"
printf "Slurm 账户：%s\n" "$ACCOUNT"
printf "默认 QOS：%s\n" "$DEFAULT_QOS"
printf "弹性 QOS：%s\n" "$BURST_QOS"
echo
echo "【密码记录】"
printf "%s\n" "$CRED_FILE"
echo
echo "=========================================="
echo "请通过安全渠道交付初始密码。"
echo "用户首次登录时需要修改密码。"
echo "=========================================="
SCRIPT

chmod 750 ~/create-lab-user.sh
```

### 4.6 一键开户
博士生
``sudo ~/create-lab-user.sh wlc phd``

硕士生
``sudo ~/create-lab-user.sh wlc master``

本科生
``sudo ~/create-lab-user.sh wlc undergrad``
### 4.7 删除用户

删除slurm用户关联
```bash
sudo sacctmgr delete user \
    where name=zyh cluster=lab-cluster account=phd
```
删除linux用户
```bash
sudo userdel -r zyh
```
删除该用户的初始密码记录
```bash
sudo find /home/huang/lab-user-credentials \
    -maxdepth 1 -type f -name 'zyh_*.txt' -print
```
确认列出的文件确实属于该用户后，再删除：

```bash
sudo find /home/huang/lab-user-credentials \
    -maxdepth 1 -type f -name 'zyh_*.txt' -delete
```
最后检查:
```bash
id zyh
sudo sacctmgr show assoc where user=zyh
```

## 5. 查看和检查用户配置

查看 Linux 用户：

```bash
id student01
```

查看用户的 Slurm 关联：

```bash
sudo sacctmgr show assoc \
  where user=student01 \
  format=Cluster,Account,User,Fairshare,QOS,DefaultQOS
```

查看某个等级的用户：

```bash
sudo sacctmgr show assoc \
  where account=phd \
  format=Cluster,Account,User,Fairshare,QOS,DefaultQOS
```

查看账户：

```bash
sudo sacctmgr show account format=Account,Descr
```

查看 QOS：

```bash
sudo sacctmgr show qos \
  format=Name,Priority,MaxJobsPU,MaxSubmitPU,MaxWall
```

## 6. 用户提交作业的示例

普通博士生作业：

```bash
sbatch \
  --partition=compute \
  --account=phd \
  --qos=phd_qos \
  --cpus-per-task=8 \
  --mem=16G \
  --time=12:00:00 \
  experiment.sbatch
```

博士生弹性资源作业：

```bash
sbatch \
  --partition=compute \
  --account=phd \
  --qos=phd_burst \
  --cpus-per-task=96 \
  --mem=160G \
  --gres=gpu:2 \
  --time=2-00:00:00 \
  experiment.sbatch
```

第二个示例申请更多资源，但能否立即启动取决于当时的资源可用情况及调度优先级。

## 7. 管理原则

1. 每位学生都应有独立的 Linux 用户。
2. 学生默认不加入 `sudo` 组。
3. 每位学生关联到对应的 Slurm 等级账户。
4. 使用默认 QOS 进行普通实验。
5. 只有确实需要更大资源时，才使用弹性 QOS。
6. 学生毕业、离组或账户权限变化时，应及时调整其 Linux 登录权限和 Slurm 账户关联。
7. 不应在 MkDocs、脚本仓库或公开文档中保存用户密码。

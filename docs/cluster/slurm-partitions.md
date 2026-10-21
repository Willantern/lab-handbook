# Slurm 分区配置与使用

分区（Partition）是 Slurm 中组织作业队列和调度策略的基本单位。不同分区可以设置不同的运行时间、允许使用的节点、访问权限和默认策略。

当前服务器只有一个计算节点 `server1`，因此 `compute` 和 `debug` 分区共享同一台物理服务器。

## 1. 当前分区

执行以下命令查看当前分区：

```bash
sinfo -o "%P %a %l %D %t %N"
```

当前配置如下：

| 分区 | 默认分区 | 节点 | 最长运行时间 | 用途 |
|---|---|---|---|---|
| `compute` | 是 | `server1` | 3 天 | 正式实验与长时间计算 |
| `debug` | 否 | `server1` | 30 分钟 | 短时测试、调试及交互任务 |

对应的 `/etc/slurm/slurm.conf` 配置为：

```ini
# General compute partition for research workloads
PartitionName=compute Nodes=server1 Default=YES MaxTime=3-00:00:00 State=UP

# Short interactive testing and debugging
PartitionName=debug Nodes=server1 Default=NO MaxTime=00:30:00 State=UP
```

`Default=YES` 表示用户未指定分区时，Slurm 默认使用该分区。

## 2. 分区参数说明

| 参数 | 含义 |
|---|---|
| `PartitionName` | 分区名称 |
| `Nodes` | 分区包含的计算节点 |
| `Default` | 是否为默认分区 |
| `MaxTime` | 单个作业允许的最长运行时间 |
| `State` | 分区状态，`UP` 表示可用 |
| `AllowAccounts` | 可使用该分区的账户，可选 |
| `AllowGroups` | 可使用该分区的 Linux 用户组，可选 |
| `OverSubscribe` | 是否允许对 CPU 等资源进行超额共享 |

当前两个分区没有按学生等级分开，而是通过 QOS 管理本科生、硕士生和博士生的资源限制。

这是适合当前单节点实验室服务器的简单架构。

## 3. 修改分区配置

### 3.1 备份配置文件

修改前先备份：

```bash
sudo cp -a /etc/slurm/slurm.conf \
  "/etc/slurm/slurm.conf.bak.$(date +%Y%m%d-%H%M%S)"
```

### 3.2 编辑配置文件

```bash
sudoedit /etc/slurm/slurm.conf
```

找到已有的 `PartitionName=` 配置，将其修改为目标配置。

注意：不要在保留旧分区定义的情况下重复追加同名分区。修改后应确认文件中只有一组预期的分区定义：

```bash
grep '^PartitionName=' /etc/slurm/slurm.conf
```

### 3.3 重新加载配置

```bash
sudo scontrol reconfigure
```

### 3.4 验证结果

```bash
sinfo -o "%P %a %l %D %t %N"

scontrol show partition compute
scontrol show partition debug
```

分区参数修改后，通常可以通过 `scontrol reconfigure` 重新加载，无须重启整台服务器。

## 4. 提交作业时选择分区

### 4.1 正式计算

```bash
sbatch \
  --partition=compute \
  --time=1-00:00:00 \
  experiment.sbatch
```

### 4.2 调试任务

```bash
srun \
  --partition=debug \
  --ntasks=1 \
  --cpus-per-task=2 \
  --mem=2G \
  --time=00:05:00 \
  hostname
```

调试任务的运行时间不能超过 `debug` 分区的 30 分钟限制。

### 4.3 在作业脚本中指定分区

也可以在 `experiment.sbatch` 中写入：

```bash
#!/bin/bash
#SBATCH --job-name=my-experiment
#SBATCH --partition=compute
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=12:00:00

python train.py
```

## 5. 分区与 QOS 的关系

分区和 QOS 负责不同层面的策略：

- **分区：** 决定作业进入哪个队列，以及适用的节点范围和运行时间上限。
- **QOS：** 决定作业的等级、优先级、资源限额及作业数量限制。
- **账户：** 确定用户所属的资源管理层级。

作业需要同时满足分区和 QOS 的限制。例如，博士生即使使用 `phd_burst`，如果选择 `debug` 分区，最长运行时间仍然只有 30 分钟。

当前两个分区使用同一个节点，不代表它们分别拥有独立的 CPU、内存或 GPU 配额。物理资源由 Slurm 的节点资源管理和作业分配机制统一管理。

## 6. 后续扩展建议

未来增加计算节点时，可以根据硬件或任务类型增加专用分区，例如：

- CPU 密集型计算分区。
- GPU 计算分区。
- 短时调试分区。
- 高内存任务分区。

新增分区前，应先明确节点归属、访问权限、最长运行时间以及是否需要与其他分区共享节点资源。对于当前单节点架构，不必仅仅为了区分本科生、硕士生和博士生而创建三个独立分区。

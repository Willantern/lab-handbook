# Slurm 常用命令

## 1. Slurm 是什么？

Slurm 是集群工作负载管理器，负责接收作业、分配计算资源、调度任务并管理作业运行状态。

实验室服务器当前使用单节点配置：

- 节点：`server1`
- 分区：`debug`
- CPU：256 个逻辑线程
- GPU：4 张 NVIDIA GeForce RTX 4090
- Slurm 版本：26.05.5

这些硬件信息仅描述当前服务器配置，具体可用资源以 Slurm 实时报告为准。

## 2. 查看集群状态

```bash
# 查看分区
sinfo

# 查看节点及资源
sinfo -N -o "%N %c %m %t %G"

# 查看控制器状态
scontrol ping

# 查看节点详情
scontrol show node server1
```

## 3. 查看作业

```bash
# 查看自己的作业
squeue -u "$USER"

# 查看所有排队和运行中的作业
squeue

# 查看作业状态及等待原因
squeue -u "$USER" -o "%.18i %.12j %.10T %.12M %.30R"

# 查看作业详细信息
scontrol show job JOB_ID
```

将 `JOB_ID` 替换为实际作业编号。

## 4. 提交批处理作业

Slurm 批处理脚本通常使用 `.sbatch` 或 `.sh` 后缀。

示例：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=cpu-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=cpu-%j.out
#SBATCH --error=cpu-%j.err

set -euo pipefail

echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"

python3 -c "print('Hello from Slurm')"
```

提交：

```bash
sbatch cpu-test.sbatch
```

`%j` 会被替换为作业编号。

## 5. 常用资源申请参数

| 参数 | 作用 |
|---|---|
| `--partition=debug` | 指定分区 |
| `--nodes=1` | 申请 1 个节点 |
| `--ntasks=1` | 申请 1 个任务 |
| `--cpus-per-task=4` | 每个任务申请 4 个 CPU |
| `--mem=8G` | 申请 8 GiB 内存 |
| `--gres=gpu:1` | 申请 1 张 GPU |
| `--time=00:30:00` | 最长运行时间 30 分钟 |
| `--output=job-%j.out` | 标准输出日志 |
| `--error=job-%j.err` | 标准错误日志 |

应根据任务的实际需求申请资源。作业申请到的资源不等于程序一定会充分使用这些资源。

## 6. 提交 GPU 作业

在脚本中加入：

```bash
#SBATCH --gres=gpu:1
```

Python 程序可以检查：

```bash
echo "$CUDA_VISIBLE_DEVICES"
nvidia-smi -L
```

对于 PyTorch：

```python
import torch

print(torch.__version__)
print(torch.cuda.is_available())

if torch.cuda.is_available():
    print(torch.cuda.get_device_name(0))
```

当前服务器已启用 Slurm cgroup 资源约束，并已验证申请单张 GPU 的作业无法打开其他未分配 GPU 的设备文件。

注意：作业中 `CUDA_VISIBLE_DEVICES` 的编号是进程可见的设备编号，不应简单视为主机上的固定物理 GPU 编号。

## 7. 交互式作业

需要临时交互式调试时，可以使用：

```bash
srun \
  --partition=debug \
  --nodes=1 \
  --ntasks=1 \
  --cpus-per-task=4 \
  --mem=8G \
  --gres=gpu:1 \
  --time=00:30:00 \
  --pty bash
```

进入分配的计算环境后，可以运行：

```bash
hostname
echo "$CUDA_VISIBLE_DEVICES"
nvidia-smi
```

退出 shell 后，交互式作业通常会结束。

不要在没有申请 GPU 的普通 SSH 会话中直接启动长期 GPU 训练。

## 8. 取消作业

```bash
# 取消指定作业
scancel JOB_ID

# 取消自己所有排队和运行中的作业
scancel -u "$USER"
```

执行前应确认作业编号，避免误取消其他实验。

## 9. 查看日志和运行结果

```bash
cat cpu-123.out
cat cpu-123.err
```

实时查看日志：

```bash
tail -f cpu-123.out
```

查看作业详细状态：

```bash
scontrol show job 123
```

如果作业已经退出，应重点检查日志、退出码和程序输出。

## 10. 常见问题

### 作业处于 Pending

```bash
squeue -u "$USER" -o "%.18i %.10T %.30R"
```

查看等待原因。可能是资源不足、作业申请的资源超出节点配置，或者分区策略限制。

### 作业运行失败

检查 `.out` 和 `.err` 日志，并确认脚本中的环境初始化、输入路径和资源申请正确。

### `sacct` 无法查询历史作业

当前服务器尚未启用 Slurm accounting storage，因此历史作业统计可能不可用。可以使用日志和 `scontrol show job` 查看仍可获得的信息。

## 11. 使用规范

- 长时间计算通过 Slurm 提交。
- 不要申请超过任务需要的资源。
- 不要在没有授权的情况下绕过调度器使用 GPU。
- 重要实验保留日志、参数和代码版本。
- 不要将密码、密钥或私人数据写入公开仓库。

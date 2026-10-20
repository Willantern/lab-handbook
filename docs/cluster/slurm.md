# 使用 Slurm 提交作业

## 常用命令

| 命令 | 用途 |
|---|---|
| `sbatch job.sbatch` | 提交批处理作业 |
| `squeue -u "$USER"` | 查看自己的排队和运行中作业 |
| `scontrol show job <jobid>` | 查看作业详情 |
| `scancel <jobid>` | 取消作业 |
| `sacct -j <jobid>` | 查看已结束作业的状态与资源使用情况 |
| `sinfo` | 查看分区和节点状态 |

## CPU 作业模板

将下面内容保存为 `cpu-test.sbatch`：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=cpu-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --output=cpu-test-%j.out
#SBATCH --error=cpu-test-%j.err

set -euo pipefail

echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"

python -c 'import os; print("CPU test passed", os.cpu_count())'
```

提交并查看：

```bash
sbatch cpu-test.sbatch
squeue -u "$USER"
```

`debug` 是示例分区名，请替换为管理员提供的有效分区。作业的 CPU、内存和时长限制也以实际策略为准。

## GPU 作业申请

常见的单 GPU 申请方式如下，但 GPU 资源声明可能因集群配置不同而变化：

```bash
#SBATCH --gres=gpu:1
```

提交前确认节点 GPU 状态及实验室的 GPU 使用规则。不要通过直接启动后台进程绕过 Slurm 调度。

## 排查作业失败

```bash
scontrol show job <jobid>
sacct -j <jobid> --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,MaxRSS
cat <job-output-file>
cat <job-error-file>
```

记录 Job ID、退出码、相关日志和复现命令，方便管理员定位问题。

# PyTorch GPU 作业

本页给出一个通用模板。它假定管理员已经准备好 Apptainer、Lmod 模块和可运行的 PyTorch SIF 镜像。模块名、分区和路径必须按实际部署调整。

## Slurm 脚本

保存为 `pytorch-gpu.sbatch`：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=torch-train
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --time=02:00:00
#SBATCH --output=torch-%j.out
#SBATCH --error=torch-%j.err

set -euo pipefail

# 按实际 Lmod 安装路径调整
source /etc/profile.d/z00_lmod.sh
module load pytorch/2.14.1-cuda13.2

export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"

apptainer exec --nv \
  --bind "$HOME/project:/workspace" \
  --bind "/data/datasets:/data/datasets:ro" \
  "$PYTORCH_SIF" \
  python /workspace/train.py
```

提交作业：

```bash
sbatch pytorch-gpu.sbatch
squeue -u "$USER"
```

## 运行前检查

1. 确认 `module avail pytorch` 中存在指定模块。
2. 确认模块提供的 `PYTORCH_SIF` 文件存在且可读。
3. 确认代码目录、数据集路径和输出路径正确。
4. 先运行小型 GPU smoke test，再启动长时间训练。
5. 保存依赖版本、随机种子、提交脚本、日志和模型输出。

## 重要说明

示例中的 PyTorch 模块只是模板，只有管理员创建并验证了对应模块和镜像后才能使用。不要将示例版本视为当前集群已安装的软件。

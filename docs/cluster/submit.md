# Slurm 作业提交指南

本文介绍如何在实验室服务器上通过 Slurm 提交 CPU、GPU 和 PyTorch 计算任务，以及如何查看作业状态、获取运行日志和处理常见问题。

## 1. 基本原则

实验室服务器使用 Slurm 管理计算资源。运行较长时间的训练、仿真、批量实验和 GPU 计算时，应优先通过 Slurm 提交作业。

- 使用 `sbatch` 提交批处理作业。
- 使用 `srun` 启动交互式计算任务。
- 使用 `squeue` 查看排队和运行中的作业。
- 使用 `scancel` 取消自己的作业。
- 使用 `module` 加载公共软件环境。

不要默认所有 GPU 都可以直接使用。提交作业时应明确申请所需的 CPU、内存、GPU 和运行时间。

## 2. 查看集群状态

查看可用节点和分区：

```bash
sinfo
```

查看详细节点资源：

```bash
sinfo -N -o "%N %c %m %t %G"
```

查看自己的作业：

```bash
squeue -u "$USER"
```

查看所有用户的作业（需要相应权限）：

```bash
squeue
```

当前服务器使用单节点配置，节点名为 `server1`，当前分区为 `debug`。分区名称和资源配置以服务器实际配置为准。

## 3. 提交 CPU 作业

创建一个测试脚本：

```bash
mkdir -p ~/slurm-jobs
cd ~/slurm-jobs

cat > cpu-test.sbatch <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=cpu-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=cpu-test-%j.out
#SBATCH --error=cpu-test-%j.err

set -euo pipefail

echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo "Allocated CPUs: $SLURM_CPUS_PER_TASK"

python3 - <<'PY'
import os
print("Python CPU affinity:",
      len(os.sched_getaffinity(0)))
print("CPU test passed")
PY
EOF
```

提交作业：

```bash
sbatch cpu-test.sbatch
```

提交后，Slurm 会返回一个作业编号，例如：

```text
Submitted batch job 123
```

其中 `123` 是本次作业的 Job ID。

## 4. 提交 GPU 作业

GPU 作业需要显式申请 GPU。以下示例申请 1 张 GPU、4 个 CPU 线程和 8 GiB 内存。

创建脚本：

```bash
cat > gpu-test.sbatch <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=gpu-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH --time=00:10:00
#SBATCH --output=gpu-test-%j.out
#SBATCH --error=gpu-test-%j.err

set -euo pipefail

echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

nvidia-smi -L

EOF
```

提交作业：

```bash
sbatch gpu-test.sbatch
```

注意：`--gres=gpu:1` 表示申请 1 张 GPU，而不是指定物理 GPU 编号。实际分配由 Slurm 决定。

不要在脚本中自行假设一定会获得 GPU 0。

## 5. 使用公共 Conda 环境运行 PyTorch

服务器提供公共软件模块，可以通过 Lmod 加载 Conda。

先查看可用模块：

```bash
module avail
```

加载公共 Anaconda：

```bash
module load conda/2026
```

查看 Conda 版本：

```bash
conda --version
```

在作业脚本中，应显式初始化模块并激活所需环境。下面以服务器已有的 `server-test` 环境为例；该环境用于测试，不代表所有研究任务都应使用这个环境。

创建 `pytorch-gpu.sbatch`：

```bash
cat > pytorch-gpu.sbatch <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=torch-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH --time=00:10:00
#SBATCH --output=torch-%j.out
#SBATCH --error=torch-%j.err

set -euo pipefail

source /etc/profile.d/z00_lmod.sh
module load conda/2026

source "$CONDA_ROOT/etc/profile.d/conda.sh"
conda activate /opt/apps/anaconda3/envs/server-test

echo "Python: $(which python)"
echo "Conda environment: $CONDA_PREFIX"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

python - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if not torch.cuda.is_available():
    raise RuntimeError("CUDA is not available")

print("GPU:", torch.cuda.get_device_name(0))

a = torch.randn(2048, 2048, device="cuda")
b = torch.randn(2048, 2048, device="cuda")
c = a @ b

print("Result shape:", tuple(c.shape))
print("CUDA test passed")
PY
EOF
```

提交作业：

```bash
sbatch pytorch-gpu.sbatch
```

如果需要其他 PyTorch 版本，请使用对应的环境或容器，不要随意修改公共环境中的包。

## 6. 查看作业状态和日志

查看自己的作业：

```bash
squeue -u "$USER"
```

查看指定作业的详细信息：

```bash
scontrol show job <JOB_ID>
```

查看输出日志：

```bash
cat torch-<JOB_ID>.out
cat torch-<JOB_ID>.err
```

实时查看日志：

```bash
tail -f torch-<JOB_ID>.out
```

取消自己的作业：

```bash
scancel <JOB_ID>
```

请将 `<JOB_ID>` 替换为实际作业编号，不要直接输入尖括号。

当前服务器尚未启用 Slurm accounting storage，因此 `sacct` 可能无法查询历史作业统计。需要查看作业结果时，可以先使用作业日志和 `scontrol show job`。

## 7. 常见问题

### 作业一直处于 Pending

查看原因：

```bash
squeue -u "$USER" -o "%.18i %.12j %.10T %.30R"
```

常见原因包括资源不足、请求的 GPU 数量过多，以及作业时间或分区限制。

### CUDA 不可用

在作业日志中检查：

```bash
nvidia-smi
echo "$CUDA_VISIBLE_DEVICES"
python -c "import torch; print(torch.cuda.is_available())"
```

同时确认已经申请 GPU，并激活了安装有兼容 PyTorch CUDA 版本的环境。

### 找不到 `module` 命令

在 Bash 作业脚本中初始化 Lmod：

```bash
source /etc/profile.d/z00_lmod.sh
module avail
```

### 作业运行失败

查看 `.out` 和 `.err` 文件，并检查脚本中的环境路径、依赖、输入文件路径和资源申请是否正确。

## 8. 使用规范

1. 长时间训练和批量计算应通过 Slurm 运行。
2. 根据实际需求申请 CPU、内存和 GPU，不要过量申请资源。
3. 重要实验应保存代码版本、运行参数、随机种子和日志。
4. 不要修改公共软件环境；需要额外依赖时，优先创建个人 Conda 环境或使用容器。
5. 不要将密码、访问令牌或其他敏感信息提交到公开代码仓库。
6. 提交大规模实验前，先使用小规模作业验证程序可以正常运行。

本指南中的分区名称、软件模块和环境路径以当前服务器配置为例，管理员可能根据后续集群建设进行调整。

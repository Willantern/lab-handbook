# Apptainer

## 1. Apptainer 是什么？

Apptainer 是面向 HPC 和科研计算场景的容器运行工具。它可以将 Python、PyTorch、CUDA 用户态库及其他依赖打包进镜像，帮助不同项目使用相对独立的软件环境。

与 Docker 不同，Apptainer 常用于普通用户在共享计算集群上运行容器，不要求每个用户都拥有 Docker daemon 的管理权限。

Apptainer 可以与 Slurm 配合使用：

- Slurm 负责分配 CPU、内存和 GPU。
- Apptainer 负责提供容器内的软件环境。
- `--nv` 用于让容器访问 NVIDIA GPU 及宿主机提供的相关驱动库。

Apptainer 不会代替 Slurm，也不应被当作资源调度器。

## 2. 加载 Apptainer 模块

```bash
module load apptainer/1.5.4

apptainer --version
apptainer help
```

查看当前模块：

```bash
module list
```

## 3. SIF 镜像的基本概念

Apptainer 常用 `.sif` 作为容器镜像文件。

例如：

```text
pytorch-2.6.sif
pytorch-2.7.sif
```

上述名称仅为示例，不代表服务器已经存在这些镜像。

公共镜像通常由管理员统一构建并设置为只读。用户可以在自己的目录中保存个人镜像，或者通过绑定目录向容器提供自己的代码和数据。

## 4. 下载镜像

如果网络允许访问镜像仓库，可以使用：

```bash
apptainer pull alpine.sif docker://alpine:3.20
```

也可以拉取指定的容器镜像：

```bash
apptainer pull pytorch.sif docker://pytorch/pytorch:TAG
```

其中 `TAG` 必须替换为实际存在且符合需求的镜像标签。

注意：容器仓库可能受到网络、DNS、代理或访问权限限制。如果服务器无法直接下载，可以在允许访问仓库的机器上获取镜像，再将 SIF 文件传到服务器。

不要在没有验证来源的情况下运行未知镜像。

## 5. 查看和运行镜像

查看镜像信息：

```bash
apptainer inspect image.sif
```

查看容器内文件：

```bash
apptainer exec image.sif ls /
```

执行容器内的 Python：

```bash
apptainer exec image.sif python --version
```

进入容器交互式 shell：

```bash
apptainer shell image.sif
```

退出 shell：

```bash
exit
```

上述命令中的 `image.sif` 应替换为实际镜像路径。

## 6. 绑定代码和数据目录

推荐将代码和数据保留在宿主机上，通过绑定目录提供给容器使用。

例如：

```bash
mkdir -p ~/projects/my-project
mkdir -p ~/datasets
mkdir -p ~/results
```

运行容器：

```bash
apptainer exec \
  --bind "$HOME/projects/my-project:/workspace" \
  --bind "$HOME/datasets:/datasets:ro" \
  --bind "$HOME/results:/results" \
  image.sif \
  python /workspace/train.py
```

绑定路径含义：

| 宿主机路径 | 容器内路径 | 用途 |
|---|---|---|
| `~/projects/my-project` | `/workspace` | 代码 |
| `~/datasets` | `/datasets` | 数据集，只读 |
| `~/results` | `/results` | 实验输出 |

`:ro` 表示容器内只读挂载。它适合保护数据集不被意外修改。

## 7. 在容器中使用 NVIDIA GPU

对于 NVIDIA GPU，通常需要添加 `--nv`：

```bash
apptainer exec --nv image.sif \
  python -c \
  "import torch; print(torch.cuda.is_available())"
```

该命令能否成功，取决于镜像内的 PyTorch、CUDA 用户态库与宿主机 NVIDIA 驱动是否兼容。

容器并不会自动提供所有宿主机驱动，也不会保证任意 CUDA 版本都能正常运行。

## 8. 通过 Slurm 运行 Apptainer

容器作业仍然需要通过 Slurm 申请资源。

下面是一个模板。使用前请将 `IMAGE` 改成管理员提供的实际 SIF 路径。

```bash
#!/usr/bin/env bash
#SBATCH --job-name=container-test
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH --time=00:10:00
#SBATCH --output=container-%j.out
#SBATCH --error=container-%j.err

set -euo pipefail

source /etc/profile.d/z00_lmod.sh
module load apptainer/1.5.4

IMAGE="/path/to/pytorch.sif"

echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

apptainer exec \
  --nv \
  --bind "$PWD:/workspace" \
  "$IMAGE" \
  python /workspace/test.py
```

提交：

```bash
sbatch container-test.sbatch
```

Slurm 负责 GPU 资源分配和作业级设备访问约束，Apptainer 则提供容器中的软件环境。容器不应被用于绕过 Slurm 的资源分配策略。

## 9. 镜像存储与权限

管理员可以将公共镜像集中存放在类似下面的目录：

```text
/opt/apps/containers/
```

该目录是建议的目录结构示例，需由管理员实际创建和配置。

公共镜像通常应由管理员维护，普通用户只读使用。个人修改应通过个人镜像或新的容器构建完成，而不是直接覆盖公共镜像。

## 10. 常见问题

### 下载镜像失败

检查网络和镜像标签。如果服务器无法访问容器仓库，可以从可访问的机器获取镜像后再传输。

### 容器中 CUDA 不可用

检查：

```bash
nvidia-smi
apptainer exec --nv image.sif python -c \
  "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

同时确认 Slurm 作业申请了 GPU。

### 无法修改公共镜像

这是正常的权限保护。请将镜像复制到个人目录，或重新构建自己的镜像。

### 容器找不到数据集

确认绑定参数中的宿主机路径存在，且当前用户有权限访问：

```bash
ls -lah "$HOME/datasets"
```

### 容器运行失败

检查镜像路径、容器内程序路径、依赖兼容性以及 `.out` 和 `.err` 日志。

## 11. 使用规范

- 优先使用经过验证的公共镜像。
- 不要将个人数据和密码写入公共镜像。
- 将代码、数据和实验结果通过绑定目录管理。
- 记录镜像版本或摘要，以便复现实验。
- GPU 容器作业仍应通过 Slurm 提交。
- 不要修改公共镜像或尝试绕过资源约束。

# Conda

## 1. Conda 是什么？

Conda 是用于管理 Python 环境及其依赖的软件工具。它允许不同项目使用不同的 Python 版本和依赖包，减少项目之间的依赖冲突。

实验室服务器通过 Lmod 提供公共 Conda 安装：

```bash
module load conda/2026
```

公共 Conda 安装路径为：

```text
/opt/apps/anaconda3
```

当前测试环境的路径为：

```text
/opt/apps/anaconda3/envs/server-test
```

`server-test` 是现有的测试环境，不建议把所有研究项目都放进这个环境。

## 2. 初始化 Conda

加载公共模块：

```bash
module load conda/2026
```

检查 Conda：

```bash
conda --version
which conda
echo "$CONDA_ROOT"
```

初始化当前 shell 的 Conda 功能：

```bash
source "$CONDA_ROOT/etc/profile.d/conda.sh"
```

查看环境：

```bash
conda env list
```

## 3. 创建个人环境

建议将个人环境放在自己的主目录中，避免修改公共环境。

例如，创建 Python 3.12 环境：

```bash
conda create \
  --prefix "$HOME/.conda/envs/my-project" \
  python=3.12 \
  -y
```

激活环境：

```bash
conda activate "$HOME/.conda/envs/my-project"
```

检查 Python 路径：

```bash
which python
python --version
```

退出环境：

```bash
conda deactivate
```

使用完整路径创建个人环境，可以避免个人环境和公共环境重名时产生歧义。

## 4. 安装和查看依赖

```bash
# 查看已安装包
conda list

# 安装 Conda 包
conda install numpy scipy

# 使用 pip 安装 Python 包
python -m pip install requests

# 查看 pip 包
python -m pip list
```

建议优先使用与当前环境兼容的 Conda 包。确实需要通过 pip 安装时，应使用当前环境对应的 Python：

```bash
python -m pip install PACKAGE_NAME
```

不要使用 `sudo pip install`，也不要将个人依赖直接安装进公共环境。

## 5. 查看、删除和复制环境

查看环境：

```bash
conda env list
```

删除个人环境：

```bash
conda env remove \
  --prefix "$HOME/.conda/envs/my-project"
```

删除前确认环境路径，避免误删仍在使用的实验环境。

克隆个人环境：

```bash
conda create \
  --prefix "$HOME/.conda/envs/my-project-copy" \
  --clone "$HOME/.conda/envs/my-project"
```

环境克隆需要额外磁盘空间。

## 6. 导出实验环境

记录环境依赖：

```bash
conda env export \
  --prefix "$HOME/.conda/envs/my-project" \
  > environment.yml
```

也可以只记录通过 Conda 显式安装的包：

```bash
conda env export \
  --prefix "$HOME/.conda/envs/my-project" \
  --from-history \
  > environment.yml
```

在其他环境中重建：

```bash
conda env create \
  --prefix "$HOME/.conda/envs/my-project-copy" \
  --file environment.yml
```

环境文件不保证在所有操作系统、硬件和软件渠道上完全一致。对于需要精确复现的研究，还应记录 Python、CUDA、PyTorch 和驱动版本。

## 7. 使用公共 PyTorch 测试环境

服务器现有测试环境：

```bash
module load conda/2026
source "$CONDA_ROOT/etc/profile.d/conda.sh"

conda activate /opt/apps/anaconda3/envs/server-test
```

检查 PyTorch：

```bash
python -c \
  "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

当前测试环境已经验证 PyTorch CUDA 可以在 RTX 4090 上执行矩阵运算。

公共环境主要用于共享和测试。研究项目如需安装不同版本的包，建议创建个人环境或使用管理员提供的容器镜像。

## 8. 在 Slurm 中运行 Conda

批处理脚本中应显式加载模块并初始化 Conda：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=conda-test
#SBATCH --partition=debug
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=conda-%j.out

set -euo pipefail

source /etc/profile.d/z00_lmod.sh
module load conda/2026

source "$CONDA_ROOT/etc/profile.d/conda.sh"
conda activate "$HOME/.conda/envs/my-project"

python --version
python -c "import sys; print(sys.executable)"
```

如果程序使用 GPU，还应在脚本中申请 GPU：

```bash
#SBATCH --gres=gpu:1
```

并确认环境中的 PyTorch 和 CUDA 运行库兼容。

## 9. 常见问题

### `conda: command not found`

```bash
source /etc/profile.d/z00_lmod.sh
module load conda/2026
```

### `conda activate` 无法使用

```bash
source "$CONDA_ROOT/etc/profile.d/conda.sh"
```

### 无法安装包

检查是否激活了个人环境，以及是否有写入权限：

```bash
which python
echo "$CONDA_PREFIX"
```

如果环境位于公共软件目录，普通用户通常没有修改权限。请创建个人环境，而不是尝试修改公共目录权限。

### 环境过大

查看环境占用：

```bash
du -sh "$HOME/.conda/envs/my-project"
```

删除不再需要的个人环境前，确认其中没有需要保留的实验依赖。

## 10. 使用规范

- 不要修改公共 Conda 环境中的包。
- 每个重要项目使用独立环境。
- 保存 `environment.yml` 或其他依赖清单。
- 在 Slurm 作业脚本中明确初始化 Conda。
- 不要将包含密码或访问令牌的配置文件提交到公开仓库。

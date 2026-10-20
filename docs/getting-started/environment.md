# 初始化软件环境

登录后，先查看管理员发布的软件模块：

```bash
module avail
module list
```

如果 shell 中提示 `module: command not found`，请查看管理员提供的 Lmod 初始化方式。常见系统可能使用：

```bash
source /etc/profile.d/z00_lmod.sh
```

实际初始化脚本路径以系统安装配置为准。

## 选择软件版本

```bash
module avail gcc
module avail java
module avail conda
```

例如，若管理员提供了这些模块：

```bash
module load gcc/12
module load java/21
module load conda/2026
module list
```

上面的模块名仅为示例。`module load` 会修改当前 shell 的环境变量；它本身不会自动申请 Slurm 资源，也不会自动进入 Apptainer 容器。

## 环境隔离建议

- 公共基础软件由管理员维护，用户不要修改公共安装目录。
- Python 项目优先使用项目自己的 Conda 环境或已验证的容器镜像。
- 记录 Python、PyTorch、CUDA、编译器和依赖版本，以便复现实验。

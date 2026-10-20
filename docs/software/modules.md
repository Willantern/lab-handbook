# Lmod Modules

Lmod 允许用户在不同软件版本之间切换，而不必修改系统全局配置。

## 常用命令

```bash
module avail
module avail gcc
module spider pytorch
module load gcc/12
module list
module show gcc/12
module unload gcc/12
module purge
```

实际可用的软件名称和版本取决于管理员安装了哪些模块。

## Modules 不等于容器

`module load pytorch/版本` 通常只会设置环境变量，例如 `PYTORCH_SIF`，并不会自动进入容器。若模块指向 Apptainer 镜像，仍需要运行：

```bash
apptainer exec --nv "$PYTORCH_SIF" python train.py
```

如果管理员提供了 `pytorch-exec` 之类的快捷命令，也可以使用该命令；请以模块文档为准。

## 在 Slurm 作业中加载模块

批处理脚本应显式初始化模块系统并加载需要的软件，避免依赖交互式终端的状态。例如：

```bash
source /etc/profile.d/z00_lmod.sh
module load gcc/12
module load java/21
```

上面的初始化路径和模块版本是示例。请使用管理员确认过的配置。

## 版本管理原则

- 尽可能显式加载版本，如 `gcc/12`，而不是依赖默认版本。
- 公共模块文件由管理员维护。
- 新增模块时，记录安装路径、版本、许可、依赖和验证方式。

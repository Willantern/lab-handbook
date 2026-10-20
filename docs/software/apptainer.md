# Apptainer 容器

Apptainer 可以将软件及其用户态依赖封装在 SIF 镜像中，常用于 HPC 集群。它与 Slurm 分工不同：Slurm 分配资源，Apptainer 运行指定环境。

## 检查安装

```bash
apptainer --version
apptainer help
```

如果命令不存在，请联系管理员确认 Apptainer 是否已安装及是否有对应模块。

## 运行公共镜像

假设管理员提供了公共镜像路径：

```bash
apptainer exec /opt/apps/containers/example.sif python --version
```

使用 NVIDIA GPU 时，常见形式是：

```bash
apptainer exec --nv /opt/apps/containers/pytorch.sif \
  python -c 'import torch; print(torch.cuda.is_available())'
```

容器内 CUDA 用户态库仍依赖兼容的主机 NVIDIA 驱动。`--nv` 不会替用户安装主机驱动。

## 挂载代码与数据

```bash
apptainer exec \
  --bind "$HOME/project:/workspace" \
  --bind "/data/datasets:/data/datasets:ro" \
  /opt/apps/containers/example.sif \
  python /workspace/train.py
```

- `--bind` 将宿主机路径映射到容器内。
- `:ro` 表示只读挂载，适合共享数据集。
- 代码目录、数据目录和输出目录应按实际路径修改。

## 可写环境

公共 SIF 通常应只读。需要新增依赖时，优先使用个人 Conda 环境、个人 overlay，或根据实验需求构建个人镜像。不要修改公共镜像文件，也不要让多个作业同时写入同一个 overlay。

# Conda 环境

Conda 可以为不同项目隔离 Python 和第三方包。若实验室提供公共 Anaconda 安装，用户应通过管理员发布的模块加载它。

## 加载公共 Conda

示例：

```bash
module load conda/2026
conda --version
```

如果 `conda` 命令不可用，说明模块文件可能没有将 Conda 加入 `PATH`，或当前 shell 没有初始化 Conda。请查看：

```bash
module show conda/2026
echo "$CONDA_ROOT"
```

若管理员配置了 `CONDA_ROOT`，并要求单独初始化 shell，可以使用：

```bash
source "$CONDA_ROOT/etc/profile.d/conda.sh"
```

不要假定每个集群都使用相同的安装路径或模块名。

## 建立个人环境

公共基础安装应保持只读。个人依赖可安装在自己的环境中：

```bash
conda create -n my-project python=3.12 -y
conda activate my-project
python -m pip install numpy
```

如果公共 Conda 安装对用户不可写，应将环境和包缓存放在个人目录；具体路径由管理员的 Conda 配置决定。

## 记录环境

```bash
conda env export --from-history > environment.yml
conda list > conda-packages.txt
python --version
```

导出的文件应随项目代码保存，便于后续复现。不要将访问令牌或带有私有渠道凭据的配置提交到公开仓库。

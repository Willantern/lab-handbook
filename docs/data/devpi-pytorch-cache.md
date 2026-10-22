# Python 软件包缓存与 PyTorch 版本管理

本文介绍实验室如何使用 `devpi` 统一管理 Python
软件包缓存，以及管理员如何添加其他 PyTorch/CUDA
版本。目标是减少重复下载，避免所有用户直接访问不稳定的外部 Python
软件包下载地址。

## 1. 当前配置

当前 `server1` 已部署 `devpi-server`，服务由 systemd 管理。

| 项目                     | 当前配置                                    |
|--------------------------|---------------------------------------------|
| devpi 服务版本           | `6.20.3`                                    |
| devpi 客户端版本         | `7.3.0`                                     |
| Python 环境              | `/opt/devpi/venv`                           |
| 服务数据目录             | `/var/lib/devpi/server`                     |
| systemd 服务             | `devpi.service`                             |
| 服务地址                 | `http://127.0.0.1:3141`                     |
| 普通 PyPI 上游           | `https://pypi.tuna.tsinghua.edu.cn/simple/` |
| 实验室索引               | `labadmin/packages`                         |
| 当前已导入的 PyTorch     | `torch==2.14.1+cu132`                       |
| 当前已导入的 torchvision | `torchvision==0.29.1+cu132`                 |

当前导入的 PyTorch Wheel 面向 Linux x86_64、CPython 3.12。其他 Python
版本、操作系统或架构可能需要对应的 Wheel。

### 1.1 当前索引

- `root/pypi`：代理清华 PyPI 镜像，按需获取并缓存普通 Python 包。
- `labadmin/packages`：实验室统一索引，继承
  `root/pypi`，同时用于上传实验室专用的软件包。

普通用户应使用实验室统一索引：

``` text
http://127.0.0.1:3141/labadmin/packages/+simple/
```

当前服务仅监听 `127.0.0.1`，因此这个地址只适用于 `server1`
本机。未来若要让其他计算节点共享缓存，需要另行配置可被内网访问的服务地址和访问控制。

## 2. 普通 Python 包：自动缓存

普通 PyPI 软件包不需要管理员提前下载。用户正常安装时，请求经过
devpi，devpi
会按需从上游获取项目元数据和软件包文件，并缓存成功获取的内容。

例如，用户可以直接执行：

``` bash
python -m pip install numpy scipy pandas
python -m pip install opencv-python scikit-image
python -m pip install jupyterlab transformers
```

当其他用户再次请求已缓存的版本时，devpi
可以复用已有文件，减少重复的外网下载。

需要注意：

- 第一次获取某个尚未缓存的文件时，仍需要 devpi 能访问上游镜像。
- devpi 是按需缓存，不是提前下载整个 PyPI 仓库。
- 如果上游暂时不可访问，尚未缓存的文件可能无法获取。
- Git 仓库、直接下载 URL、模型权重和数据集不一定经过
  devpi，不能指望它自动缓存这些资源。

### 2.1 检查普通包是否能通过 devpi 下载

``` bash
mkdir -p /tmp/devpi-test

python -m pip download \
  --no-cache-dir \
  --index-url http://127.0.0.1:3141/labadmin/packages/+simple/ \
  --trusted-host 127.0.0.1 \
  --dest /tmp/devpi-test \
  "typing-extensions==4.16.0"
```

`--no-cache-dir` 关闭的是客户端 pip 缓存，不会关闭 devpi 服务端缓存。

如果下载成功，说明当前环境能够通过实验室索引获取这个软件包。

## 3. 配置 pip 默认使用实验室索引

如果希望 `server1` 上的用户默认使用 devpi，可以由管理员配置系统级
`/etc/pip.conf`。

**先确认 devpi 索引和软件包下载测试成功，再执行此操作。**

``` bash
sudo tee /etc/pip.conf >/dev/null <<'EOF'
[global]
index-url = http://127.0.0.1:3141/labadmin/packages/+simple/
trusted-host = 127.0.0.1
timeout = 60
retries = 2
EOF

sudo chmod 644 /etc/pip.conf
```

检查配置：

``` bash
python -m pip config list
python -m pip config debug
```

之后，普通用户一般可以直接运行：

``` bash
pip install numpy
```

如果某个环境没有使用该索引，检查是否存在覆盖配置的环境变量或用户级配置：

``` bash
env | grep -i '^PIP_'
python -m pip config debug
```

命令行参数和环境变量可能覆盖配置文件中的设置。不要在每个用户的 Conda
环境中重复安装 devpi；devpi 是服务器级服务，用户只需要使用自己的
Python/Conda 环境。

## 4. 管理员添加其他 PyTorch/CUDA 版本

普通 PyPI 包可以自动缓存，但 PyTorch 官方 CUDA
专用索引中的特定构建版本不会因为配置了清华 PyPI
上游就自动全部进入实验室索引。

添加一个新的 PyTorch 版本时，通常需要：

1.  确认 PyTorch、torchvision 和 CUDA 构建的兼容组合。
2.  从对应的 PyTorch 官方索引下载主 Wheel。
3.  将 Wheel 上传到 `labadmin/packages`。
4.  测试依赖能否通过内部索引解析和下载。

版本组合请先通过 [PyTorch
官方安装选择器](https://pytorch.org/get-started/locally/)
确认。不要只修改版本号就假设相应 Wheel 一定存在。

### 4.1 确定版本参数

下面的示例使用当前已导入的版本，目的是展示可重复使用的操作流程。添加其他版本时，请将变量改为官方实际提供的版本组合和
CUDA 索引。

``` bash
CUDA_TAG=cu132
TORCH_VERSION='2.14.1+cu132'
VISION_VERSION='0.29.1+cu132'

PYTORCH_INDEX="https://download.pytorch.org/whl/${CUDA_TAG}"
WHEELDIR="$HOME/torch-wheels/${TORCH_VERSION}-${CUDA_TAG}"

mkdir -p "$WHEELDIR"
```

当前示例对应的官方索引是：

``` text
https://download.pytorch.org/whl/cu132
```

下载之前，请确认当前 Python 解释器版本与目标 Wheel 匹配。当前已导入的
Wheel 标签为 `cp312`，即 CPython 3.12。

### 4.2 下载 PyTorch 主 Wheel

``` bash
python -m pip download \
  --no-deps \
  --only-binary=:all: \
  --index-url "$PYTORCH_INDEX" \
  --dest "$WHEELDIR" \
  "torch==$TORCH_VERSION" \
  "torchvision==$VISION_VERSION"
```

检查文件：

``` bash
ls -lh "$WHEELDIR"
```

这里使用 `--no-deps`，只下载 `torch` 和 `torchvision`
主包。其余依赖将在后续通过实验室索引解析；这不代表依赖已经全部下载或缓存。

如果提示找不到对应版本，请检查官方索引、版本组合、Python
版本和平台标签，不要直接上传不匹配的 Wheel。

### 4.3 上传 Wheel 到实验室索引

上传需要 `labadmin` 账户密码。不要把真实密码写进公开脚本、Git
仓库或手册。

``` bash
read -rsp "输入 labadmin 密码: " TWINE_PASSWORD
echo

TWINE_USERNAME=labadmin \
TWINE_PASSWORD="$TWINE_PASSWORD" \
/opt/devpi/venv/bin/twine upload \
  --repository-url http://127.0.0.1:3141/labadmin/packages/ \
  --non-interactive \
  "$WHEELDIR"/*.whl

unset TWINE_PASSWORD
```

上传成功后，检查包索引：

``` bash
for pkg in torch torchvision; do
  curl -sS -o /dev/null \
    -w "$pkg HTTP=%{http_code}\n" \
    "http://127.0.0.1:3141/labadmin/packages/+simple/$pkg/"
done
```

如果是全新版本，通常应看到两个索引页面均返回 HTTP
`200`。重复上传已经存在的版本可能会失败；遇到这种情况，应先检查索引中是否已经存在该版本，不要盲目覆盖或删除已有文件。

## 5. 验证 PyTorch 的完整依赖

上传主 Wheel 后，还需要确认依赖可以从实验室索引获取。PyTorch 可能依赖
CUDA、cuDNN、NCCL、Triton 等软件包，实际依赖取决于所选版本和构建。

可以先做一次解析和下载测试：

``` bash
python -m pip install \
  --dry-run \
  --ignore-installed \
  --no-cache-dir \
  "torch==$TORCH_VERSION" \
  "torchvision==$VISION_VERSION"
```

该命令不会把软件包安装到当前环境，但为了完成解析，pip 可能需要下载大量
Wheel。CUDA 相关依赖可能占用数 GB
流量和临时磁盘空间，请在空间充足、网络允许时执行。

如果测试成功，说明当前索引能够解析这组版本的依赖。如果失败：

1.  查看错误中缺失的具体包名和版本。
2.  确认该依赖是否存在于 `root/pypi` 上游。
3.  如果依赖只存在于其他专用索引，需要单独下载并导入内部索引。
4.  重新执行测试，直到依赖解析成功。

普通用户随后即可使用内部索引安装指定版本：

``` bash
python -m pip install \
  "torch==2.14.1+cu132" \
  "torchvision==0.29.1+cu132"
```

安装其他版本时，替换为已经导入并验证过的版本号。

## 6. 提前缓存某个项目的依赖

通常不需要专门预热缓存：用户正常安装就会触发按需缓存。如果管理员希望在实验前提前准备某个项目，可以使用项目的
`requirements.txt`。

例如：

``` bash
cd ~/code/lgp-x2

mkdir -p /tmp/lgp-x2-wheelhouse

python -m pip download \
  --no-cache-dir \
  --dest /tmp/lgp-x2-wheelhouse \
  -r requirements.txt
```

下载过程使用当前 pip 配置的索引；成功获取的相关文件会经过
devpi，有机会进入服务端缓存。`/tmp/lgp-x2-wheelhouse`
是额外保存的本地副本，不是 devpi
的缓存目录。确认不再需要这些文件后，可以删除该临时目录。

如果 `requirements.txt` 包含 Git 仓库、直接下载 URL 或其他非 PyPI
来源，需单独确认这些资源的获取方式。

## 7. 检查和维护 devpi 服务

检查服务状态：

``` bash
sudo systemctl status devpi --no-pager
```

查看最近的服务日志：

``` bash
sudo journalctl -u devpi -n 80 --no-pager
```

检查本机 HTTP 接口：

``` bash
curl -sS -o /dev/null \
  -w 'HTTP=%{http_code}\n' \
  http://127.0.0.1:3141/
```

查看索引配置：

``` bash
/opt/devpi/venv/bin/devpi use http://127.0.0.1:3141
/opt/devpi/venv/bin/devpi index root/pypi
/opt/devpi/venv/bin/devpi index labadmin/packages
```

最后两条命令用于查看索引配置；如果客户端没有登录或无法访问索引，请先检查
devpi 客户端登录状态。

## 8. 注意事项

- `devpi` 负责 Python 包索引、代理和缓存，不是通用下载缓存服务。
- 普通 PyPI 包由上游镜像按需缓存；PyTorch 专用 CUDA
  构建需要管理员导入并验证。
- 缓存不能保证首次下载离线可用。要支持断网安装，必须提前确认所有目标包和依赖都已缓存或导入。
- 当前服务监听 `127.0.0.1:3141`，只适用于 `server1` 本机。不要直接把
  `127.0.0.1`
  配置复制到其他计算节点；多节点部署需要统一的内网服务地址，并评估认证、TLS
  和访问控制。
- `/etc/pip.conf` 是系统级配置，会影响本机多个 Python
  环境。修改前应先完成测试，并留意用户级配置、环境变量或命令行参数的覆盖。
- Conda 包、Ubuntu `apt` 包、Apptainer `.sif`
  镜像、模型权重和数据集应使用各自合适的仓库或共享存储管理。
- 不要把 `labadmin` 或 `root` 密码写进公开的 MkDocs
  页面、脚本仓库或项目配置。

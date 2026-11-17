# 使用大语言模型

本文介绍实验室计算平台的大语言模型（Large Language Model，LLM）使用方法，涵盖**查看现有模型、管理员安装与卸载、模型下载与校验、公共软件配置、普通用户通过 Slurm 自行申请 GPU 推理**。文中以已部署的 **Qwen3.8-27B Q8_0** 为操作示例；安装其他模型时，应依据模型的文件格式、许可证、GPU 需求和推理框架要求调整参数。

平台采用**管理员统一维护软件与模型，用户自行通过 Slurm 启动推理任务**的方式。管理员无需常驻启动模型服务。模型文件由多人只读共享，GPU 占用和作业时间由 Slurm 管理。

## 1. 平台配置与使用原则

以下内容以当前 `server1` 上已验证的部署为例。其他模型或服务器可参照调整。

| 项目 | 当前配置 |
| --- | --- |
| 操作系统 | Ubuntu 22.04 |
| GPU | 4 × NVIDIA RTX 4090（每张约 24 GiB） |
| GPU 调度 | Slurm；`compute`、`debug` 分区 |
| CUDA Toolkit | 13.2，Lmod 模块 `cuda/13.2` |
| 推理框架 | llama.cpp，编译提交 `eada89c` |
| llama.cpp 模块 | `llama.cpp/cuda13.2` |
| 已确认安装的模型 | Qwen3.8-27B，GGUF Q8_0 |
| 模型权重目录 | `/data/models/qwen3.8-27b/q8_0/` |
| 推理程序目录 | `/opt/apps/llama.cpp/` |
| Lmod 模块目录 | `/opt/modulefiles/` |

基本原则：

- **模型文件只下载一次。** 管理员下载并检查来源，普通用户以只读方式访问。
- **Lmod 只提供环境。** `module load` 不会自动启动模型，也不会申请 GPU。
- **GPU 必须通过 Slurm 申请。** 不要直接在登录终端启动 GPU 推理进程。
- **个人服务由个人管理。** 用户自行启动或停止 Slurm 作业，管理员不负责常驻模型进程。
- **个人数据保存在个人目录。** 不在 `/data/models` 写入提示词、日志、缓存或实验结果。
- **不得公开模型服务。** 默认只监听 `127.0.0.1`，从个人电脑通过 SSH 隧道访问。

!!! note "显存与磁盘是不同资源"
    Qwen3.8-27B 的 Q8_0 文件约为 **28.6 GB（26.63 GiB）**。模型文件存储在硬盘，实际推理还要占用 GPU 显存、KV Cache 和运行内存。当前 Q8_0 配置已在 **2 张 RTX 4090** 上通过推理测试。四张 GPU 的显存不会自动合并成一个单独的 96 GB 显存池。

## 2. 当前已安装模型与查看方式

### 2.1 已确认部署的模型

截至 **2026-11-17**，根据管理员已完成的下载校验、Lmod 加载和 Slurm 推理测试，能够确认以下模型已在 `server1` 上部署成功：

| 模型 | 格式与量化 | 权重文件大小 | 建议 GPU | 模型路径 | 状态 |
| --- | --- | ---: | --- | --- | --- |
| **Qwen3.8-27B** | GGUF / **Q8_0** | **28.6 GB（26.63 GiB）** | **2 × RTX 4090** | `/data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf` | 已通过 SHA256 与 Slurm API 推理验收 |

对应的公共推理环境为 `llama.cpp/cuda13.2`，模型的默认路径由环境变量 `QWEN_MODEL` 指定。已验证的一次短请求生成速度约为 **31 tokens/s**，实际性能与上下文长度、GPU 负载和并发数有关。

**上表是目前已核实的模型清单，不是从服务器实时生成的动态清单。** 以后管理员新增其他模型时，应同步更新此表。Qwen3.8-27B 的 Q4_K_M、BF16 等版本在后文只是下载和部署示例，**不能据此认为已经安装**。如需查看服务器此刻的真实文件，以以下命令为准。

### 2.2 普通用户如何查看共享模型

登录 `server1` 后，无需 `sudo`，直接列出公共目录中的 GGUF 模型文件：

```bash
find /data/models -type f -iname '*.gguf' \
  -printf '%p\n' | sort
```

按文件大小查看：

```bash
find /data/models -type f -iname '*.gguf' \
  -exec du -h {} + | sort -h
```

目前已确认的 Qwen 模型可直接查看：

```bash
ls -lh /data/models/qwen3.8-27b/q8_0/
```

若以后安装了 Hugging Face 原始格式的分片模型（例如 `*.safetensors`），可以进一步查看：

```bash
find /data/models -type f -name 'config.json' \
  -printf '%h\n' | sort -u
```

`config.json` 目录列表只能帮助定位 Hugging Face 格式的模型，不代表全部文件都完整、已通过验收或兼容当前 llama.cpp。查看某个模型的真实可用性，还应参考本章的管理员验收记录。

### 2.3 查看推理软件与默认模型

```bash
source /etc/profile.d/z00_lmod.sh
module avail llama.cpp
module show llama.cpp/cuda13.2

module load llama.cpp/cuda13.2
echo "$QWEN_MODEL"
ls -lh "$QWEN_MODEL"
```

**注意区别：** `module avail` 展示的是可加载的软件模块，不是完整模型清单。`module show` 和 `echo "$QWEN_MODEL"` 仅显示该模块当前设置的默认模型路径。要查看**全部共享模型文件**，使用上一节的 `find /data/models` 命令。

### 2.4 选择其他已安装模型

用户运行 llama.cpp 时，可以通过 `--model` 指定任意**已安装、可读且格式兼容**的 GGUF 文件，而不必使用默认的 `QWEN_MODEL`：

```bash
# 示例：当前已确认存在的 Qwen 模型
MODEL_PATH=/data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf

# 在已获得 Slurm GPU 配额的作业内部运行
llama-cli --model "$MODEL_PATH" \
  --n-gpu-layers 999 --split-mode layer \
  --ctx-size 8192 --prompt "你好" --n-predict 256
```

新增模型后，将 `MODEL_PATH` 改成实际文件路径即可。不能因为文件存在就直接沿用两张 GPU 或 Qwen 的上下文参数；具体资源需求需根据该模型单独确定。

!!! tip "查看模型不需要 GPU"
    `find`、`ls`、`module avail` 和 `module show` 都不加载权重，也不占用显存。**只有真正执行推理程序时，才需要先通过 Slurm 申请 GPU。**

## 3. 管理员：安装前检查

以下章节由具有 `sudo` 权限的管理员执行。普通用户可直接阅读[第 8 节：用户使用](#8-用户通过-slurm-使用模型)。

检查现有环境：

```bash
nvidia-smi
sinfo

df -hT / /opt
ls -ld /data /opt/modulefiles 2>/dev/null || true

source /etc/profile.d/z00_lmod.sh
module avail cuda
module avail llama.cpp

command -v git
command -v cmake
command -v ninja
command -v gcc
command -v g++
```

如基础工具已存在，不必重复安装。对于系统软件安装，先使用 `apt-get -s` 模拟，检查是否会卸载、替换重要组件：

```bash
sudo apt-get -s install \
  git cmake ninja-build build-essential libcurl4-openssl-dev
```

检查结果无异常且确实缺少依赖时，再去掉 `-s` 正式安装。不要为了安装推理框架而随意升级 NVIDIA 驱动、Slurm 或现有 Conda 环境。

## 4. 管理员：安装 CUDA Toolkit 并注册 Lmod

**已存在 `cuda/13.2` 且 `nvcc --version` 正常时，跳过本节。** 模型文件下载和运行预编译程序并不需要 CUDA 编译器；这里安装 Toolkit 是为了编译 CUDA 版 llama.cpp。

### 4.1 检查 Toolkit

```bash
module load cuda/13.2
nvcc --version
echo "$CUDA_HOME"
```

当前平台预期：

```text
Cuda compilation tools, release 13.2
/usr/local/cuda-13.2
```

`nvidia-smi` 中的 CUDA Version 是驱动支持的 CUDA API 版本，不等于已安装 CUDA Toolkit。

### 4.2 首次安装 CUDA Toolkit（仅管理员）

仅在未安装 CUDA Toolkit 时执行：

```bash
cd /tmp
wget -c \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb

sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

apt-cache policy cuda-toolkit-13-2
sudo apt-get -s install cuda-toolkit-13-2 \
  | tee /tmp/cuda-install-plan.txt

grep '^Remv ' /tmp/cuda-install-plan.txt || true
```

确认模拟安装**没有卸载或替换现有 NVIDIA Driver**后，执行：

```bash
sudo apt-get install cuda-toolkit-13-2
/usr/local/cuda-13.2/bin/nvcc --version
nvidia-smi
```

不要使用 `cuda`、`cuda-drivers` 元包代替 `cuda-toolkit-13-2`。安装 Toolkit 后不需要将 CUDA 路径永久添加到所有用户的 `.bashrc`。

### 4.3 创建 CUDA 的 Lmod 模块

```bash
sudo install -d -m 755 /opt/modulefiles/cuda

sudo tee /opt/modulefiles/cuda/13.2.lua >/dev/null <<'LUA'
help([[NVIDIA CUDA Toolkit 13.2]])
whatis("Name: NVIDIA CUDA Toolkit")
whatis("Version: 13.2")
family("cuda")

local root = "/usr/local/cuda-13.2"
prepend_path("PATH", pathJoin(root, "bin"))
setenv("CUDA_HOME", root)
setenv("CUDA_ROOT", root)
setenv("CUDAToolkit_ROOT", root)
LUA

sudo chown root:root /opt/modulefiles/cuda/13.2.lua
sudo chmod 644 /opt/modulefiles/cuda/13.2.lua

module --ignore_cache avail cuda
module load cuda/13.2
nvcc --version
```

该模块只设置编译器路径和必要环境变量，未将 CUDA 库目录永久加入全局 `LD_LIBRARY_PATH`。需要 CUDA 动态库的特定软件，在自身模块中设置运行路径。

## 5. 管理员：下载与共享大模型

### 5.1 选择模型与量化版本

管理员先确认模型的**许可证、来源、量化格式、推理框架兼容性、磁盘和显存需求**。

以 [ggml-org/Qwen3.8-27B-GGUF](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF) 为例：

| 量化版本 | 模型文件大小（约） | 当前安装状态 | 当前平台建议 |
| --- | ---: | --- | --- |
| Q4_K_M | 19.4 GB | 未确认安装 | 可尝试单张 4090，长上下文需实测 |
| **Q8_0** | **28.6 GB** | **已安装，验收通过** | **两张 4090，当前示例配置** |
| BF16 | 53.8 GB | 未确认安装 | 需要更多 GPU 显存，不作为首次部署方案 |

Q4/Q8 的差异主要是模型权重精度与存储占用。**文件能装下，不代表任意上下文或并发设置都能运行。**

### 5.2 创建共享模型目录

先确认 `/data` 所在文件系统有足够空间。当前平台的 `/data` 位于根文件系统，不应误以为这是独立挂载盘。

```bash
df -hT /data 2>/dev/null || df -hT /

sudo install -d -m 755 /data /data/models /data/models/qwen3.8-27b
sudo install -d -m 755 \
  -o "$(id -un)" -g "$(id -gn)" \
  /data/models/qwen3.8-27b/q8_0
```

### 5.3 从 Hugging Face 官方地址下载

管理员下载 Q8_0 模型文件：

```bash
cd /data/models/qwen3.8-27b/q8_0

wget -c --show-progress --tries=10 --timeout=60 \
  -O Qwen3.8-27B-Q8_0.gguf \
  'https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q8_0.gguf'
```

`-c` 用于断点续传，下载中断后可重新执行。注意下载地址可能跳转至 Hugging Face 的 Xet/CDN 域名，因此能访问仓库主页不代表一定能下载大文件。

### 5.4 从 HF-Mirror 镜像下载

网络连接官方站点不稳定时，可使用 [HF-Mirror](https://hf-mirror.com/)：

```bash
cd /data/models/qwen3.8-27b/q8_0

wget -c --show-progress --tries=10 --timeout=60 \
  -O Qwen3.8-27B-Q8_0.gguf \
  'https://hf-mirror.com/ggml-org/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q8_0.gguf'
```

镜像地址也可能跳转至 `cas-bridge.xethub.hf.co` 等下载域名，这属于正常的文件分发过程。镜像是否可用以当时的实际网络情况为准。

对于需要下载多个文件或一个完整模型仓库的情况，也可使用 `hf` 命令：

```bash
# 建议在管理员独立 Python 环境中安装 huggingface_hub
python3 -m venv ~/venvs/hf-download
source ~/venvs/hf-download/bin/activate
python -m pip install -U huggingface_hub

export HF_ENDPOINT=https://hf-mirror.com
hf download ggml-org/Qwen3.8-27B-GGUF \
  Qwen3.8-27B-Q8_0.gguf \
  --local-dir /data/models/qwen3.8-27b/q8_0

deactivate
```

若系统缺少 `venv` 组件，需先按管理员软件包变更流程检查并安装 `python3-venv`。不要在系统 Python 或普通用户的项目环境中强行升级下载工具。

### 5.5 检查文件完整性与来源

```bash
cd /data/models/qwen3.8-27b/q8_0

ls -lh Qwen3.8-27B-Q8_0.gguf
sha256sum Qwen3.8-27B-Q8_0.gguf
```

**将 SHA256 与所选模型文件版本在发布页面显示的 SHA256 比较。** 仅把本机计算出的 SHA256 写回 `sha256sum -c`，不能独立证明文件来自发布者。

!!! warning "关于版本与 SHA256"
    `resolve/main/` 会随仓库更新而变化。记录下载日期、仓库名、具体提交、文件大小和 SHA256，后续复现优先使用固定 revision。当前服务器在 **2026-11-17** 下载的 Q8_0 文件，实际计算得到 `6bc9e7220d8400574fd62df25f04a961cb5cbb0d766cf0118c21c36c0059c35a`。该值是**这次服务器文件的记录**，不能当成所有后续版本的通用校验值；若与官方发布记录不同，应核实仓库修订版本及来源后再对外共享。

### 5.6 设为公共只读

```bash
sudo chown -R root:root /data/models/qwen3.8-27b
sudo find /data/models/qwen3.8-27b -type d -exec chmod 755 {} +
sudo find /data/models/qwen3.8-27b -type f -exec chmod 644 {} +

namei -l \
  /data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf
```

普通用户应具有目录的遍历权限和模型文件的读取权限，不具有修改权限。用户如需新模型或其他量化版本，应联系管理员统一添加，不要重复将同一文件复制到多个家目录。

## 6. 管理员：安装 llama.cpp 并注册 Lmod

### 6.1 源码编译

当前服务器已具有 Git、CMake、Ninja、GCC 及 `libcurl4-openssl-dev`，无需重复安装。

```bash
mkdir -p ~/src
cd ~/src

git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

git log -1 --format='%h %cs %s'
module load cuda/13.2

cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_COMPILER="$CUDA_HOME/bin/nvcc" \
  -DCMAKE_CUDA_ARCHITECTURES=89 \
  -DCMAKE_INSTALL_PREFIX=/opt/apps/llama.cpp \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'

cmake --build build --parallel 16
sudo cmake --install build
```

RTX 4090 使用 CUDA Compute Capability `8.9`，对应构建参数 `89`。管理员应保留编译提交号、编译参数及 CUDA 版本，便于更新回滚。当前已验证安装的 llama.cpp 提交为 `eada89c`。

检查：

```bash
/opt/apps/llama.cpp/bin/llama-server --version
/opt/apps/llama.cpp/bin/llama-cli --version
ldd /opt/apps/llama.cpp/bin/llama-server | grep 'not found' || true
```

### 6.2 创建 llama.cpp 模块

```bash
sudo install -d -m 755 /opt/modulefiles/llama.cpp

sudo tee /opt/modulefiles/llama.cpp/cuda13.2.lua >/dev/null <<'LUA'
help([[llama.cpp CUDA backend; RTX 4090, CUDA 13.2]])
whatis("Name: llama.cpp")
whatis("Build: eada89c")
whatis("CUDA: 13.2")

depends_on("cuda/13.2")

local root = "/opt/apps/llama.cpp"
prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", "/usr/local/cuda-13.2/lib64")

setenv("LLAMA_CPP_ROOT", root)
setenv("QWEN_MODEL",
  "/data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf")
LUA

sudo chown root:root /opt/modulefiles/llama.cpp/cuda13.2.lua
sudo chmod 644 /opt/modulefiles/llama.cpp/cuda13.2.lua
```

检查：

```bash
source /etc/profile.d/z00_lmod.sh
module --ignore_cache avail llama.cpp
module load llama.cpp/cuda13.2

which llama-server
llama-server --version
echo "$QWEN_MODEL"
module list
```

当前模块同时设置了 llama.cpp 的运行环境和 Qwen 模型路径。以后如果部署更多模型，建议将推理框架模块与模型路径模块进一步拆分，便于版本管理。

## 7. 管理员：首次 Slurm 推理验收

在共享给其他用户之前，使用 Slurm 申请 2 张 GPU，验证实际推理。**不要只凭 `llama-server --version` 判断 GPU 模型已可用。**

```bash
mkdir -p ~/slurm-jobs/qwen
cd ~/slurm-jobs/qwen

cat > qwen-smoke.sbatch <<'EOF_SBATCH'
#!/usr/bin/env bash
#SBATCH --job-name=qwen-smoke
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --gres=gpu:2
#SBATCH --time=00:20:00
#SBATCH --output=qwen-smoke-%j.out
#SBATCH --error=qwen-smoke-%j.err

set -euo pipefail
source /etc/profile.d/z00_lmod.sh
module load llama.cpp/cuda13.2

echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
llama-server --list-devices

# 简短测试，不需要长期占用 API 端口
llama-cli \
  --model "$QWEN_MODEL" \
  --n-gpu-layers 999 \
  --split-mode layer \
  --ctx-size 8192 \
  --prompt "请用中文简要解释线性遗传编程。" \
  --n-predict 256
EOF_SBATCH

sbatch qwen-smoke.sbatch
squeue -u "$USER"
```

作业结束后查看：

```bash
cat qwen-smoke-<作业ID>.out
cat qwen-smoke-<作业ID>.err
```

将 `<作业ID>` 替换为 `sbatch` 实际返回的编号。验收时确认 Slurm 分配了两张 GPU、CUDA 后端正常、模型能够输出可读中文。

当前平台已有 Qwen3.8-27B Q8_0 的 `llama-server` API 实测：短请求生成约 **31 tokens/s**。该数值仅用于说明环境已实际运行，不作为长上下文、多用户并发或不同版本的性能保证。

## 8. 用户：通过 Slurm 使用模型

普通用户**不需要 sudo、不需要下载模型、不需要单独安装 CUDA 或 llama.cpp**。

### 8.1 查看模型、模块与路径

先查看**当前实际存在的共享 GGUF 权重文件**：

```bash
find /data/models -type f -iname '*.gguf' \
  -printf '%p\n' | sort
```

然后加载公共推理环境，查看 Qwen 示例模型的默认路径：

```bash
source /etc/profile.d/z00_lmod.sh
module avail llama.cpp
module load llama.cpp/cuda13.2

which llama-cli
which llama-server
echo "$QWEN_MODEL"
ls -lh "$QWEN_MODEL"
```

正常情况下，`QWEN_MODEL` 指向：

```text
/data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf
```

### 8.2 交互式推理：`srun` + `llama-cli`

适用于短时间尝试模型或临时提问。

```bash
srun \
  --partition=compute \
  --nodes=1 \
  --ntasks=1 \
  --gres=gpu:2 \
  --cpus-per-task=8 \
  --mem=48G \
  --time=02:00:00 \
  --pty bash
```

进入作业后执行：

```bash
source /etc/profile.d/z00_lmod.sh
module load llama.cpp/cuda13.2

llama-cli \
  --model "$QWEN_MODEL" \
  --n-gpu-layers 999 \
  --split-mode layer \
  --ctx-size 8192 \
  --prompt "请写一个 Python 快速排序函数，并解释时间复杂度。" \
  --n-predict 1024
```

使用完毕后：

```bash
exit
```

退出 Slurm 交互会话后，资源由调度器释放。避免在分配的时间内让模型无意义地长期空闲。

### 8.3 批量任务：`sbatch` + `llama-cli`

适用于无人值守执行一次推理并保存结果。普通用户在自己的目录操作：

```bash
mkdir -p ~/llm-jobs
cd ~/llm-jobs

cat > qwen-cli.sbatch <<'EOF_SBATCH'
#!/usr/bin/env bash
#SBATCH --job-name=qwen-cli
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --gres=gpu:2
#SBATCH --time=01:00:00
#SBATCH --output=qwen-cli-%j.out
#SBATCH --error=qwen-cli-%j.err

set -euo pipefail
source /etc/profile.d/z00_lmod.sh
module load llama.cpp/cuda13.2

llama-cli \
  --model "$QWEN_MODEL" \
  --n-gpu-layers 999 \
  --split-mode layer \
  --ctx-size 8192 \
  --prompt "请总结 Linux 进程、线程与 Slurm 作业的区别。" \
  --n-predict 1024
EOF_SBATCH

sbatch qwen-cli.sbatch
```

查看自己的任务和日志：

```bash
squeue -u "$USER"
ls -lh qwen-cli-*.out
```

### 8.4 用户自行启动个人 API 服务

适用于 Python 程序、OpenAI 兼容客户端和 Coding Agent。**一个用户一个 Slurm 作业、一个个人 API 密钥**。本方案不会让管理员常驻启动模型。

先创建个人密钥：

```bash
install -d -m 700 ~/.config/qwen-server
umask 077
openssl rand -hex 32 > ~/.config/qwen-server/api-keys
chmod 600 ~/.config/qwen-server/api-keys
```

创建个人服务脚本：

```bash
mkdir -p ~/llm-jobs
cd ~/llm-jobs

cat > qwen-api.sbatch <<'EOF_SBATCH'
#!/usr/bin/env bash
#SBATCH --job-name=my-qwen-api
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --gres=gpu:2
#SBATCH --time=04:00:00
#SBATCH --output=qwen-api-%j.out
#SBATCH --error=qwen-api-%j.err

set -euo pipefail
source /etc/profile.d/z00_lmod.sh
module load llama.cpp/cuda13.2

KEY_FILE="$HOME/.config/qwen-server/api-keys"
test -r "$KEY_FILE"

# 降低与其他作业端口冲突的概率；并非保证端口唯一
PORT=$((20000 + SLURM_JOB_ID % 40000))

echo "Job ID: $SLURM_JOB_ID"
echo "Host: $(hostname)"
echo "Port: $PORT"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

echo "Starting llama-server..."
exec llama-server \
  --model "$QWEN_MODEL" \
  --alias qwen3.8-27b \
  --host 127.0.0.1 \
  --port "$PORT" \
  --n-gpu-layers 999 \
  --split-mode layer \
  --ctx-size 16384 \
  --parallel 1 \
  --jinja \
  --api-key-file "$KEY_FILE"
EOF_SBATCH

sbatch qwen-api.sbatch
```

查询自己的作业和分配的节点：

```bash
squeue -u "$USER" -o '%.18i %.14j %.10T %.15N %.30R'
```

例如返回 Job ID 为 `3910`，用户通过以下命令读取日志中的端口：

```bash
cat qwen-api-3910.out
```

日志中的 `Port` 只是该作业计划使用的端口。应确认日志显示服务实际启动，且未发生端口冲突。**不要直接假定所有用户都使用 18080。**

### 8.5 测试个人 API

假设作业日志中的端口为 `23910`，在 `server1` 上测试：

```bash
PORT=23910  # 改为自己日志中的 Port

curl -fsS "http://127.0.0.1:${PORT}/health"
```

模型仍在加载时，`/health` 可能返回 HTTP 503；加载完成后返回 HTTP 200。然后测试带密钥的请求：

```bash
curl -sS "http://127.0.0.1:${PORT}/v1/chat/completions" \
  -H "Authorization: Bearer $(cat ~/.config/qwen-server/api-keys)" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.8-27b",
    "messages": [
      {"role": "user", "content": "请解释什么是遗传编程。"}
    ],
    "max_tokens": 1024
  }' | python3 -m json.tool
```

若返回 `finish_reason: "length"`，表示本次输出达到 `max_tokens` 限制，不一定是推理故障。可在显存和任务预算允许的情况下调高输出上限。

### 8.6 在个人电脑通过 SSH 隧道访问

假设作业运行在 `server1`，服务端口为 `23910`。在**个人电脑终端**运行：

```bash
ssh -N -L 23910:127.0.0.1:23910 用户名@server1
```

此时可在个人电脑的客户端中填写：

```text
Base URL: http://127.0.0.1:23910/v1
Model:    qwen3.8-27b
API Key:  自己创建的 API 密钥
```

API Key 不要写进共享脚本、公开仓库或日志。SSH 隧道关闭后，本地客户端连接会中断，但 Slurm 模型作业仍会继续运行，直至用户取消或达到时间上限。

如果自己的电脑本地端口 `23910` 已被占用，可以改变 SSH `-L` 的**左侧本地端口**，远端端口仍填写作业日志中的端口。

### 8.7 停止自己的模型服务

```bash
squeue -u "$USER"
scancel 3910  # 替换为自己实际的 Job ID
```

请核对作业编号，勿取消其他无关作业。作业终止后，模型进程退出，Slurm 释放 GPU 资源。

## 9. 代码智能体与工具使用

Qwen 模型提供推理能力；**OpenCode、Pi 等 Agent 框架**负责读写文件、管理会话、调用终端和执行测试。模型服务本身不会因 API 可访问而自动获得服务器的命令执行权限。

个人 API 服务成功启动后，可将上一节的 Base URL、Model ID 和 API Key 填入支持 OpenAI 兼容接口的客户端。具体字段和工具调用格式以各客户端的当前文档为准。首次接入时，建议用个人测试项目验证：

1. 普通中文问答与代码生成。
2. JSON / 工具调用格式。
3. 读取测试目录、修改一份可恢复文件、运行单元测试。
4. 失败时的错误提示和重试行为。

!!! warning "安全边界"
    不要把具有管理员权限的 SSH 凭据、Slurm 管理命令或其他用户的数据交给 Agent。个人 API 服务保持 `127.0.0.1` 监听，不启用未经审查的服务器端 `--tools all`、MCP 等自动执行功能。模型推理申请 GPU 与 Agent 执行外部命令是不同的权限问题。

## 10. 管理员：新增、更新与卸载模型

### 10.1 新增量化版本或其他模型

每个模型和量化版本使用独立目录。下面是**将来新增模型后的示例结构**，其中目前仅确认 `q8_0` 的权重已安装，`q4_k_m` 和 `other-model` 仅用于说明目录规划：

```text
/data/models/
├── qwen3.8-27b/
│   ├── q8_0/
│   │   └── Qwen3.8-27B-Q8_0.gguf
│   └── q4_k_m/
│       └── Qwen3.8-27B-Q4_K_M.gguf
└── other-model/
    └── version/
```

管理员从模型仓库选择合法公开的权重文件，确认许可证、校验和与推理兼容性，再设置公共只读。添加后可在 Lmod 中提供新的模型路径变量，或者让用户在作业中用 `--model /data/models/...` 指定文件。**不要直接覆盖旧文件，导致正在运行的作业失去稳定的模型版本。** 新模型完成 SHA256 校验和 Slurm 推理测试后，再更新[当前已安装模型清单](#21-已确认部署的模型)，并注明量化版本、GPU 需求、路径和验收日期。

### 10.2 更新 llama.cpp

更新前记录现有版本并先验证新版本；建议将多个版本安装在不同的版本化目录，通过不同模块切换。当前安装示例路径为 `/opt/apps/llama.cpp`，升级时不要在已有作业运行过程中原地覆盖动态库与可执行文件。

```bash
module load llama.cpp/cuda13.2
llama-server --version
squeue -o '%.18i %.16u %.16j %.10T %.20R'
```

先完成升级公告与兼容测试，再切换模块。回滚时恢复旧模块和对应程序目录。

### 10.3 停用某个共享模型

卸载前依次进行：

1. 通知用户并停止接受新的相关任务。
2. 检查是否仍有用户通过 Slurm 使用该模型，不要取消或删除正在使用的其他用户作业。
3. 保留来源、SHA256、版本和安装记录；确认无需回滚后再删除。

检查：

```bash
squeue -o '%.18i %.16u %.20j %.10T %.20R'
module show llama.cpp/cuda13.2
ls -lh /data/models/qwen3.8-27b/q8_0/
```

如仅删除 Q8_0 权重，先核对目标文件，再**交互式确认删除**：

```bash
sudo rm -i -- \
  /data/models/qwen3.8-27b/q8_0/Qwen3.8-27B-Q8_0.gguf
```

随后调整或移除模块中已失效的 `QWEN_MODEL` 路径，并同步更新[当前已安装模型清单](#21-已确认部署的模型)。该操作只删除指定模型文件，不会卸载 llama.cpp、CUDA 或 NVIDIA 驱动。

### 10.4 卸载 llama.cpp

只有在确认**没有其他共享模型和正在运行的作业**依赖该软件后，才移除模块及安装目录。先核对完整路径：

```bash
ls -ld /opt/apps/llama.cpp
ls -l /opt/modulefiles/llama.cpp/cuda13.2.lua
```

确认后再删除：

```bash
sudo rm -i -- /opt/modulefiles/llama.cpp/cuda13.2.lua
sudo rm -rI -- /opt/apps/llama.cpp
```

`~/src/llama.cpp` 为管理员个人源码目录，可按需保留或单独清理。不要删除整个 `/opt/apps` 或 `/opt/modulefiles` 目录。

### 10.5 卸载 CUDA Toolkit（通常不需要）

CUDA Toolkit 是全体实验室用户可能共享的编译环境。**仅卸载 Qwen 模型时，不需要卸载 CUDA Toolkit。**

只有确认不存在其他依赖 `cuda/13.2` 的软件和作业后，才由管理员评估移除。先模拟：

```bash
sudo apt-get -s remove cuda-toolkit-13-2
```

该命令只是模拟，实际能否完全清理还取决于单独安装的 CUDA 组件和其他软件依赖。不要直接执行 `apt autoremove`、`apt purge 'cuda*'`，不要卸载 NVIDIA Driver，也不要为了移除模型修改 Slurm GPU 配置。

## 11. 常见问题

| 问题 | 检查与处理 |
| --- | --- |
| `module: command not found` | `source /etc/profile.d/z00_lmod.sh` |
| 不知道有哪些模型 | `find /data/models -type f -iname '*.gguf'`；参见第 2 节 |
| 找不到模型文件 | `echo "$QWEN_MODEL"`、`ls -lh "$QWEN_MODEL"`，检查目录权限 |
| `nvcc: command not found` | 检查 `module load cuda/13.2`；仅使用已编译好的推理程序通常不需 `nvcc` |
| `llama-server: error while loading shared libraries` | `module list`、`ldd "$(which llama-server)"`；联系管理员检查运行库路径 |
| 模型无法识别 GPU | 确认作业申请了 `--gres=gpu:2`，在作业中运行 `llama-server --list-devices` |
| CUDA out of memory | 降低 `--ctx-size`、`--parallel`，减少并发或换较小量化版本 |
| 作业一直 Pending | `squeue -u "$USER" -o '%.18i %.10T %.30R'`，检查 GPU/内存与分区限制 |
| `curl` 连接被拒绝 | 检查作业状态、日志、节点和端口；确认模型已加载完成 |
| `/health` 返回 503 | 正在加载模型；检查日志并在完成后重试 |
| HTTP 401 | 检查 API Key 与当前作业的密钥文件 |
| 端口占用 | 检查 `qwen-api-<JOB_ID>.err` 或 `.out`，改用未占用端口后重新提交 |
| 中文显示为 `\uXXXX` | JSON Unicode 转义通常不是乱码；用 `json.loads` 提取 `choices[0].message.content` |
| 回答中断，`finish_reason=length` | 提高请求中的 `max_tokens`，同时关注上下文和资源限制 |
| 生成速度慢 | 查看长上下文长度、显存分配、并发数及 Slurm 分配的 GPU；不要只比较单次短请求 |

## 12. 使用规范与参考资料

- 遵守模型许可证、使用要求及实验室数据管理规定。
- 对科研代码、结果和数学结论进行独立验证，不将模型输出直接视为实验事实。
- 不在公开仓库、作业日志或共享目录泄露 API Key、私人数据或访问令牌。
- GPU 任务必须通过 Slurm 申请，作业结束及时释放资源。
- 管理员升级模型与推理框架时保留版本、校验和与编译记录。

相关手册：

- [Lmod Modules](../software/modules.md)
- [Slurm 作业提交](../cluster/slurm-submit.md)
- [共享数据集](../data/shared-data.md)
- [端口占用](../cluster/port-use.md)

外部资料：

- [Qwen3.8-27B GGUF 模型仓库](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF)
- [HF-Mirror 下载说明](https://hf-mirror.com/)
- [llama.cpp 官方仓库](https://github.com/ggml-org/llama.cpp)
- [llama.cpp CUDA 编译说明](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [llama.cpp 多 GPU 使用说明](https://github.com/ggml-org/llama.cpp/blob/master/docs/multi-gpu.md)
- [llama-server API 文档](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)

### 将本章加入 MkDocs

建议将文件保存到 `docs/software/using-llms.md`，并在 `mkdocs.yml` 的“软件环境”导航下添加：

```yaml
nav:
  - 软件环境:
      - 使用大语言模型: software/using-llms.md
```

如果 `mkdocs.yml` 已经有其他“软件环境”条目，应**只添加** `- 使用大语言模型: software/using-llms.md`，不要用上面的片段覆盖原有整个 `nav`。

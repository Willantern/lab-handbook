# Lmod Modules

## 1. Lmod 是什么？

Lmod 是一种环境模块管理工具。它允许用户通过 `module load` 切换软件版本，而不需要手动修改大量环境变量。

例如，实验室服务器可以提供多个 GCC 和 Java 版本：

```bash
module load gcc/11
module load java/21
```

加载模块后，`PATH`、`JAVA_HOME` 等环境变量会相应改变。

**注意：Module 不等于虚拟机或容器。** 它主要负责配置软件运行环境，并不会自动隔离文件、进程或 GPU 设备。

## 2. 初始化与查看模块

登录服务器后，通常可以直接使用 `module`。如果当前 shell 中找不到该命令，可以初始化 Lmod：

```bash
source /etc/profile.d/z00_lmod.sh
```

查看所有可用模块：

```bash
module avail
```

搜索模块：

```bash
module spider gcc
module spider java
module spider apptainer
```

查看模块详情：

```bash
module show gcc/12
module show java/21
```

查看当前已加载的模块：

```bash
module list
```

## 3. 加载和卸载模块

```bash
# 加载 GCC 12
module load gcc/12

# 加载 Java 21
module load java/21

# 查看当前模块
module list

# 卸载指定模块
module unload java/21

# 卸载全部模块
module purge
```

如果某个软件有多个版本，可以加载另一个版本：

```bash
module load gcc/11
module load gcc/12
```

Lmod 通常会处理同一软件的版本切换。

也可以明确使用：

```bash
module swap gcc/11 gcc/12
```

实际行为取决于模块文件定义。切换后，应重新检查 `gcc --version` 和 `which gcc`，不要假设环境变量已经符合预期。

## 4. 当前服务器可用模块

以下为当前已配置的代表性模块：

| 模块 | 用途 |
|---|---|
| `gcc/11` | GCC 11 编译器 |
| `gcc/12` | GCC 12 编译器 |
| `java/11` | OpenJDK 11 |
| `java/17` | OpenJDK 17 |
| `java/21` | OpenJDK 21 |
| `java/25` | OpenJDK 25 |
| `conda/2026` | 公共 Anaconda/Conda 安装 |
| `apptainer/1.5.4` | Apptainer 容器工具 |

可用模块以 `module avail` 的实际输出为准。

## 5. GCC 使用示例

加载 GCC 12：

```bash
module load gcc/12

which gcc
gcc --version
g++ --version
```

编译 C++ 程序：

```bash
g++ -O2 -std=c++20 main.cpp -o main
./main
```

切换到 GCC 11：

```bash
module load gcc/11
gcc --version
g++ --version
```

检查实际调用的编译器：

```bash
which gcc
which g++
echo "$CC"
echo "$CXX"
```

不要将不同编译器版本的环境随意混合使用。对于依赖特定编译器 ABI 的第三方库，建议保持编译器和运行库的一致性。

## 6. Java 使用示例

加载 Java 21：

```bash
module load java/21

java -version
javac -version
echo "$JAVA_HOME"
```

编译和运行 Java 程序：

```bash
javac Hello.java
java Hello
```

切换到 Java 11：

```bash
module load java/11
java -version
javac -version
```

## 7. 加载公共 Conda

```bash
module load conda/2026

conda --version
which conda
echo "$CONDA_ROOT"
```

加载 Conda 模块只负责配置公共 Conda 的访问路径，不一定会自动激活某个 Python 环境。

激活 Conda 功能：

```bash
source "$CONDA_ROOT/etc/profile.d/conda.sh"
```

然后查看环境：

```bash
conda env list
```

如果需要使用某个公共环境，应按照管理员公布的环境名称或路径进行激活。

## 8. 加载 Apptainer

```bash
module load apptainer/1.5.4

apptainer --version
apptainer help
```

该模块提供容器运行工具，但并不意味着所有 PyTorch 镜像都已经部署完成。请使用管理员公布的镜像路径。

## 9. 在 Slurm 作业脚本中加载模块

批处理脚本应明确加载需要的软件模块：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=module-test
#SBATCH --partition=debug
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:05:00

set -euo pipefail

source /etc/profile.d/z00_lmod.sh
module load gcc/12
module load java/21

gcc --version
java -version
```

这样可以减少登录终端环境和批处理环境之间的差异。

## 10. 常见问题

### `module: command not found`

执行：

```bash
source /etc/profile.d/z00_lmod.sh
```

### 加载模块后仍然使用旧版本

检查：

```bash
module list
which gcc
gcc --version
```

### 找不到某个模块

执行：

```bash
module avail
module spider 软件名称
```

如果模块确实不存在，请联系管理员，不要自行假设模块名称。

## 11. 使用原则

- 通过 Module 选择软件版本。
- 不要随意修改公共模块文件。
- 不要把 Module 当作权限隔离工具。
- 对可复现的实验，记录使用的模块版本。

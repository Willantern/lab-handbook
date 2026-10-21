# Linux

本文介绍 Linux 终端的基本操作、文件管理、进程管理、系统资源查看和文件传输命令，适合实验室服务器的日常使用。

## 1. 终端与目录操作

| 命令 | 作用 |
|---|---|
| `pwd` | 显示当前目录 |
| `ls` | 列出文件 |
| `ls -lah` | 显示详细信息、隐藏文件和文件大小 |
| `cd /path/to/dir` | 进入指定目录 |
| `cd ~` | 返回个人主目录 |
| `cd ..` | 返回上一级目录 |
| `mkdir -p path/to/dir` | 创建目录，包括不存在的父目录 |
| `clear` | 清空终端显示 |
| `history` | 查看历史命令 |

示例：

```bash
# 查看当前位置
pwd

# 查看当前目录的全部文件
ls -lah

# 创建实验目录
mkdir -p ~/projects/experiment1

# 进入目录
cd ~/projects/experiment1
```

## 2. 文件和目录管理

| 命令 | 作用 |
|---|---|
| `cp file1 file2` | 复制文件 |
| `cp -r dir1 dir2` | 复制目录 |
| `mv old new` | 移动或重命名 |
| `rm file` | 删除文件 |
| `rmdir dir` | 删除空目录 |
| `find . -name "*.py"` | 搜索 Python 文件 |
| `grep "error" log.txt` | 搜索文本 |
| `file filename` | 查看文件类型 |
| `stat filename` | 查看文件元信息 |

示例：

```bash
# 查找当前目录及子目录中的 Python 文件
find . -type f -name "*.py"

# 查找日志中的错误信息
grep -in "error" run.log

# 查找最近修改的文件
find . -type f -mtime -1
```

注意：删除命令通常无法通过回收站恢复。执行 `rm -r` 或 `rm -rf` 前，应先检查目标路径，不要在不确定时使用递归强制删除。

## 3. 查看文件内容和日志

| 命令 | 作用 |
|---|---|
| `cat file` | 输出整个文件 |
| `less file` | 分页查看文件 |
| `head -n 20 file` | 查看前 20 行 |
| `tail -n 20 file` | 查看最后 20 行 |
| `tail -f file` | 实时查看日志 |
| `wc -l file` | 统计行数 |

例如：

```bash
# 查看日志末尾
tail -n 50 run.log

# 实时追踪日志
tail -f run.log

# 查找训练日志中的异常
grep -inE "error|exception|failed" run.log
```

在 `less` 中，按 `q` 退出。

## 4. 文件权限

Linux 权限由所有者、所属组和其他用户三部分组成。

```bash
# 查看权限
ls -l script.sh

# 给自己增加执行权限
chmod u+x script.sh

# 给文件所有者读写权限，其他用户只读
chmod 644 results.csv

# 给目录所有者完整权限，其他用户可读和进入
chmod 755 public-data
```

常见权限：

| 权限 | 含义 |
|---|---|
| `644` | 所有者可读写，其他人只读 |
| `755` | 所有者可读写执行，其他人可读执行 |
| `700` | 只有所有者可访问 |
| `600` | 只有所有者可读写 |

不要随意使用 `chmod -R 777`，这会给所有用户过宽的访问权限。

`sudo` 用于执行需要管理员权限的命令。普通实验用户不应尝试修改系统服务、公共软件或其他用户的文件。

## 5. 查看 CPU、内存和磁盘

```bash
# CPU 逻辑线程数量
nproc

# CPU 和进程概况
lscpu

# 查看内存和 swap
free -h

# 查看文件系统剩余空间
df -h

# 查看当前目录占用空间
du -sh .

# 查看目录下各子目录的空间
du -h --max-depth=1 .
```

查看进程：

```bash
# 查看自己的进程
ps -u "$USER"

# 交互式查看系统进程
top

# 如果安装了 htop
htop
```

`nproc` 显示的是当前进程可用的逻辑 CPU 数量；在 Slurm 作业中，它可能受作业资源限制影响。

## 6. 进程管理

```bash
# 查看自己的进程
ps -u "$USER"

# 搜索某个程序
pgrep -af python

# 结束指定进程
kill PID

# 必要时强制结束进程
kill -9 PID
```

优先使用普通 `kill`，只有进程无法正常退出时才考虑 `kill -9`。

对于通过 Slurm 提交的作业，应优先使用：

```bash
scancel JOB_ID
```

不要只结束一个 Python 子进程而遗留整个作业。

## 7. 压缩与解压

```bash
# 创建 tar.gz 压缩包
tar -czf results.tar.gz results/

# 解压 tar.gz
tar -xzf results.tar.gz

# 查看压缩包内容
tar -tzf results.tar.gz

# 解压 zip
unzip archive.zip

# 创建 zip
zip -r archive.zip results/
```

## 8. SSH 与文件传输

连接服务器：

```bash
ssh username@server-address
```

复制本地文件到服务器：

```bash
scp local_file username@server-address:~/uploads/
```

复制服务器文件到本地：

```bash
scp username@server-address:~/results.csv .
```

复制整个目录：

```bash
scp -r local_dir username@server-address:~/projects/
```

传输大目录或需要断点续传时，可以使用 `rsync`：

```bash
rsync -avP local_dir/ username@server-address:~/projects/local_dir/
```

具体连接地址、用户名和 SSH 认证方式以实验室管理员提供的信息为准。

## 9. 环境变量

```bash
# 查看环境变量
env

# 查看某个变量
echo "$HOME"
echo "$PATH"

# 设置当前终端的变量
export MY_VAR="example"

# 查看命令路径
which python
command -v gcc
```

环境变量通常只在当前 shell 及其子进程中生效。不要把密码或访问令牌写进公开脚本或 Git 仓库。

## 10. 推荐工作习惯

- 每个实验建立独立目录。
- 将代码、配置、日志和结果分开管理。
- 运行长时间任务时使用 Slurm，而不是依赖 SSH 终端一直保持连接。
- 重要数据至少保留一份独立备份。
- 删除或修改文件前确认路径。

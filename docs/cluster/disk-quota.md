# Linux 用户磁盘配额

本文说明实验室服务器的 Linux 用户磁盘配额、检查方法，以及新建用户时如何自动应用限制。

## 1. 当前配置

| 项目 | 当前配置 |
|---|---|
| 文件系统 | ext4 |
| 设备 | `/dev/sda2` |
| 挂载点 | `/`；`/home` 与根目录共用同一文件系统 |
| 配额类型 | Linux 用户配额（`usrquota`） |
| 普通用户上限 | 每人 50 GiB |
| 管理员 `huang` | 不设置个人配额 |
| 文件数量（inode）限制 | 暂不限制 |

根分区在 `/etc/fstab` 中的挂载行应包含 `usrquota`，例如：

```fstab
UUID=289ccc22-4122-4314-a612-d8dc66370039 / ext4 errors=remount-ro,usrquota 0 1
```

实际维护时应保留服务器当前正确的 UUID 和其他挂载参数，不要直接用示例覆盖整份 `/etc/fstab`。

## 2. 限制的计算方式

50 GiB 对应 `52428800` 个 KiB 配额块。软限制和硬限制均设置为 50 GiB，文件数量限制设为 `0`（不限制）：

```bash
sudo setquota -u USERNAME 52428800 52428800 0 0 /
```

将 `USERNAME` 替换为实际 Linux 用户名。

配额按**文件所有者**统计，作用于整个 `/dev/sda2` 文件系统，而不只是 `/home/用户名`。用户在该文件系统中拥有的文件都会计入其配额。由 `root` 或 `huang` 所有的共享软件和数据不会计入学生用户的个人配额；如果共享文件归学生用户所有，则会计入该用户的配额。

## 3. 检查配额状态

查看根分区的挂载选项：

```bash
findmnt -no TARGET,FSTYPE,OPTIONS /
```

输出应包含 `usrquota`。

检查用户配额是否开启：

```bash
sudo quotaon -p /
```

确认输出中包含：

```text
user quota on / (...) is on
```

查看所有用户的磁盘占用和限制：

```bash
sudo repquota -u /
```

查看某个用户：

```bash
sudo quota -s -u wlc
```

将 `wlc` 替换为要检查的用户名。`repquota` 中的 block 数值以 KiB 配额块显示；`soft` 和 `hard` 列为 `52428800` 时，表示 50 GiB。

## 4. 给现有普通用户统一设置 50 GiB

首次启用配额后，需要为现有用户单独设置限制。下面的命令会查找 UID 为 1000–59999 且使用正常登录 shell 的账户，并排除管理员 `huang`：

```bash
sudo bash <<'ROOT'
set -euo pipefail
LIMIT_KIB=52428800

while IFS= read -r username; do
    [[ "$username" == "huang" ]] && continue
    setquota -u "$username" "$LIMIT_KIB" "$LIMIT_KIB" 0 0 /
    echo "已设置 $username：50 GiB"
done < <(
    getent passwd |
    awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1}'
)
ROOT
```

执行后检查：

```bash
sudo repquota -u /
```

此操作不会给管理员 `huang` 设置限制，也不会修改 Slurm 的 CPU、GPU、内存或作业时长策略。

## 5. 新建用户时自动设置配额

`/home/huang/create-lab-user.sh` 在创建 Linux 用户和 Slurm 关联时，会自动设置 50 GiB 用户配额。脚本要求根文件系统的 `usrquota` 挂载选项和用户配额服务均已生效；若未启用，脚本会报错退出，而不会悄悄创建一个没有磁盘限制的用户。

使用方式：

```bash
sudo ~/create-lab-user.sh USERNAME undergrad
sudo ~/create-lab-user.sh USERNAME master
sudo ~/create-lab-user.sh USERNAME phd
```

等级只决定 Slurm Account/QOS；普通用户的磁盘配额均为 50 GiB。管理员 `huang` 不通过此脚本创建，也不受个人配额限制。

## 6. 调整或取消某个用户的配额

把某个用户的配额改成 30 GiB：

```bash
sudo setquota -u USERNAME 31457280 31457280 0 0 /
```

取消某个用户的块配额限制：

```bash
sudo setquota -u USERNAME 0 0 0 0 /
```

取消限制后，该用户在此文件系统上将不再受用户块配额限制。请谨慎执行。

## 7. 注意事项

- 配额是 Linux 文件系统级限制，与 Slurm 的 CPU、GPU、内存和作业时长限制相互独立。
- 本服务器的 `/` 和 `/home` 位于同一个 ext4 文件系统，因此不能把 `/home` 理解为单独的配额分区。
- `quotaon` 曾提示 ext4 的外部配额文件方式已弃用，但同时确认 `user quota on`。当前配置可用；后续可安排迁移到 ext4 原生配额功能，迁移前不要随意删除配额数据库文件。
- 服务器维护或重启后，可再次执行 `sudo quotaon -p /` 检查配额是否仍处于启用状态。

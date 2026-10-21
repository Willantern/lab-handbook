#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Lab server user provisioning script.
# Usage: sudo /home/huang/create-lab-user.sh <username> <undergrad|master|phd>

CLUSTER="lab-cluster"
ADMIN_USER="huang"
CRED_DIR="/home/huang/lab-user-credentials"
QUOTA_MOUNT="/"
QUOTA_KIB=52428800  # 50 GiB in KiB blocks

usage() {
    cat <<'USAGE'
用法：sudo ~/create-lab-user.sh <用户名> <等级>
等级：undergrad | master | phd
示例：sudo ~/create-lab-user.sh zyh phd
USAGE
}

fail() {
    echo "错误：$*" >&2
    exit 1
}

if [[ ${EUID} -ne 0 ]]; then
    fail "请使用 sudo 运行此脚本，例如：sudo ~/create-lab-user.sh zyh phd"
fi

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
fi

USERNAME="$1"
LEVEL="$2"

# Use a conservative Linux username pattern and prevent path injection.
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || \
    fail "用户名格式不合法。请使用小写字母开头，后续仅包含小写字母、数字、下划线或连字符，长度不超过 32。"
[[ "$USERNAME" != "$ADMIN_USER" ]] || fail "huang 是管理员账户，不能通过此脚本创建或覆盖。"

case "$LEVEL" in
    undergrad)
        ACCOUNT="undergrad"
        BASE_QOS="undergrad_qos"
        BURST_QOS="undergrad_burst"
        ;;
    master)
        ACCOUNT="master"
        BASE_QOS="master_qos"
        BURST_QOS="master_burst"
        ;;
    phd)
        ACCOUNT="phd"
        BASE_QOS="phd_qos"
        BURST_QOS="phd_burst"
        ;;
    *)
        usage >&2
        fail "未知等级：$LEVEL"
        ;;
esac

for cmd in useradd userdel chpasswd openssl setquota quotaon findmnt sacctmgr; do
    command -v "$cmd" >/dev/null 2>&1 || fail "缺少必要命令：$cmd"
done

# Ensure the root filesystem is mounted with user quota support and quotas are on.
MOUNT_OPTIONS="$(findmnt -n -o OPTIONS "$QUOTA_MOUNT")"
case ",${MOUNT_OPTIONS}," in
    *,usrquota,*) ;;
    *) fail "根文件系统没有 usrquota 挂载选项。请先检查 /etc/fstab 并启用用户配额。" ;;
esac
QUOTA_STATUS="$(quotaon -p "$QUOTA_MOUNT" 2>/dev/null)" || \
    fail "无法读取根文件系统的用户配额状态。"
if ! grep -Eqi '^user quota on / .* is on$' <<< "$QUOTA_STATUS"; then
    fail "根文件系统的用户配额当前未启用。请先执行 sudo quotaon -vu / 并确认 sudo quotaon -p /。"
fi

# Verify SlurmDBD/accounting configuration and required Slurm objects.
CLUSTER_LIST="$(sacctmgr -nP show cluster format=Cluster 2>/dev/null)" || \
    fail "无法查询 Slurm 集群；请检查 slurmdbd 和 accounting 配置。"
grep -Fxq "$CLUSTER" <<< "$CLUSTER_LIST" || \
    fail "Slurm 集群 $CLUSTER 不可用，请检查集群名称。"
ACCOUNT_LIST="$(sacctmgr -nP show account format=Account 2>/dev/null)" || \
    fail "无法查询 Slurm 账户。"
grep -Fxq "$ACCOUNT" <<< "$ACCOUNT_LIST" || \
    fail "Slurm 账户 $ACCOUNT 不存在。"
QOS_LIST="$(sacctmgr -nP show qos format=Name 2>/dev/null)" || \
    fail "无法查询 Slurm QOS。"
grep -Fxq "$BASE_QOS" <<< "$QOS_LIST" || \
    fail "Slurm QOS $BASE_QOS 不存在。"
grep -Fxq "$BURST_QOS" <<< "$QOS_LIST" || \
    fail "Slurm QOS $BURST_QOS 不存在。"

if getent passwd "$USERNAME" >/dev/null; then
    fail "Linux 用户 $USERNAME 已存在；为避免覆盖现有账户，本脚本不会继续。"
fi
ASSOCIATIONS="$(sacctmgr -nP show assoc where user="$USERNAME" format=User 2>/dev/null)" || \
    fail "无法查询 Slurm 用户关联。"
if grep -Fxq "$USERNAME" <<< "$ASSOCIATIONS"; then
    fail "Slurm 中已存在用户 $USERNAME 的关联；请先核实后再操作。"
fi

# Store the initial password in a directory readable only by huang.
id "$ADMIN_USER" >/dev/null 2>&1 || fail "找不到管理员本地账户 $ADMIN_USER。"
install -d -o "$ADMIN_USER" -g "$ADMIN_USER" -m 0700 "$CRED_DIR"

PASSWORD="$(openssl rand -hex 12)"  # 24 hexadecimal characters
LOCAL_CREATED=0
SLURM_CREATED=0

rollback() {
    local reason="$1"
    echo "错误：$reason" >&2
    if [[ "$SLURM_CREATED" -eq 1 ]]; then
        sacctmgr -i delete user where name="$USERNAME" cluster="$CLUSTER" account="$ACCOUNT" >/dev/null 2>&1 || true
    fi
    if [[ "$LOCAL_CREATED" -eq 1 ]]; then
        userdel -r "$USERNAME" >/dev/null 2>&1 || true
    fi
    exit 1
}

if ! useradd -m -s /bin/bash "$USERNAME"; then
    fail "创建 Linux 用户 $USERNAME 失败。"
fi
LOCAL_CREATED=1

if ! printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd; then
    rollback "设置初始密码失败，已尝试清理新建账户。"
fi

if ! sacctmgr -i add user \
    Name="$USERNAME" \
    Account="$ACCOUNT" \
    Cluster="$CLUSTER" \
    QOS="$BASE_QOS" \
    DefaultQOS="$BASE_QOS"; then
    rollback "添加 Slurm 用户关联失败，已尝试清理新建账户。"
fi
SLURM_CREATED=1

# Grant the tier's burst QOS as an optional larger-resource choice.
if ! sacctmgr -i modify user where name="$USERNAME" set QOS+="$BURST_QOS"; then
    rollback "授予扩展 QOS $BURST_QOS 失败，已尝试清理新建账户。"
fi

# Apply the same 50 GiB hard cap to every ordinary account, regardless of tier.
if ! setquota -u "$USERNAME" "$QUOTA_KIB" "$QUOTA_KIB" 0 0 "$QUOTA_MOUNT"; then
    rollback "设置 50 GiB 磁盘配额失败，已尝试清理新建账户。"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
CRED_FILE="$CRED_DIR/${USERNAME}_${TIMESTAMP}.txt"
if ! {
    printf '用户名：%s\n' "$USERNAME"
    printf '密码：%s\n' "$PASSWORD"
    printf '等级：%s\n' "$LEVEL"
    printf 'Slurm Account：%s\n' "$ACCOUNT"
    printf '默认 QOS：%s\n' "$BASE_QOS"
    printf '扩展 QOS：%s\n' "$BURST_QOS"
    printf '磁盘配额：50 GiB\n'
    printf '创建时间：%s\n' "$(date '+%F %T %Z')"
} > "$CRED_FILE"; then
    echo "警告：无法写入密码记录文件。请立即安全地记录本次输出的密码。" >&2
else
    chown "$ADMIN_USER:$ADMIN_USER" "$CRED_FILE"
    chmod 0600 "$CRED_FILE"
fi

printf '\n========== 用户创建成功 ==========\n'
printf '用户名：%s\n' "$USERNAME"
printf '密码：%s\n' "$PASSWORD"
printf '等级：%s\n' "$LEVEL"
printf 'Slurm Account：%s\n' "$ACCOUNT"
printf '默认 QOS：%s\n' "$BASE_QOS"
printf '扩展 QOS：%s\n' "$BURST_QOS"
printf '磁盘配额：50 GiB（硬限制）\n'
printf '密码记录：%s\n' "$CRED_FILE"
printf '==================================\n'
printf '请通过安全渠道向用户交付密码。\n'

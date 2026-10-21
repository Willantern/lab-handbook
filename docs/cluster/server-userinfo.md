# 用户信息

| 用户名 | UID | 用户类型 | 系统权限 | Slurm 账户 | 默认 QOS | 责任人 |
|---|---|---|---|---|---|---|
| `huang` | 1000 | 管理员 | sudo | `admin` | `normal` | `吴联程` | 
| `wlc` | 1001 | 博士生 | 普通用户 | `phd` | `phd_qos` | `吴联程` | 
| `hzx` | 1002 | 博士生 | 普通用户 | `phd` | `phd_qos` | `黄至行` | 
| `zyh` | 1003 | 博士生 | 普通用户 | `phd` | `phd_qos` | `张云辉` | 

## 用户资源权限

- `huang`：负责服务器管理与 Slurm 配置。

## 查看用户
查看当前 Linux 用户：

```bash
getent passwd | awk -F: \
  '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {
    printf "%-16s UID=%-6s HOME=%-25s SHELL=%s\n",
           $1, $3, $6, $7
  }'
```
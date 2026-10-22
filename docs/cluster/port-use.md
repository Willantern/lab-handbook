# 目前端口占用

| 端口  | 协议 | 监听地址       | 进程/服务            | 用途说明                     |
|-------|------|----------------|----------------------|------------------------------|
| 22    | TCP  | 0.0.0.0 / [::] | sshd                 | SSH 远程登录                 |
| 6817  | TCP  | 0.0.0.0        | slurmctld            | Slurm 控制器                 |
| 6818  | TCP  | 0.0.0.0        | slurmd               | Slurm 计算节点守护进程       |
| 6819  | TCP  | 0.0.0.0        | slurmdbd             | Slurm 数据库守护进程         |
| 3141  | TCP  | 127.0.0.1      | devpi-server         | devpi PyPI 私有包服务        |
| 3306  | TCP  | 127.0.0.1      | mariadbd             | MariaDB 数据库               |
| 53    | TCP/UDP | 127.0.0.53%lo | systemd-resolve      | 本地 DNS 解析                |
| 631   | TCP  | 127.0.0.1 / [::1] | cupsd             | CUPS 打印服务                |
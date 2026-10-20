# SSH 登录

登录地址、端口和账号由管理员单独提供。不要将内部登录地址或个人账号信息直接写入公开手册，除非实验室明确允许公开。

## 连接示例

在自己的电脑终端运行：

```bash
ssh <username>@<login-host>
```

如果管理员指定了非默认端口：

```bash
ssh -p <port> <username>@<login-host>
```

将尖括号中的占位符替换为管理员提供的信息；不要原样输入。

## SSH 密钥

如实验室要求使用 SSH 密钥，请按照管理员提供的流程生成、登记和管理密钥。私钥应保存在自己的电脑上，不要上传到 GitHub、共享目录或聊天群。

## 登录问题

- `Permission denied`：确认账号、密钥和服务器授权。
- `Connection timed out`：确认网络、VPN、地址和端口。
- `Host key verification failed`：不要盲目删除记录；先通过可信渠道核对服务器主机密钥是否发生变化。

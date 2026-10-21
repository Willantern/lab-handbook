# SSH 登录

登录地址、端口和账号由管理员单独提供。不要将内部登录地址或个人账号信息对外提供。

## 连接示例
假设用户名为 `wlc`, 服务器的登陆地址为 `192.168.1.98`。

### windows
按 `Win+R` 打开运行对话框，输入 `cmd` 后回车打开自己电脑的终端。

在终端输入命令：

```bash
ssh <username>@<login-host>
```
举个例子：
```bash
ssh wlc@192.168.1.98
```
### mac
打开 `terminal`。 ssh命令如windows操作系统一样。

### linux
按`Ctrl+Alt+T`打开终端。ssh命令如windows操作系统一样。

### vscode
1. 安装完vscode，在应用商店拓展的搜索栏输入 `Remote - SSH`并安装。
2. 打开应用拓展的设置，弹出`/Users/<username>/.ssh/config`
3. 配置config文件

举个例子：
```bash
Host server1 # 用户偏好命名
    HostName 192.168.1.98 # 登陆地址
    User wlc # 用户名
```

## SSH 密钥
实测下来`mac/linux`电脑密钥链接会很方便。

如果要使用 SSH 密钥，私钥应保存在自己的电脑上，不要上传到 GitHub、共享目录或聊天群。

## 登录问题

- `Permission denied`：确认账号、密钥和服务器授权。
- `Connection timed out`：确认网络、VPN、地址和端口。
- `Host key verification failed`：不要盲目删除记录；先通过可信渠道核对服务器主机密钥是否发生变化。

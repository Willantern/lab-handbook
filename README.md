# 实验室计算平台用户手册

基于 **MkDocs + Material for MkDocs** 的实验室用户手册模板，可部署到 GitHub Pages。

## 特性

- 中文文档，按快速开始、集群、软件、数据、实验流程和故障排查分区。
- MkDocs Material 主题、站内搜索、导航标签和代码复制。
- GitHub Actions 自动构建并部署到 GitHub Pages。
- 文档内容尽量使用可复用的命令模板；集群名称、分区、路径和模块版本均可按实际环境调整。

## 本地预览

建议使用 Python 3.11 或 3.12。

```bash
conda create -n lab-handbook python=3.12

python -m pip install -r requirements.txt

mkdocs serve
```

浏览器打开终端显示的本地地址，通常是 `http://127.0.0.1:8000/`。

构建静态网站：

```bash
mkdocs build --strict
```

生成的网站位于 `site/` 目录。`site/` 已加入 `.gitignore`，通常不需要提交。

## 部署到 GitHub Pages

1. 在 GitHub 创建一个仓库，例如 `lab-handbook`。
2. 将本项目提交并推送到 `main` 分支。
3. 修改 `mkdocs.yml` 中的 `site_url` 和 `repo_url`，替换为你自己的 GitHub 用户名和仓库名。
4. 打开仓库 **Settings → Pages**，将 **Build and deployment → Source** 设置为 **GitHub Actions**。
5. 推送到 `main`，或在 **Actions** 页面手动运行 `Deploy MkDocs to GitHub Pages`。
6. 等待工作流成功后，从 **Settings → Pages** 查看网站地址。

工作流使用 GitHub Actions 官方 Pages 部署流程：构建 `site/`、上传 Pages artifact，再发布到 GitHub Pages。

## 维护约定

- 新增页面时，将 Markdown 文件放在合适的 `docs/` 子目录，并同步更新 `mkdocs.yml` 的 `nav`。
- 面向用户的命令应标明执行位置（登录节点、计算节点、容器内或本地电脑）。
- 不要提交密码、令牌、私钥、个人数据、内部 IP 或不适合公开的主机信息。
- 公开仓库中只放通用示例。真实登录地址、账号申请流程和内部数据访问规则，应在确认允许公开后再补充。
- 修改软件版本、分区或路径时，应同步更新相关页面，避免不同章节出现不一致。

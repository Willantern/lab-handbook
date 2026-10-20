# 实验室计算平台用户手册

欢迎使用实验室计算平台。本手册介绍如何登录服务器、提交 Slurm 作业、加载软件模块、运行容器以及访问共享数据集。

## 从哪里开始？

<div class="grid cards" markdown>

-   :material-rocket-launch: **快速开始**

    ---

    了解登录方式和首次使用前需要确认的事项。

    [:octicons-arrow-right-24: 开始使用](getting-started/index.md)

-   :material-calendar-clock: **提交计算任务**

    ---

    通过 Slurm 申请 CPU、内存和 GPU 资源。

    [:octicons-arrow-right-24: Slurm 作业](cluster/slurm.md)

-   :material-package-variant: **软件环境**

    ---

    使用 Lmod、Conda 和 Apptainer 选择软件版本。

    [:octicons-arrow-right-24: 软件环境](software/modules.md)

-   :material-database: **共享数据集**

    ---

    了解公共数据集的位置、权限和使用规范。

    [:octicons-arrow-right-24: 数据管理](data/shared-data.md)

</div>

## 使用前请注意

- 计算任务应通过 Slurm 提交，不要在登录节点执行长时间、高负载的训练。
- 共享软件和数据集默认只读；实验结果应保存到个人或项目目录。
- 示例中的分区、模块名、文件路径和资源数量是模板。请以管理员公布的当前配置为准。
- 本手册可能部署在公开的 GitHub Pages 上。不要在文档中提交密码、私钥、访问令牌或不适合公开的基础设施信息。

## 平台信息

以下内容由管理员维护，部署前请按实际情况填写：

| 项目 | 当前配置 |
|---|---|
| 登录地址 | `由管理员提供` |
| Slurm 分区 | `由管理员提供` |
| 软件模块路径 | `由管理员提供` |
| 公共数据目录 | `由管理员提供` |
| 支持与反馈 | `由管理员提供` |

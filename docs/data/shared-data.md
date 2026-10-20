# 共享数据集

公共数据集由管理员或项目负责人维护。Lmod 可以提供统一的数据路径变量，但真正保存数据的是共享文件系统，不是模块系统本身。

## 推荐目录结构

以下仅为示例：

```text
/data/datasets/
├── moving-mnist/
│   ├── v1/
│   └── v2/
├── imagenet/
│   └── v1/
└── project-dataset/
    └── v1/
```

## 使用原则

- 阅读数据集的许可证、引用要求和访问条件。
- 公共数据默认只读，实验输出写入自己的项目或结果目录。
- 不要擅自重命名、覆盖或删除共享数据。
- 同一个数据集的不同版本应分开存放，并记录来源、版本、校验和及更新时间。
- 含个人信息、受限数据或第三方未授权数据，不得放入公开目录或公开文档。

## 通过环境变量访问

如果管理员提供了数据集模块：

```bash
module avail dataset
module load dataset/moving-mnist/1
echo "$MOVING_MNIST_ROOT"
```

Python 中读取：

```python
import os
from pathlib import Path

data_root = Path(os.environ["MOVING_MNIST_ROOT"])
if not data_root.exists():
    raise FileNotFoundError(data_root)

print(data_root)
```

若未提供模块，请使用管理员公布的路径，不要自行假定目录存在。

## 容器中访问共享数据

```bash
apptainer exec \
  --bind "/data/datasets:/data/datasets:ro" \
  /opt/apps/containers/example.sif \
  python /workspace/train.py
```

多节点作业中，所有相关计算节点都必须能够访问同一数据路径，或采用管理员批准的数据分发方案。

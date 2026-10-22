# Pytorch 不同版本共享
目前通过devpi来提前预下载pytorch的依赖包。
## 目前支持

### Pytorch 2.14
目前支持`python 3.10` `python 3.11` `python 3.12` `python 3.13`，安装命令为:

```bash
pip install \
  "torch==2.14.1+cu132" \
  "torchvision==0.29.1+cu132"
```

如果要在conda环境安装其他版本的Pytorch请先联系管理员。
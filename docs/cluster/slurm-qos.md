# Slurm QOS 与分级资源管理

本文介绍实验室当前的 Quality of Service（QOS）配置，包括本科生、硕士生和博士生的常规资源限制、弹性资源策略、调度优先级及相关管理命令。

## 1. QOS 的作用

QOS 是 Slurm 中用于定义作业服务等级和资源限制的机制。

当前使用两类 QOS：

- **常规 QOS：** 用于学生日常实验，资源上限相对保守。
- **弹性 QOS：** 在需要更多资源时，由用户主动申请更高的资源上限。

目前共有以下 QOS：

| 等级 | 常规 QOS | 弹性 QOS |
|---|---|---|
| 管理员 | `normal` | 未配置专用弹性 QOS |
| 本科生 | `undergrad_qos` | `undergrad_burst` |
| 硕士生 | `master_qos` | `master_burst` |
| 博士生 | `phd_qos` | `phd_burst` |

`normal` 当前没有设置 QOS 级别的显式资源上限，主要用于管理员账户。不要将其随意授予学生账户。

## 2. 常规 QOS 配置

当前常规 QOS 如下。

| 参数 | `undergrad_qos` | `master_qos` | `phd_qos` |
|---|---:|---:|---:|
| Priority | 10 | 50 | 100 |
| MaxWall | 12 小时 | 2 天 | 3 天 |
| MaxJobsPerUser | 2 | 3 | 4 |
| MaxSubmitJobsPerUser | 10 | 20 | 30 |
| MaxTRESPerJob：CPU | 16 | 32 | 64 |
| MaxTRESPerJob：内存 | 32 GiB | 64 GiB | 128 GiB |
| MaxTRESPerJob：GPU | 1 | 1 | 2 |
| MaxTRESPerUser：CPU | 24 | 48 | 96 |
| MaxTRESPerUser：内存 | 48 GiB | 96 GiB | 160 GiB |
| MaxTRESPerUser：GPU | 1 | 1 | 2 |
| GrpTRES：CPU | 64 | 128 | 192 |
| GrpTRES：内存 | 96 GiB | 160 GiB | 224 GiB |
| GrpTRES：GPU | 2 | 3 | 4 |

三个常规 QOS 均启用了 `DenyOnLimit`。

## 3. 弹性 QOS 配置

弹性 QOS 允许用户在需要更多计算资源时申请更大的作业资源上限。

| 参数 | `undergrad_burst` | `master_burst` | `phd_burst` |
|---|---:|---:|---:|
| Priority | 10 | 50 | 100 |
| MaxWall | 12 小时 | 2 天 | 3 天 |
| MaxJobsPerUser | 2 | 3 | 4 |
| MaxSubmitJobsPerUser | 10 | 20 | 30 |
| MaxTRESPerJob：CPU | 32 | 64 | 256 |
| MaxTRESPerJob：内存 | 64 GiB | 128 GiB | 240 GiB |
| MaxTRESPerJob：GPU | 1 | 2 | 4 |
| MaxTRESPerUser：CPU | 48 | 96 | 256 |
| MaxTRESPerUser：内存 | 96 GiB | 160 GiB | 240 GiB |
| MaxTRESPerUser：GPU | 1 | 2 | 4 |
| GrpTRES：CPU | 96 | 160 | 256 |
| GrpTRES：内存 | 128 GiB | 192 GiB | 240 GiB |
| GrpTRES：GPU | 2 | 3 | 4 |

三个弹性 QOS 均启用了 `DenyOnLimit`。

博士生弹性 QOS 的上限接近整台服务器的可用资源，因此单个博士生作业可以申请大量 CPU、内存和 GPU。但这不代表系统为其预留了这些资源。

## 4. QOS 参数说明

### 4.1 优先级

`Priority` 用于参与作业优先级计算。数值越高，通常越有利于作业在队列竞争中获得较高优先级。

当前配置为：

| QOS | Priority |
|---|---:|
| `normal` | 0 |
| 本科生 | 10 |
| 硕士生 | 50 |
| 博士生 | 100 |

当前 Slurm 使用多因子调度，因此实际作业优先级还受到等待时间和 Fairshare 等因素影响。

### 4.2 MaxWallDurationPerJob

单个作业允许运行的最长时间。

例如：

```text
MaxWallDurationPerJob=3-00:00:00
```

表示最长运行 3 天。

作业时间同时受到分区 `MaxTime` 的限制，因此实际允许的最长时间取分区和 QOS 两者中更严格的限制。

### 4.3 MaxJobsPerUser

限制单个用户在该 QOS 下同时运行的作业数量。

例如：

```text
MaxJobsPerUser=4
```

表示每位用户在该 QOS 下最多同时运行 4 个作业。

### 4.4 MaxSubmitJobsPerUser

限制单个用户在该 QOS 下可提交的作业数量，包括排队及运行中的作业。

### 4.5 MaxTRESPerJob

限制单个作业能够申请的资源上限。

例如：

```text
MaxTRESPerJob=cpu=64,mem=128G,gres/gpu=2
```

表示单个作业最多申请 64 个 Slurm CPU 单位、128 GiB 内存及 2 张 GPU。

### 4.6 MaxTRESPerUser

限制同一用户在该 QOS 下作业的资源使用总量。

例如：

```text
MaxTRESPerUser=cpu=96,mem=160G,gres/gpu=2
```

该限制作用于用户在对应 QOS 下的资源使用，而不是服务器上所有用户的总资源。

### 4.7 GrpTRES

限制使用同一 QOS 的所有用户所运行作业的资源总量。

例如：

```text
GrpTRES=cpu=192,mem=224G,gres/gpu=4
```

表示该 QOS 下的运行作业总体受到 CPU、内存和 GPU 总量限制。

需要注意：常规 QOS 与弹性 QOS 的 `GrpTRES` 分别计算，不是两个 QOS 的合并总限额。实际作业仍然不能分配超过节点可用资源的资源量。

### 4.8 DenyOnLimit

`DenyOnLimit` 用于在作业违反相应 QOS 限额时拒绝提交，而不是允许明显超限的请求无限等待。

它并不意味着服务器只要繁忙就拒绝所有作业。资源暂时不足和违反 QOS 硬限制是两种不同情况。

## 5. 当前调度优先级配置

当前 `/etc/slurm/slurm.conf` 使用：

```ini
PriorityType=priority/multifactor
PriorityDecayHalfLife=14-0
PriorityMaxAge=7-0
PriorityWeightAge=1000
PriorityWeightFairshare=5000
PriorityWeightQOS=10000
```

账户 Fairshare：

| 账户 | Fairshare |
|---|---:|
| `undergrad` | 1 |
| `master` | 2 |
| `phd` | 4 |

Fairshare 体现不同账户在公平共享调度中的相对权重，不等于固定资源配额。

当前没有启用作业抢占。即使博士生作业具有更高优先级，也不会因此自动终止正在运行的本科生或硕士生作业。

## 6. 如何创建 QOS

以下为创建新 QOS 的基本示例：

```bash
sudo sacctmgr -i add qos \
  Name=example_qos \
  Priority=20 \
  MaxWallDurationPerJob=12:00:00 \
  MaxJobsPerUser=2 \
  MaxSubmitJobsPerUser=10 \
  MaxTRESPerJob=cpu=16,mem=32G,gres/gpu=1 \
  MaxTRESPerUser=cpu=24,mem=48G,gres/gpu=1 \
  GrpTRES=cpu=64,mem=96G,gres/gpu=2
```

启用超限拒绝：

```bash
sudo sacctmgr -i modify qos \
  where name=example_qos \
  set Flags+=DenyOnLimit
```

注意：当前集群已经存在上述六个等级 QOS，不要重复执行创建命令。需要修改现有 QOS 时，使用 `modify qos`。

## 7. 如何修改现有 QOS

例如，将博士生弹性 QOS 的单作业内存上限修改为 200 GiB：

```bash
sudo sacctmgr -i modify qos \
  where name=phd_burst \
  set MaxTRESPerJob=cpu=256,mem=200G,gres/gpu=4
```

如果需要调整运行时间：

```bash
sudo sacctmgr -i modify qos \
  where name=phd_burst \
  set MaxWallDurationPerJob=2-00:00:00
```

修改前应先检查当前配置，并确认新的上限不会与节点容量和实验室使用政策冲突。

## 8. 如何将 QOS 授权给账户和用户

先允许整个学生等级账户使用对应弹性 QOS：

```bash
sudo sacctmgr -i modify account \
  where name=undergrad set QOS+=undergrad_burst

sudo sacctmgr -i modify account \
  where name=master set QOS+=master_burst

sudo sacctmgr -i modify account \
  where name=phd set QOS+=phd_burst
```

对于已经建立的用户关联，也应确认用户本身具有相应权限。例如：

```bash
sudo sacctmgr -i modify user \
  where name=hzx set QOS+=phd_burst

sudo sacctmgr -i modify user \
  where name=wlc set QOS+=phd_burst
```

为用户配置默认 QOS：

```bash
sudo sacctmgr -i modify user \
  where name=hzx set DefaultQOS=phd_qos
```

普通作业默认使用常规 QOS；用户在提交弹性作业时，需要显式指定弹性 QOS。

## 9. 如何查看当前 QOS

查看完整 QOS 参数：

```bash
sudo sacctmgr -P show qos \
  format=Name,Priority,MaxWall,MaxTRESPerJob,MaxTRESPerUser,GrpTRES,Flags
```

查看用户与账户的关联：

```bash
sudo sacctmgr show assoc \
  where account=phd \
  format=Cluster,Account,User,Fairshare,QOS,DefaultQOS
```

查看 Slurm 的强制记账与限额设置：

```bash
scontrol show config | grep -i AccountingStorageEnforce
```

当前预期为：

```text
AccountingStorageEnforce = associations,limits,qos
```

该配置用于强制执行账户关联、资源限制及 QOS 相关策略。

## 10. 用户如何使用弹性资源

普通博士生作业：

```bash
sbatch \
  --partition=compute \
  --account=phd \
  --qos=phd_qos \
  --cpus-per-task=16 \
  --mem=32G \
  --gres=gpu:1 \
  --time=12:00:00 \
  experiment.sbatch
```

博士生弹性作业：

```bash
sbatch \
  --partition=compute \
  --account=phd \
  --qos=phd_burst \
  --cpus-per-task=96 \
  --mem=160G \
  --gres=gpu:2 \
  --time=2-00:00:00 \
  experiment.sbatch
```

第二种方式允许申请更大的资源上限，但不保证作业立即运行。

如果资源暂时不足，作业可能进入 `PENDING` 状态；如果请求超过 QOS 或分区的硬限制，则可能被拒绝。

## 11. 当前弹性调度策略的边界

当前策略采用“常规 QOS + 弹性 QOS”，实现的是用户主动选择不同资源上限，而不是自动动态修改 QOS。

- 服务器空闲时，用户可以申请更大的弹性资源。
- 服务器资源不足时，作业等待资源释放。
- 作业不能突破其选定 QOS 的硬限制。
- 高优先级影响排队顺序，但不会自动抢占正在运行的作业。
- 常规 QOS 与弹性 QOS 的用户资源限制分别计算；如需对用户跨 QOS 的全部作业设置统一总限额，需要另外规划账户级限制。

这种设计适合当前单节点实验室服务器，后续可以根据实际作业等待时间、CPU 利用率、GPU 利用率和用户使用情况调整参数。

# 故障排查

遇到问题时，优先收集完整命令、错误输出、作业 ID 和对应日志。不要在没有证据时直接重装软件或修改系统配置。

## `module: command not found`

检查 Lmod 是否安装，以及 shell 初始化脚本位置：

```bash
command -v lmod
ls /etc/profile.d/*lmod*
```

如果管理员确认使用以下脚本，可以执行：

```bash
source /etc/profile.d/z00_lmod.sh
```

## 作业一直处于 `PENDING`

```bash
squeue -u "$USER"
scontrol show job <jobid>
sinfo
```

检查 `Reason` 字段、分区状态、资源申请是否过大，以及是否存在排队限制。

## 作业很快变成 `FAILED`

```bash
scontrol show job <jobid>
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,MaxRSS
cat <job-output-file>
cat <job-error-file>
```

常见原因包括脚本路径错误、命令不存在、环境没有加载、内存不足或程序返回非零退出码。

## 容器中找不到代码或数据

检查容器启动命令中的 `--bind` 路径。宿主机源路径必须存在，容器内路径必须与程序使用的路径一致。

## `torch.cuda.is_available()` 为 `False`

依次检查：

1. Slurm 是否成功分配 GPU。
2. 主机 `nvidia-smi` 是否正常。
3. 容器启动时是否使用 `--nv`。
4. 容器内 PyTorch 是否包含匹配的 CUDA 支持。
5. 是否存在驱动兼容性或 GPU 设备访问限制。

## 联系管理员时请提供

- 执行时间和作业 ID。
- 运行的命令或 Slurm 脚本。
- 完整错误信息与相关日志。
- `scontrol show job <jobid>` 和 `sacct` 的输出（如适用）。
- 不要发送密码、私钥、令牌或其他秘密信息。

#!/bin/bash
nvidia-smi -pm 1
# 自动检测NVIDIA显卡数量
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -n 1)

# 如果无法获取显卡数量，则默认为1
if [ -z "$GPU_COUNT" ] || [ "$GPU_COUNT" -eq 0 ]; then
    GPU_COUNT=1
fi

echo "检测到 $GPU_COUNT 个NVIDIA显卡"

# 执行性能测试
echo "开始执行NCCL性能测试..."
/home/aisuan/nccl/all_reduce_perf -b 256M -e 20G -f 2 -g $GPU_COUNT 



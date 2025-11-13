#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: $0 <devices>"
    echo "Example: $0 3,4,5"
    exit 1
fi
devices="$1"
ngpus=$(echo -n "$devices" | awk -F',' '{ print NF }')

echo "Driver: CUDA_VISIBLE_DEVICES=$devices"
echo "Count: ${ngpus}"

# 执行NCCL测试
 bash -c "CUDA_VISIBLE_DEVICES="$devices" NCCL_DEBUG=ERROR /home/aisuan/nccl/all_reduce_perf -b 256M -e 20G -f 2 -g '${ngpus}'"

#!/bin/bash

INPUT_CMD="nvidia-smi -q"
if [ "$1" == "--debug" ]; then
    if [ -n "$2" ]; then
        INPUT_CMD="cat $2"
    else
        echo "请指定输入文件"
        exit 1
    fi
fi

INPUT=$($INPUT_CMD 2>/dev/null)
if [ -z "$INPUT" ]; then
    echo "无法获取nvidia-smi数据"
    exit 1
fi

# 解析 dmidecode 输出，生成 Bus Address 到 Designation 的映射
DMIDECODE_OUTPUT=$(dmidecode -t slot 2>/dev/null)
if [ "$1" == "--debug" ]; then
    if [ -n "$2" ]; then
        DMIDECODE_OUTPUT=$(cat dmi2.txt 2>/dev/null)
    else
        exit 1
    fi
fi
declare -A BUS_TO_SLOT
current_bus=""
current_designation=""

while IFS= read -r line; do
    if [[ $line =~ ^Handle ]]; then  # 遇到新的Handle，处理前一个块的信息
        if [ -n "$current_bus" ] && [ -n "$current_designation" ]; then
            BUS_TO_SLOT[$current_bus]="$current_designation"
            # echo $current_bus $current_designation  #debug
        fi
        current_bus=""
        current_designation=""
    elif [[ $line =~ Bus\ Address:\ ([0-9A-Fa-f:]+\.[0-9]) ]]; then
        current_bus=$(echo ${BASH_REMATCH[1]} | tr '[:upper:]' '[:lower:]')
    elif [[ $line =~ Designation:\ (.+) ]]; then
        current_designation=${BASH_REMATCH[1]}
    fi
done <<< "$DMIDECODE_OUTPUT"

# 处理最后一个块的信息
if [ -n "$current_bus" ] && [ -n "$current_designation" ]; then
    BUS_TO_SLOT[$current_bus]="$current_designation"
    # echo $current_bus $current_designation   #debug
fi



# 存储所有GPU信息的数组
declare -a GPU_DATA_ARRAY

gpu_idx=0
current_gpu_bus=""
current_gpu_model=""
current_gpu_memory=""
current_gpu_power=""
current_gpu_sn=""
current_gpu_vbios=""
gpu_power_block=0
gpu_pci_block=0
pcie=""
while IFS= read -r line; do
    # GPU起始
    if [[ $line =~ ^GPU\ ([0-9A-Fa-f:]+) ]]; then
        # 如果已经收集到完整的GPU信息，则存储它
        if [ -n "$current_gpu_model" ]; then
            # 计算 memory_gb
            memory_gb="N/A"
            if [[ "$current_gpu_memory" =~ ^[0-9]+$ ]]; then
                memory_gb=$(echo "scale=2; $current_gpu_memory / 1024" | bc) 
            fi
            [ -z "$current_gpu_power" ] && current_gpu_power="N/A"
            [ -z "$current_gpu_sn" ] && current_gpu_sn="N/A"
            [ -z "$current_gpu_vbios" ] && current_gpu_vbios="N/A"

            current_slot_val=$(echo "${BUS_TO_SLOT[$current_gpu_bus]:-"N/A"}" | xargs)

            GPU_DATA_ARRAY+=("$gpu_idx|$current_slot_val|$current_gpu_bus|$current_gpu_model|${memory_gb}G|${current_gpu_power}W|$current_gpu_sn|$current_gpu_vbios")
            gpu_idx=$((gpu_idx+1))
        fi
        current_gpu_bus=$(echo "$line" | awk '{print $2}' | sed 's/^00000000:/0000:/' | tr '[:upper:]' '[:lower:]') # 转换为小写，并统一Bus Address格式
        current_gpu_model=""
        current_gpu_memory=""
        current_gpu_power=""
        current_gpu_sn=""
        current_gpu_vbios=""
        continue
    fi
    # Product Name
    if [[ $line =~ Product\ Name ]]; then
        current_gpu_model=$(echo "$line" | awk -F: '{print $2}' | xargs)
        continue
    fi
    # FB Memory Usage
    if [[ $line =~ FB\ Memory\ Usage ]]; then
        read -r mem_line
        if [[ $mem_line =~ Total ]]; then
            current_gpu_memory=$(echo "$mem_line" | awk -F: '{print $2}' | awk '{print $1}')
        fi
        continue
    fi
    #pci
    
        
    if [[ $line =~ GPU\ Link\ Info ]]; then
        gpu_pci_block=1
        # echo $line
        continue
    fi

    # if [[ $gpu_pci_block -eq 1 && $line =~ PCIe\ Generation ]]; then
    #     # 读取下一行（包含 Max 值）
    #     read next_line
    #     read current_line
    #     if [[ $next_line =~ Current.*:\ (.*) ]]; then
    #         echo "PCIe Generation Current: ${BASH_REMATCH}"
    #         echo $next_line
    #     fi
    # fi
# 当在 GPU Link Info 块中时，查找 Link Width 的 Current 值
    if [[ $gpu_pci_block -eq 1 && $line =~ Link\ Width ]]; then
        # 读取下一行（包含 Max 值）
        read next_line
        # 再下一行（包含 Current 值）
        read current_line
        # 提取 Current 值
        
        if [[ $current_line =~ Current.*:\ (.*) ]]; then
            # echo "Link Width Current: ${BASH_REMATCH[1]}"
            pcie=${BASH_REMATCH[1]}
        fi
        gpu_pci_block=0  # 重置标志
    fi

    # 检测进入GPU Power Readings块
    if [[ $line =~ GPU\ Power\ Readings ]]; then
        gpu_power_block=1
        continue
    fi
    # 检测离开GPU Power Readings块（遇到下一个section标题或 Module Power Readings）
    if [[ $gpu_power_block -eq 1 && ( $line =~ ^[A-Za-z] || $line =~ Module\ Power\ Readings ) ]]; then
        gpu_power_block=0
    fi
    # 只在GPU Power Readings块内匹配Max Power Limit
    if [[ $gpu_power_block -eq 1 && $line =~ Max\ Power\ Limit ]]; then
        val=$(echo "$line" | awk -F: '{print $2}' | awk '{print $1}' | awk -F. '{print $1}')
        [ "$val" != "" ] && current_gpu_power="$val"
        continue
    fi
    # Serial Number（精确匹配行首）
    if [[ $line =~ ^[[:space:]]*Serial\ Number ]]; then
        current_gpu_sn=$(echo "$line" | awk -F: '{print $2}' | xargs)
        continue
    fi
    # VBIOS Version
    if [[ $line =~ VBIOS\ Version ]]; then
        current_gpu_vbios=$(echo "$line" | awk -F: '{print $2}' | xargs)
        continue
    fi
done <<< "$INPUT"

# 存储最后一块GPU信息
if [ -n "$current_gpu_model" ]; then
    memory_gb="N/A"
    if [[ "$current_gpu_memory" =~ ^[0-9]+$ ]]; then
        memory_gb=$(echo "scale=2; $current_gpu_memory / 1024" | bc) 
    fi
    [ -z "$current_gpu_power" ] && current_gpu_power="N/A"
    [ -z "$current_gpu_sn" ] && current_gpu_sn="N/A"
    [ -z "$current_gpu_vbios" ] && current_gpu_vbios="N/A"

    current_slot_val=$(echo "${BUS_TO_SLOT[$current_gpu_bus]:-"N/A"}" | xargs)

    GPU_DATA_ARRAY+=("$gpu_idx|$current_slot_val|$current_gpu_bus|$current_gpu_model|${memory_gb}G|${current_gpu_power}W|$current_gpu_sn|$current_gpu_vbios")
fi

# 打印表头
printf "%-6s %-25s %-15s %-25s %-13s %-10s %-20s %-20s \n" "GPU id" "slot" "bus id" "Product Name" "Memory Usage" "Max Power" "SN" "VBIOS"
echo "--------------------------------------------------------------------------------------------------------"

# 遍历数组并打印所有GPU信息
for gpu_info_str in "${GPU_DATA_ARRAY[@]}"; do
    IFS='|' read -r idx slot bus model memory_gb power sn vbios <<< "$gpu_info_str"
    # 使用 sed 清理 slot 变量：去除所有空白字符，并修剪
    slot=$(echo "$slot" | sed 's/[[:space:]]\+/ /g' | xargs)

    # 使用 awk 格式化输出
    awk -v idx="$idx" -v slot="$slot" -v bus="$bus" -v model="$model" -v memory_gb="$memory_gb" -v power="$power" -v sn="$sn" -v vbios="$vbios" -v pcie="$pcie" 'BEGIN {
        printf "%-6s %-25s %-15s %-25s %-13s %-10s %-20s %-20s %-10s\n", "GPU " idx, slot, bus, model, memory_gb, power, sn, vbios ,"PCIE: " pcie
    }'
done
# 输出ECC信息
echo "-------------------------------------ECC INFO---------------------------------------------------"
printf "%-8s %-20s %-30s %-30s %-30s\n" "GPU ID" "ECC Mode Current" "ECC Errors Volatile" "ECC Errors Aggregate" "SRAM Sources"

gpu_idx=0
ecc_mode=""
ecc_volatile=""
ecc_aggregate=""
ecc_sram_sources=""
in_ecc_block=0
in_volatile=0
in_aggregate=0
in_sram_sources=0

# 清理数据的函数
clean_data() {
    local data="$1"
    # 移除前导和尾随空格
    data=$(echo "$data" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 将多个连续空格替换为单个空格
    data=$(echo "$data" | sed 's/[[:space:]]\+/ /g')

    echo "$data"
}

while IFS= read -r line; do
    # 检测新的GPU
    if [[ $line =~ ^GPU\ ([0-9A-Fa-f:]+) ]]; then
        # 输出前一个GPU的信息
        if [ -n "$ecc_mode" ]; then
            # 清理数据
            ecc_mode=$(clean_data "$ecc_mode")
            ecc_volatile=$(clean_data "$ecc_volatile")
            ecc_aggregate=$(clean_data "$ecc_aggregate")
            ecc_sram_sources=$(clean_data "$ecc_sram_sources")
            
            printf "%-8s %-20s %-30s %-30s %-30s\n" "GPU $gpu_idx" "$ecc_mode" "$ecc_volatile" "$ecc_aggregate" "$ecc_sram_sources"
            gpu_idx=$((gpu_idx+1))
        fi
        # 重置变量
        ecc_mode=""
        ecc_volatile=""
        ecc_aggregate=""
        ecc_sram_sources=""
        in_ecc_block=0
        in_volatile=0
        in_aggregate=0
        in_sram_sources=0
        continue
    fi

    # 检测ECC Mode
    if [[ $line =~ "ECC Mode" ]]; then
        in_ecc_block=1
        continue
    fi
    if [[ $in_ecc_block -eq 1 && $line =~ ^[[:space:]]*Current[[:space:]]*:[[:space:]]*(.+) ]]; then
        ecc_mode=${BASH_REMATCH[1]}
        in_ecc_block=0
        continue
    fi

    # 检测ECC Errors
    if [[ $line =~ "ECC Errors" ]]; then
        in_ecc_block=1
        continue
    fi
    if [[ $in_ecc_block -eq 1 && $line =~ "Volatile" ]]; then
        in_volatile=1
        in_aggregate=0
        in_sram_sources=0
        continue
    fi
    if [[ $in_ecc_block -eq 1 && $line =~ "Aggregate" && !($line =~ "SRAM Sources") ]]; then
        in_volatile=0
        in_aggregate=1
        in_sram_sources=0
        continue
    fi
    if [[ $in_ecc_block -eq 1 && $line =~ "Aggregate Uncorrectable SRAM Sources" ]]; then
        in_volatile=0
        in_aggregate=0
        in_sram_sources=1
        continue
    fi
    
    if [[ $in_volatile -eq 1 && $line =~ (SRAM|DRAM)\ (Correctable|Uncorrectable) ]]; then
        val=$(echo "$line" | awk -F: '{print $2}' | xargs)
        if [ -z "$ecc_volatile" ]; then
            ecc_volatile="$val"
        else
            ecc_volatile="$ecc_volatile $val"
        fi
        continue
    fi
    if [[ $in_aggregate -eq 1 && $line =~ (SRAM|DRAM)\ (Correctable|Uncorrectable|Threshold) ]]; then
        val=$(echo "$line" | awk -F: '{print $2}' | xargs)
        if [ -z "$ecc_aggregate" ]; then
            ecc_aggregate="$val"
        else
            ecc_aggregate="$ecc_aggregate $val"
        fi
        continue
    fi
    if [[ $in_sram_sources -eq 1 && $line =~ SRAM\ (L2|SM|Microcontroller|PCIE|Other) ]]; then
        val=$(echo "$line" | awk -F: '{print $2}' | xargs)
        if [ -z "$ecc_sram_sources" ]; then
            ecc_sram_sources="$val"
        else
            ecc_sram_sources="$ecc_sram_sources $val"
        fi
        continue
    fi
    # 检测离开ECC块
    if [[ $in_ecc_block -eq 1 && $line =~ ^[A-Za-z] && !($line =~ (Volatile|Aggregate|SRAM\ (L2|SM|Microcontroller|PCIE|Other)|(SRAM|DRAM)\ (Correctable|Uncorrectable))) ]]; then
        in_ecc_block=0
        in_volatile=0
        in_aggregate=0
        in_sram_sources=0
    fi
done <<< "$INPUT"

# 输出最后一个GPU的信息
if [ -n "$ecc_mode" ]; then
    # 清理数据
    ecc_mode=$(clean_data "$ecc_mode")
    ecc_volatile=$(clean_data "$ecc_volatile")
    ecc_aggregate=$(clean_data "$ecc_aggregate")
    ecc_sram_sources=$(clean_data "$ecc_sram_sources")
    
    printf "%-8s %-20s %-30s %-30s %-30s\n" "GPU $gpu_idx" "$ecc_mode" "$ecc_volatile" "$ecc_aggregate" "$ecc_sram_sources"
fi

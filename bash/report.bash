#!/bin/bash

# ==================== 硬件信息收集 ====================
export LC_ALL=C.UTF-8
get_serial_number() {
    local serial

    serial=$(dmidecode -s system-serial-number 2>/dev/null | tr -d ' ')

    if [[ -z "$serial" || "$serial" == "NotSpecified" || "$serial" == "TobefilledbyO.E.M." || "$serial" == "None" ]]; then
        serial=$(dmidecode -t baseboard 2>/dev/null | awk -F': ' '/Serial Number/ {print $2; exit}' | tr -d ' ')
    fi

    if [[ -z "$serial" || "$serial" == "NotSpecified" || "$serial" == "TobefilledbyO.E.M." || "$serial" == "None" ]]; then
        serial=$(dmidecode -t system 2>/dev/null | awk -F': ' '/Serial Number/ {print $2; exit}' | tr -d ' ')
    fi

    if [[ -z "$serial" || "$serial" == "NotSpecified" || "$serial" == "TobefilledbyO.E.M." || "$serial" == "None" ]]; then
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        serial="UNKNOWN_${TIMESTAMP}"
        echo ": $serial" >> "$LOG_FILE"
    fi

    echo "$serial"
}

SERIAL_NUMBER=$(get_serial_number)
OUTPUT_DIR="$(pwd)/$SERIAL_NUMBER"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/${SERIAL_NUMBER}.log"

nvidia-smi -q 2>/dev/null > "$OUTPUT_FILE"
lshw 2>/dev/null > "$OUTPUT_FILE"
lspci -vvv 2>/dev/null > "$OUTPUT_FILE"
lscpu 2>/dev/null > "$OUTPUT_FILE"
dmidecode 2>/dev/null > "$OUTPUT_FILE"

{
echo "================= 硬件检测报告 ================="
echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "系统: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2) | 内核: $(uname -r)"
echo "服务器序列号: $SERIAL_NUMBER"
echo "=============================================="
echo

dmidecode -t 1 2>/dev/null | awk -F': ' '
/Manufacturer/ {printf "品牌: %s\n", $2}
/Product Name/ {printf "型号: %s\n", $2}
/Serial Number/ {printf "序列号: %s\n", $2}'
echo

echo "物理CPU数量: $(lscpu | awk -F': +' '/Socket\(s\)/ {print $2}')"
echo "每CPU核心数: $(lscpu | awk -F': +' '/Core\(s\) per socket/ {print $2}')"
echo "每核心线程数: $(lscpu | awk -F': +' '/Thread\(s\) per core/ {print $2}')"
echo "CPU型号: $(lscpu | awk -F': +' '/Model name/ {print $2}' | head -1)"

echo "---- 内存详情 ----"
dmidecode -t memory 2>/dev/null | awk '
BEGIN {
    RS = ""  
    FS = "\n"  
}
/Memory Device/ {
  
    slot = "None"
    manufacturer = "None"
    part_number = "None"
    size = "None"
    speed = "None"
    configured_memory_speed = "None"
    sn = "None"
    installed = 0
    
  
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[[:space:]]*Locator:/) {
            split($i, arr, ":")
            slot = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", slot)
        }
        else if ($i ~ /^[[:space:]]*Manufacturer:/) {
            split($i, arr, ":")
            manufacturer = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", manufacturer)
            # 过滤掉厂商编码（如0xABCD格式）
            if (manufacturer ~ /^[0-9A-Fa-f]{4}$/ || manufacturer == "Unknown") manufacturer = "None"
        }
        else if ($i ~ /^[[:space:]]*Part Number:/) {
            split($i, arr, ":")
            part_number = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", part_number)
            if (part_number == "Unknown" || part_number == "Not Specified") part_number = "None"
        }
        else if ($i ~ /^[[:space:]]*Size:/) {
            split($i, arr, ":")
            size = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", size)
            if (size != "No Module Installed") installed = 1
        }
        else if ($i ~ /^[[:space:]]*Speed:/) {
            split($i, arr, ":")
            speed = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", speed)
            if (speed == "Unknown") speed = "None"
        }
        else if ($i ~ /^[[:space:]]*Configured Memory Speed:/) {
            split($i, arr, ":")
            configured_memory_speed = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", configured_memory_speed)
            if (configured_memory_speed == "Unknown") configured_memory_speed = "None"
        }
        else if ($i ~ /^[[:space:]]*Serial Number:/) {
            split($i, arr, ":")
            sn = arr[2]
            gsub(/^[ \t]+|[ \t]+$/, "", sn)
            if (sn == "Unknown") sn = "None"
        }
    }
    
    # 如果没有安装内存模块，则将所有字段设为None
    if (!installed) {
        manufacturer = "None"
        part_number = "None"
        size = "None"
        speed = "None"
        configured_memory_speed = "None"
        sn = "None"
    }
    
    # 打印结果
    printf "%-25s %-20s %-25s %-10s %-10s %-10s %-10s\n", slot, manufacturer, part_number, size, speed, configured_memory_speed, sn
}'

echo "===== 存储设备 ====="

lsblk -d -o NAME,SERIAL,MODEL,TYPE,SIZE,TRAN | grep -v loop
echo

echo "===== 网络适配器 ====="
lspci -nn 2>/dev/null | grep -iE "ethernet|infiniband|network" | sort | awk -F': ' '{
    split($1, parts, " ");
    device_id = parts[1];

    if (!seen[device_id]++) {
        desc = $2
        gsub(/ \[[0-9a-f]{4}:[0-9a-f]{4}\]/, "", desc);
        gsub(/ \(rev ..\)/, "", desc);
        gsub(/  +/, " ", desc);
        print device_id ": " desc
    }
}'
echo
echo "--------------------------------------------------"

printf "%-12s %-45s %10s %s\n" "pci" "Name" "SN"
for d in /sys/bus/pci/devices/*; do
    # 判断是不是 Mellanox 设备（15b3 是 Mellanox 的 Vendor ID）
    [[ "$(cat "$d/vendor" 2>/dev/null)" == "0x15b3" ]] || continue

    pci=${d##*/}
    model=$(lspci -s "$pci" 2>/dev/null | cut -d: -f3- | xargs)
    sn=$(cat "$d/vpd" 2>/dev/null | strings | awk 'p{print $1;exit} /SN|sn/{p=1}')
    [[ -z "$sn" ]] && sn="N/A"
    
    printf "%-12s %-45s %10s %s\n" "$pci" "$model" "$sn"

done
echo
echo "--------------------------------------------------"
echo "===== GPU信息 ====="


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
    awk -v idx="$idx" -v slot="$slot" -v bus="$bus" -v model="$model" -v memory_gb="$memory_gb" -v power="$power" -v sn="$sn" -v vbios="$vbios" 'BEGIN {
        printf "%-6s %-25s %-15s %-25s %-13s %-10s %-20s %-20s\n", "GPU " idx, slot, bus, model, memory_gb, power, sn, vbios
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



echo

echo "===== 电源信息 ====="
dmidecode -t 39 2>/dev/null | awk -F': ' '
BEGIN {count = 1}
/Model Part Number:/ {model = $2}
/Serial Number:/ {serial = $2}
/Max Power Capacity:/ {
    split($2, parts, " ");
    power = parts[1]
}
/^$/ {
    if (model) {
        printf "PSU%d: %s | %s | %s W\n",
               count, model, serial, power
        count++
        model = ""; serial = ""; power = ""
    }
}'

if [[ $count -eq 1 ]]; then
    echo "未检测到电源信息"
fi
echo

echo "=============================================="
echo "硬件报告部分已完成"
} > "$OUTPUT_FILE"

chmod 644 "$OUTPUT_FILE"
echo "硬件报告已生成: $OUTPUT_FILE"

# ==================== 硬件测试功能 ====================
run_hardware_tests() {
    echo -e "\n\n======= 硬件测试开始 =======" >> "$OUTPUT_FILE"
    echo "测试开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
    echo "===================================" >> "$OUTPUT_FILE"

    GPU_BURN_PATH="/home/aisuan/gpu-burn/gpu_burn"
    FIELDIAG_PATH="/home/aisuan/fd/fieldiag.sh"

    echo "Starting NVIDIA services..."
    systemctl start nvidia-fabricmanager.service
    systemctl start nvidia-dcgm.service
    sleep 30

    echo -e "\n[$(date '+%H:%M:%S')] === NVIDIA P2P测试 ===" | tee -a "$OUTPUT_FILE"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi topo -p2p r | tee -a"$OUTPUT_FILE" 2>&1
        echo "P2P测试完成" | tee -a "$OUTPUT_FILE"
    else
        echo "NVIDIA驱动未安装，跳过P2P测试" >> "$OUTPUT_FILE"
    fi

    # DCGM诊断测试
    echo -e "\n[$(date '+%H:%M:%S')] === DCGM诊断测试===" | tee -a "$OUTPUT_FILE"
    if command -v dcgmi &>/dev/null; then
        echo "DCGM开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
        
        if systemctl status nvidia-dcgm.service >/dev/null 2>&1; then
            systemctl restart nvidia-dcgm.service
            sleep 5
        else
            systemctl start nvidia-dcgm.service
            sleep 10
        fi
        
        timeout 1h dcgmi diag -r 4 >> "$OUTPUT_FILE" 2>&1
        DCGM_EXIT=$?
        echo -e "\nDCGM测试完成" | tee -a "$OUTPUT_FILE"
        echo "DCGM结束时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
        echo "DCGM退出代码: $DCGM_EXIT" >> "$OUTPUT_FILE"
    else
        echo "dcgmi未安装，跳过DCGM测试" | tee -a "$OUTPUT_FILE"
    fi

    sleep 180
    echo -e "\n[$(date '+%H:%M:%S')] === GPU Burn Test 8h ===" >> "$OUTPUT_FILE"
    if [[ -f "$GPU_BURN_PATH" ]]; then
        cd /home/aisuan/gpu-burn/
        ./gpu_burn -d 28800 |tail -n 9 >> "$OUTPUT_FILE" 2>&1
        echo "GPU Burn测试完成" >> "$OUTPUT_FILE"
    else
        echo "GPU-Burn未安装，跳过测试" >> "$OUTPUT_FILE"
    fi

    # NVLink状态检查
    echo -e "\n[$(date '+%H:%M:%S')] === NVLink状态检查 ===" >> "$OUTPUT_FILE"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi nvlink topo -m >> "$OUTPUT_FILE" 2>&1
    else
        echo "NVIDIA驱动未安装，跳过NVLink检查" >> "$OUTPUT_FILE"
    fi

    echo -e "\n[$(date '+%H:%M:%S')] === bandwidthTest ===" >> "$OUTPUT_FILE"
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=0
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=1
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=2
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=3
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=4
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=5
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=6
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=7
    /usr/local/cuda/extras/demo_suite/bandwidthTest --device=all

# GPU ECC错误检查
    echo -e "\n[$(date '+%H:%M:%S')] === GPU ECC错误检查 ===" >> "$OUTPUT_FILE"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=index,serial,ecc.mode.current,ecc.mode.pending,ecc.errors.corrected.aggregate.dram,ecc.errors.uncorrected.aggregate.dram --format=csv >> "$OUTPUT_FILE"
    else
        echo "NVIDIA驱动未安装，跳过ECC检查" >> "$OUTPUT_FILE"
    fi

    echo -e "\n[$(date '+%H:%M:%S')] === 深度诊断测试 ===" >> "$OUTPUT_FILE"
    if [[ -f "$FIELDIAG_PATH" ]]; then
        echo "停止NVIDIA相关服务..." >> "$OUTPUT_FILE"
        systemctl stop nvidia-fabricmanager.service >> "$OUTPUT_FILE" 2>&1
        systemctl stop nvidia-dcgm.service >> "$OUTPUT_FILE" 2>&1
        nvidia-smi -pm 0 >> "$OUTPUT_FILE" 2>&1
        rmmod nvidia_drm nvidia_uvm nvidia_modeset nvidia >> "$OUTPUT_FILE" 2>&1
        sleep 10
     #  rm -rf /home/test/test/tiny/629-24287-XXXX-FLD-40212/
     #  tar -xzf /home/test/test/629-24287-XXXX-FLD-40212.tar.gz -C "/home/test/test/tiny/"
        sleep 15
        
        cd /home/aisuan/fd
        ./fieldiag.sh --no_bmc --level2 >> "$OUTPUT_FILE" 2>&1
        sleep 10
        echo "深度诊断完成" >> "$OUTPUT_FILE"
    else
        echo "fieldiag.sh脚本未找到，跳过深度诊断" >> "$OUTPUT_FILE"
    fi
    sleep 10

    echo "[6/6] 正在恢复系统状态..."
    echo -e "\n===== 重新加载NVIDIA驱动 =====" >> $SUMMARY_LOG

    for module in "${NVIDIA_MODULES[@]}"; do
        echo "加载模块: $module" | tee -a $SUMMARY_LOG
        modprobe $module 2>&1 | tee -a $SUMMARY_LOG
        sleep 1
    done

    echo "NVIDIA" | tee -a $SUMMARY_LOG
    systemctl start nvidia-persistenced.service 2>&1 | tee -a $SUMMARY_LOG
    systemctl start nvidia-fabricmanager.service 2>&1 | tee -a $SUMMARY_LOG
    systemctl start nvidia-dcgm.service 2>&1 | tee -a $SUMMARY_LOG
    sleep 5  

    echo "NVIDIA..." | tee -a $SUMMARY_LOG
    if nvidia-smi >/dev/null 2>&1; then
        echo "驱动恢复成功" | tee -a $SUMMARY_LOG
        echo "GPU状态验证:" | tee -a $SUMMARY_LOG
        nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu --format=csv 2>&1 | tee -a $SUMMARY_LOG
    else
        echo "驱动恢复失败，可能需要重启系统" | tee -a $SUMMARY_LOG
        systemctl restart nvidia-persistenced.service
        sleep 3
        if ! nvidia-smi; then
            echo "紧急恢复失败，请手动检查" | tee -a $SUMMARY_LOG
        fi
    fi
    # 收集诊断结果
    echo -e "\n[$(date '+%H:%M:%S')] === 收集诊断结果 ===" | tee -a "$OUTPUT_FILE"
    cp -f /home/aisuan/fieldiag.log "$OUTPUT_DIR/" >> "$OUTPUT_FILE" 2>&1
    ipmitool fru list 0 >> "$OUTPUT_FILE" 2>&1

    echo -e "\n[$(date '+%H:%M:%S')] ====== 硬件测试完成 ======" >> "$OUTPUT_FILE"
    echo "测试结束时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
    echo "===================================" >> "$OUTPUT_FILE"
    echo -e "\n所有硬件测试已完成，完整报告见: $OUTPUT_FILE"
}

if [[ "$1" == "--run-tests" ]]; then
    echo -e "\n\033[1;34m开始硬件测试...\033[0m"
    echo -e "所有测试结果将保存到: \033[1;32m$OUTPUT_FILE\033[0m"
    run_hardware_tests
else
    echo "请使用: sudo $0 --run-tests 运行完整硬件测试"
fi

#!/bin/bash
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
    fi

    echo "$serial"
}
SERIAL_NUMBER=$(get_serial_number)
OUTPUT_DIR="$(pwd)/$SERIAL_NUMBER"
mkdir -p "$OUTPUT_DIR"

start_time=$(date +%s)


echo $start_time
dcgmi diag -r 3 2>&1 | tee -a "${OUTPUT_DIR}/dcgmi.txt"
sleep 1 #10分钟


cd /home/aisuan/fd
./fieldiag.sh --level1 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt"  | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600
./fieldiag.sh --level2 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600

./fieldiag.sh --level1 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600
./fieldiag.sh --level2 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600


./fieldiag.sh --level1 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600
./fieldiag.sh --level2 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"


sleep 600
./fieldiag.sh --level1 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600
./fieldiag.sh --level2 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"


sleep 600
./fieldiag.sh --level1 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"
sleep 600
./fieldiag.sh --level2 --no_bmc --log "${OUTPUT_DIR}/fieldiag.txt" | tee -a "${OUTPUT_DIR}/fd.txt"

sleep 10
systemctl restart nvidia-power
systemctl restart nvidia-fabricmanager


# 计算已用时间并计算剩余时间（48小时 = 172800秒）
elapsed_time=$(($(date +%s) - $start_time))
remaining_time=$((172800 - $elapsed_time))
# 确保剩余时间不为负数
if [ $remaining_time -lt 0 ]; then
    remaining_time=0

fi


echo "剩余时间: $remaining_time 秒"
cd /home/aisuan/gpu-burn
./gpu_burn $remaining_time
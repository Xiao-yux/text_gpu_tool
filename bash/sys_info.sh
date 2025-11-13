#!/usr/bin/bash

export LC_ALL=C.UTF-8

dmidecode -t system | awk '
/Manufacturer:/ {
    sub(/Manufacturer: /, "")
    print "Manufacturer:" $0
}
/Product Name:/ {
    sub(/Product Name: /, "")
    print "Product Name:" $0
}
/Serial Number:/ {
    sub(/Serial Number: /, "")
    print "SN:" $0
}
'


lscpu | grep -iE "name|socket"

printf "\n"
lsmem


if [ "$EUID" -ne 0 ]; then
    echo "sudo su"
    exit 1
fi

printf "%-25s %-20s %-25s %-10s %-10s %-15s %-10s\n" "Slot" "Manufacturer" "Part Number" "Size" "Speed" "Memory Speed" "SN"

dmidecode -t memory | awk '
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



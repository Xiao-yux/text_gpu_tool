#!/bin/bash

# Script name: aisuan.sh
# Function: 菜鸟菜单
# email: liuyanchao@xinaisuan.com
# Date: 2025-9-5
# Version: v1.0

# Define directory paths
LOG_DIR="/home/aisuan/Log"
AISUAN_DIR="/home/aisuan"
GPU_BURN_DIR="${AISUAN_DIR}/gpu-burn"
NCCL_DIR="${AISUAN_DIR}/nccl"
FD_DIR="${AISUAN_DIR}/fd"

# Create necessary directories
create_directories() {
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}"
    fi
}

# Create date-based log directory and log file
create_log_file() {
    # 创建日期目录
    local date_str=$(date +%Y-%m-%d)
    local date_dir="${LOG_DIR}/${date_str}"

    # 如果日期目录不存在则创建
    if [ ! -d "${date_dir}" ]; then
        mkdir -p "${date_dir}"
        echo "Created log directory: ${date_dir}"
    fi

    # 创建脚本执行日志文件
    local log_file="${date_dir}/aisuan.log"

    # 如果日志文件不存在则创建，否则追加
    if [ ! -f "${log_file}" ]; then
        touch "${log_file}"
        echo "Log file: ${log_file}"
        echo "-----------------system info --------------------" >> "${log_file}"
        echo "log to ${log_file}" >> "${log_file}"
        echo "" >> "${log_file}"
        echo "1  show   system info" >> "${log_file}"
        echo "2 show  disk eth info" >> "${log_file}"
        echo "3 show  nvidia info" >> "${log_file}"
        echo "4 run  gpuburn test" >> "${log_file}"
        echo "5 run nccl test" >> "${log_file}"
        echo "6 run fd test" >> "${log_file}"
        echo "7 run dcgm test" >> "${log_file}"
        echo "" >> "${log_file}"
    else
        echo "Log file: ${log_file}"
    fi

    # Save log file path to variable for later use
    CURRENT_LOG_FILE="${log_file}"

    # 在日志文件中记录脚本启动时间
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] Script started" >> "${CURRENT_LOG_FILE}"
}

# 创建日期目录和选项日志文件
create_option_log_file() {
    local log_type=$1
    local date_str=$(date +%Y-%m-%d)
    local date_dir="${LOG_DIR}/${date_str}"

    # 如果日期目录不存在则创建
    if [ ! -d "${date_dir}" ]; then
        mkdir -p "${date_dir}"
    fi

    # 创建选项日志文件
    local option_log_file="${date_dir}/${log_type}.log"

    # 返回日志文件路径
    echo "${option_log_file}"
}

# Display menu
show_menu() {
    echo "-----------------system info --------------------"
    echo "log to ${CURRENT_LOG_FILE}"
    echo "1  show  cpu  mem info"
    echo "2  show  disk eth info "
    echo "3  show  nvidia info"
    echo "4  run  gpuburn test"
    echo "5  run  nccl test"
    echo "6  run  fd test"
    echo "7  run  dcgm test"
    echo ""
    # echo "Please enter option (1-5):"
}

# Log action
log_action() {
    local action=$1
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] ${action}" >> "${CURRENT_LOG_FILE}"
}

# 1. Show system info
show_system_info() {
    log_action "Executing option 1: Show system info"
    echo "Executing option 1: Show system info"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "cpu_mem")

    # 执行命令并保存到日志文件
    ${AISUAN_DIR}/info_cpu.sh 2>&1 | tee -a "${option_log_file}"
    wait

    # 记录完成信息
    echo "System info displayed"
    log_action "System info saved to: ${option_log_file}"
}

# 2. Show disk eth info
show_disk_eth_info(){
    log_action "Executing option 2: Show disk eth info"
    echo "Executing option 2: Show disk eth info"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "DISK_eth")

    # 执行命令并保存到日志文件
    ${AISUAN_DIR}/SN_INFO_DISK_CX7.sh 2>&1 | tee -a "${option_log_file}"
    wait

    # 记录完成信息
    echo "disk eth info displayed"
    log_action "Disk eth info saved to: ${option_log_file}"
}

# 3. Show NVIDIA info
show_nvidia_info() {
    log_action "Executing option 3: Show NVIDIA info"
    echo "Executing option 3: Show NVIDIA info"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "nvidia_info")

    # 执行命令并保存到日志文件
    ${AISUAN_DIR}/nvidia_info.sh 2>&1 | tee -a "${option_log_file}"

    # Save nvidia-smi -q raw data
    local nvidia_smi_log=$(create_option_log_file "nvidia")
    nvidia-smi -q 2>&1 | tee -a "${nvidia_smi_log}"
    log_action "NVIDIA SMI raw info saved to: ${nvidia_smi_log}"
    echo "NVIDIA SMI raw info saved to: ${nvidia_smi_log}"
    log_action "NVIDIA info saved to: ${option_log_file}"
    echo "NVIDIA info saved to: ${option_log_file}"
}

# 4. Run GPU burn test
run_gpuburn_test() {
    log_action "Executing option 4: Run GPU burn test"
    echo "Executing option 4: Run GPU burn test"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "gpuburn")

    echo "Please select test duration:"
    echo "1) 30 minutes"
    echo "2) 1 hour"
    echo "3) 2 hours"
    echo "4) Custom time (seconds)"

    read -p "Please enter option (1-4): " time_option

    case $time_option in
        1)
            seconds=$((30 * 60))
            echo "Running GPU burn test for 30 minutes"
            ;;
        2)
            seconds=$((60 * 60))
            echo "Running GPU burn test for 1 hour"
            ;;
        3)
            seconds=$((120 * 60))
            echo "Running GPU burn test for 2 hours"
            ;;
        4)
            read -p "Please enter test time in seconds: " seconds
            if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
                echo "Invalid input, please enter a number"
                return
            fi
            echo "Running GPU burn test for ${seconds} seconds"
            ;;
        *)
            echo "Invalid option, please try again"
            return
            ;;
    esac

    # Confirm to start test
    # read -p "Confirm to start GPU burn test? (y/n): " confirm
    # if [[ "$confirm" == "y" ]]; then
        log_action "Starting GPU burn test, duration: ${seconds} seconds"

        # 执行测试并保存输出到日志文件
        ${GPU_BURN_DIR}/gpu_burn ${seconds} 2>&1 | tee -a "${option_log_file}"

        log_action "GPU burn test completed"
        echo "GPU burn test completed"
        log_action "GPU burn test output saved to: ${option_log_file}"
    # else
    #     log_action "Cancelled GPU burn test"
    #     echo "GPU burn test cancelled"
    # fi
}

# 5. Run NCCL test
run_nccl_test() {
    log_action "Executing option 5: Run NCCL test"
    echo "Executing option 5: Run NCCL test"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "nccl_test")

    # 执行命令并保存到日志文件
    ${AISUAN_DIR}/test_nvida.sh 2>&1 | tee -a "${option_log_file}"

    # 记录完成信息
    log_action "NCCL test completed"
    echo "NCCL test completed"
    log_action "NCCL test output saved to: ${option_log_file}"
}

# 6. Run FD test
run_fd_test() {
    log_action "Executing option 6: Run FD test"
    echo "Executing option 6: Run FD test"
    #跑fd需要在fd目录下执行
    cd ${FD_DIR}
    echo "Please select test level:"
    echo "1) level1"
    echo "2) level2"

    read -p "Please enter option (1-2): " level_option

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "fd_test")

    case $level_option in
        1)
            log_action "Running FD level1 test"
            echo "Running FD level1 test"
            cd ${FD_DIR}
            ${FD_DIR}/fieldiag.sh --level1 --no_bmc 2>&1 | tee -a "${option_log_file}"
            cd ${AISUAN_DIR}
            log_action "FD level1 test completed"
            echo "FD level1 test completed"
            ;;
        2)
            log_action "Running FD level2 test"
            echo "Running FD level2 test"
            cd ${FD_DIR}
            ${FD_DIR}/fieldiag.sh --level2 --no_bmc 2>&1 | tee -a "${option_log_file}"
            cd ${AISUAN_DIR}
            log_action "FD level2 test completed"
            echo "FD level2 test completed"
            ;;
        *)
            log_action "Invalid option, cancelled FD test"
            echo "Invalid option, cancelled FD test"
            ;;
    esac
}

# 7. Run DCGM test
run_dcgm_test() {
    log_action "Executing option 7: Run DCGM test"
    echo "Executing option 7: Run DCGM test"

    # 创建选项日志文件
    local option_log_file=$(create_option_log_file "dcgm_test")

    # 执行命令并保存到日志文件
    dcgmi diag -r 3 2>&1 | tee -a "${option_log_file}"

    # 记录完成信息
    log_action "DCGM test completed"
    echo "DCGM test completed"
    log_action "DCGM test output saved to: ${option_log_file}"
}

# Main function
main() {
    # Create necessary directories and log file
    create_directories
    create_log_file

    # 设置退出时的陷阱函数，确保脚本结束时记录日志
    trap 'local timestamp=$(date "+%Y-%m-%d %H:%M:%S"); echo "[${timestamp}] Script ended" >> "${CURRENT_LOG_FILE}"' EXIT

    while true; do
        # Display menu
        show_menu

        # Read user input
        read -p "Please enter option (1-7): " choice

        case $choice in
            1)
                show_system_info
                ;;
            2)
                show_disk_eth_info
                ;;
            3)
                show_nvidia_info
                ;;
            4)
                run_gpuburn_test
                ;;
            5)
                run_nccl_test
                ;;
            6)
                run_fd_test
                ;;
            7)
                run_dcgm_test
                ;;
            *)
                log_action "Invalid option: $choice"
                echo "Invalid option, please try again"
                ;;
        esac
        if [[ "$choice" -ge 1 && "$choice" -le 7 ]]; then
            read -p "Press Enter to return to the menu..."
        fi
    done
}

# Execute main function
main
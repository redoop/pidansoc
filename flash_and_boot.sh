#!/bin/bash

#
# Pidan1 SoC JTAG 烧录和 UART 引导脚本
#
# 功能:
#   1. 使用 Vivado 通过 JTAG 加载 bitstream 到 FPGA
#   2. 使用 litex_term 通过串口引导 Linux 系统
#   3. 加载 OpenSBI, Kernel, DTB, RootFS
#

set -e  # 遇到错误立即退出

# 配置参数
VIVADO_PATH="/tools/Xilinx/Vivado/2024.2/bin/vivado"
LITEX_PATH="/tools/LiteX"
SERIAL_PORT="/dev/ttyUSB0"
SERIAL_BAUD="115200"

# 构建输出目录
BUILD_DIR="build/microphase_artix7_200t"
BITSTREAM="${BUILD_DIR}/gateware/top.bit"

# 引导镜像文件
OPENSBI="opensbi.bin"
KERNEL="Image"
DTB="devicetree.dtb"
ROOTFS="rootfs.cpio"

# 镜像地址配置 (从 images-litex.json 读取)
JSON_CONFIG="images-litex.json"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        log_error "File not found: $1"
        exit 1
    fi
}

# 检查 Vivado 是否可用
check_vivado() {
    if [ ! -f "$VIVADO_PATH" ]; then
        log_error "Vivado not found at $VIVADO_PATH"
        log_info "Please update VIVADO_PATH in this script"
        exit 1
    fi
    log_info "Found Vivado at $VIVADO_PATH"
}

# 检查串口是否可用
check_serial() {
    if [ ! -e "$SERIAL_PORT" ]; then
        log_error "Serial port not found: $SERIAL_PORT"
        log_info "Available serial ports:"
        ls -l /dev/ttyUSB* 2>/dev/null || log_warn "No /dev/ttyUSB* devices found"
        exit 1
    fi
    log_info "Found serial port: $SERIAL_PORT"
}

# 加载 bitstream 到 FPGA SRAM (快速测试)
load_bitstream() {
    log_info "Loading bitstream to FPGA SRAM via JTAG..."
    check_file "$BITSTREAM"

    # 创建 Vivado TCL 脚本
    cat > /tmp/load_bitstream.tcl <<EOF
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7a200t_0]
set_property PROGRAM.FILE {$BITSTREAM} [get_hw_devices xc7a200t_0]
program_hw_devices [get_hw_devices xc7a200t_0]
refresh_hw_device [lindex [get_hw_devices xc7a200t_0] 0]
close_hw_manager
quit
EOF

    $VIVADO_PATH -mode batch -source /tmp/load_bitstream.tcl
    log_info "Bitstream loaded successfully"
}

# 烧录 bitstream 到 SPI Flash (永久存储)
flash_bitstream() {
    log_info "Flashing bitstream to SPI Flash..."
    check_file "$BITSTREAM"

    # 创建 Vivado TCL 脚本用于 SPI Flash 编程
    cat > /tmp/flash_bitstream.tcl <<EOF
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7a200t_0]

# 创建 Flash 编程配置
create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7a200t_0] 0] -mem_dev [lindex [get_cfgmem_parts {s25fl256sxxxxxx0-spi-x1_x2_x4}] 0]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.ADDRESS_RANGE  {use_file} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.FILES [list "$BITSTREAM" ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.BPI_RS_PINS {none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]

startgroup
if {![string equal [get_property PROGRAM.HW_CFGMEM_TYPE  [lindex [get_hw_devices xc7a200t_0] 0]] [get_property MEM_TYPE [get_property CFGMEM_PART [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]]]] }  { create_hw_bitstream -hw_device [lindex [get_hw_devices xc7a200t_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices xc7a200t_0] 0]]; program_hw_devices [lindex [get_hw_devices xc7a200t_0] 0]; };

program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a200t_0] 0]]
endgroup

close_hw_manager
quit
EOF

    $VIVADO_PATH -mode batch -source /tmp/flash_bitstream.tcl
    log_info "Bitstream flashed successfully"
}

# 引导 Linux 系统
boot_linux() {
    log_info "Booting Linux via UART..."

    # 检查引导镜像
    check_file "$OPENSBI"
    check_file "$KERNEL"
    check_file "$DTB"
    check_file "$ROOTFS"
    check_file "$JSON_CONFIG"

    # 检查 litex_term
    LITEX_TERM="${LITEX_PATH}/litex/tools/litex_term.py"
    if [ ! -f "$LITEX_TERM" ]; then
        # 尝试查找本地副本
        if [ -f "litex_term.py" ]; then
            LITEX_TERM="./litex_term.py"
        else
            log_error "litex_term.py not found"
            log_info "Please install LiteX or copy litex_term.py to current directory"
            exit 1
        fi
    fi

    log_info "Using litex_term: $LITEX_TERM"

    # 等待用户确认
    log_warn "Make sure FPGA is powered on and bitstream is loaded"
    read -p "Press Enter to start booting..."

    # 使用 litex_term 引导
    python3 "$LITEX_TERM" \
        --speed $SERIAL_BAUD \
        --images "$JSON_CONFIG" \
        $SERIAL_PORT

    log_info "Boot sequence completed"
}

# 显示帮助信息
show_help() {
    cat <<EOF
Pidan1 SoC Flash and Boot Script

Usage: $0 [COMMAND]

Commands:
    load        - Load bitstream to FPGA SRAM (temporary, fast)
    flash       - Flash bitstream to SPI Flash (permanent, slow)
    boot        - Boot Linux via UART serial console
    all         - Load bitstream and boot Linux (default)
    help        - Show this help message

Examples:
    $0              # Load bitstream and boot Linux
    $0 load         # Only load bitstream to SRAM
    $0 flash        # Only flash bitstream to SPI Flash
    $0 boot         # Only boot Linux (assumes bitstream already loaded)

Configuration:
    VIVADO_PATH    : $VIVADO_PATH
    LITEX_PATH     : $LITEX_PATH
    SERIAL_PORT    : $SERIAL_PORT
    SERIAL_BAUD    : $SERIAL_BAUD
    BITSTREAM      : $BITSTREAM

EOF
}

# 主程序
main() {
    local cmd="${1:-all}"

    case "$cmd" in
        load)
            check_vivado
            load_bitstream
            ;;
        flash)
            check_vivado
            flash_bitstream
            ;;
        boot)
            check_serial
            boot_linux
            ;;
        all)
            check_vivado
            check_serial
            load_bitstream
            sleep 2  # 等待 FPGA 初始化
            boot_linux
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

# 皮蛋一号 (Pidan1) — BitNet 加速器 SoC

基于 LiteX + VexRiscv-SMP 的 FPGA SoC，面向电信信令实时处理的 1-bit BitNet 矩阵向量乘法加速器。

## 硬件平台

- **FPGA**: MicroPhase Artix-7 200T (XC7A200T-FBG484)
- **工具链**: Xilinx Vivado 2024.2
- **DDR3**: 512MB (MT41K256M16, 800MT/s)
- **以太网**: RTL8211E RGMII
- **UART**: CH340 USB转串口

## 系统架构

| 组件 | 规格 |
|------|------|
| CPU | VexRiscv-SMP (linux 变体，支持 SMP + PLIC + CLINT) |
| 系统时钟 | 50MHz 输入 → 100MHz (MMCM PLL) |
| 内存 | DDR3 512MB |
| 加速器基地址 | `0x8000_2000` (非缓存) |

## BitNet 加速器

### 概述

专用矩阵向量乘法加速器，针对 1-bit 量化权重（-1, 0, +1）优化。最大支持 64×64 矩阵，通过 Wishbone 从接口与 CPU 通信。

### 寄存器映射（字节地址）

| 偏移 | 名称 | 读写 | 说明 |
|------|------|------|------|
| `0x000` | CTRL | W | bit0: start, bit1: clear |
| `0x004` | STATUS | R | bit0: done, bit1: busy |
| `0x008` | SIZE_M | RW | 矩阵行数 (1~64) |
| `0x00C` | SIZE_N | RW | 矩阵列数 (1~64) |
| `0x010` | 权重区 | RW | 256 字 × 4B (2-bit 编码: 0→`00`, +1→`01`, -1→`10`) |
| `0x410` | 输入区 | RW | 16 字 × 4B (8-bit 打包, 4 元素/字) |
| `0x450` | 输出区 | R | 64 字 × 4B (32-bit 有符号结果) |

总地址空间：4KB (向上对齐)

### 操作流程

1. 写入 `SIZE_M`、`SIZE_N` 设置矩阵维度
2. 将 2-bit 编码权重写入权重区
3. 将 8-bit 输入向量写入输入区
4. 写 `CTRL` 的 bit0 启动计算
5. 轮询 `STATUS` 等待 done
6. 从输出区读取结果

## 文件说明

```
├── bitnet_accel.v          # Verilog 加速器核心 (v3)
├── bitnet_accel_litex.py   # LiteX/Migen Wishbone 封装
├── pidan1_soc.py           # SoC 顶层定义 (CPU + DDR3 + ETH + 加速器)
├── bitnet_test.c           # 用户态测试程序 (通过 /dev/mem mmap)
├── bitnet_test             # 已编译的测试程序 (RISC-V 32-bit)
├── flash_and_boot.sh       # JTAG 烧录 + UART 引导脚本
├── litex_term.py           # LiteX 串口终端工具
├── images-litex.json       # 引导镜像地址映射
├── Image                   # Linux 内核镜像
├── rootfs.cpio             # 根文件系统
├── devicetree-*.dtb        # 设备树
├── opensbi.bin             # OpenSBI (外部路径)
└── emulator-*.bin          # LiteX BIOS 模拟器
```

## 构建与运行

### 生成 bitstream

```bash
python3 pidan_soc.py --build
```

### 加载到 FPGA (SRAM)

```bash
python3 pidan_soc.py --load
```

### 烧录并引导系统

```bash
./flash_and_boot.sh
```

### 编译测试程序

```bash
# 交叉编译 (在构建系统上)
riscv32-buildroot-linux-gnu-gcc -O2 -o bitnet_test bitnet_test.c

# 或在目标板上直接运行
./bitnet_test
```

## 引导镜像布局

| 镜像 | 加载地址 |
|------|----------|
| OpenSBI | `0x40F00000` |
| Linux Kernel (Image) | `0x40000000` |
| Device Tree (DTB) | `0x40EF0000` |
| RootFS (rootfs.cpio) | `0x41000000` |

## 当前状态

✅ **所有核心组件已完成**

- [x] 加速器 Verilog 实现完成 (bitnet_accel.v)
- [x] LiteX/Migen Wishbone 封装完成 (bitnet_accel_litex.py)
- [x] SoC 顶层定义完成 (pidan1_soc.py)
- [x] 用户态测试程序完成 (bitnet_test.c)
- [x] JTAG 烧录和引导脚本完成 (flash_and_boot.sh)
- [x] 引导镜像地址配置完成 (images-litex.json)
- [x] Makefile 构建系统完成
- [x] 项目文档完成 (README.md, SETUP.md)

## 快速开始

✅ 所有引导镜像已准备就绪（位于 `boot-images/` 目录）

1. **构建 bitstream**
   ```bash
   make build
   ```

2. **加载到 FPGA 并引导 Linux**
   ```bash
   make run
   ```

3. **在目标板上测试加速器**
   ```bash
   ./bitnet_test
   ```

详细安装和使用说明请参见 [SETUP.md](SETUP.md)

## 引导镜像

所有 Linux 引导所需的镜像文件已包含在 `boot-images/` 目录中：
- OpenSBI (~258KB) - RISC-V M-mode 固件
- Linux Kernel (~8.4MB) - 内核镜像
- Device Tree (~1.9KB) - 硬件描述
- Root FS (~9.8MB) - 根文件系统

详见 [boot-images/README.md](boot-images/README.md)

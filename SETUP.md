# 皮蛋一号 (Pidan1) 安装和使用指南

## 系统要求

### 硬件
- **FPGA 开发板**: MicroPhase Artix-7 200T (XC7A200T-FBG484)
- **调试器**: Xilinx 兼容 JTAG 调试器（板载或外置）
- **串口**: USB-UART (CH340) 或其他串口连接
- **主机**: Linux 工作站（推荐 Ubuntu 20.04/22.04）

### 软件依赖

1. **Xilinx Vivado 2024.2**
   ```bash
   # 安装路径: /tools/Xilinx/Vivado/2024.2
   # 确保 vivado 命令在 PATH 中
   source /tools/Xilinx/Vivado/2024.2/settings64.sh
   ```

2. **Python 3.8+**
   ```bash
   sudo apt install python3 python3-pip
   ```

3. **LiteX 及依赖**
   ```bash
   # 安装到 /tools/LiteX
   cd /tools
   wget https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
   python3 litex_setup.py --init --install --user

   # 安装额外的 Python 包
   pip3 install migen litex litedram liteeth litescope
   ```

4. **RISC-V 工具链**
   ```bash
   # 32-bit RISC-V Linux 工具链
   # 使用 Buildroot 或其他预编译工具链
   # 示例: https://github.com/riscv-collab/riscv-gnu-toolchain

   # 或者从 SiFive 下载预编译版本
   wget https://static.dev.sifive.com/dev-tools/freedom-tools/v2020.12/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14.tar.gz
   ```

5. **其他工具**
   ```bash
   sudo apt install build-essential git wget curl
   sudo apt install device-tree-compiler  # dtc
   ```

## 快速开始

### 1. 克隆仓库

```bash
cd /root/github
git clone <repository-url> pidansoc
cd pidansoc
```

### 2. 检查依赖

```bash
make check-deps
```

### 3. 构建 SoC Bitstream

```bash
make build
```

这将：
- 使用 LiteX 生成 Verilog RTL
- 调用 Vivado 综合、实现和生成 bitstream
- 输出文件位于 `build/microphase_artix7_200t/gateware/top.bit`

### 4. 准备 Linux 引导镜像

你需要准备以下文件（从 LiteX Linux 或其他来源获取）：

```bash
# 下载或构建以下文件:
# - opensbi.bin       : OpenSBI 固件
# - Image             : Linux 内核镜像
# - devicetree.dtb    : 设备树
# - rootfs.cpio       : 根文件系统 (initramfs)

# 示例: 从 LiteX Linux 项目获取
# https://github.com/litex-hub/linux-on-litex-vexriscv
```

### 5. 加载到 FPGA

```bash
# 方法 1: 加载到 SRAM (快速测试，断电后丢失)
make load

# 方法 2: 烧录到 Flash (永久保存)
make flash
```

### 6. 引导 Linux 系统

```bash
# 确保串口连接正常 (默认 /dev/ttyUSB0)
make boot

# 或者完整流程（加载 + 引导）
make run
```

### 7. 测试 BitNet 加速器

在 Linux 系统启动后，运行测试程序：

```bash
# 在 FPGA 上运行
./bitnet_test
```

或者在主机上交叉编译后复制：

```bash
# 在主机上
make test

# 通过网络或串口传输到目标板
scp bitnet_test root@<board-ip>:/root/
```

## 高级配置

### 修改系统时钟频率

```bash
# 默认 100MHz，可以修改为其他频率
make build SYS_CLK_FREQ=125e6
```

### 自定义板级配置

编辑 `pidan1_soc.py` 中的 `_io` 列表来修改引脚分配：

```python
_io = [
    ("clk50", 0, Pins("U18"), IOStandard("LVCMOS33")),
    # ... 其他引脚定义
]
```

### 调整 BitNet 加速器参数

在 `bitnet_accel.v` 中修改参数：

```verilog
module bitnet_accel #(
    parameter MAX_DIM = 64,        // 最大矩阵维度
    parameter ADDR_WIDTH = 12      // 地址空间大小
)
```

## 目录结构

```
pidansoc/
├── bitnet_accel.v           # BitNet 加速器 Verilog 核心
├── bitnet_accel_litex.py    # LiteX Wishbone 封装
├── pidan1_soc.py            # SoC 顶层定义
├── bitnet_test.c            # 用户态测试程序
├── flash_and_boot.sh        # JTAG 烧录和引导脚本
├── images-litex.json        # 引导镜像地址配置
├── Makefile                 # 构建系统
├── README.md                # 项目说明
├── SETUP.md                 # 本文档
├── LICENSE                  # 许可证
└── build/                   # 构建输出目录（生成）
```

## 常见问题

### Q: Vivado 找不到 FPGA

检查 JTAG 连接和驱动：

```bash
# 安装 Xilinx Cable Driver
cd /tools/Xilinx/Vivado/2024.2/data/xicom/cable_drivers/lin64/install_script/install_drivers
sudo ./install_drivers

# 检查 USB 设备
lsusb | grep -i xilinx
```

### Q: 串口无法连接

```bash
# 检查串口设备
ls -l /dev/ttyUSB*

# 添加用户到 dialout 组
sudo usermod -a -G dialout $USER

# 重新登录后生效
```

### Q: LiteX 构建失败

```bash
# 确保所有依赖已安装
pip3 install --upgrade litex migen litedram liteeth

# 清理并重新构建
make distclean
make build
```

### Q: BitNet 测试程序运行失败

```bash
# 检查 /dev/mem 访问权限
ls -l /dev/mem

# 可能需要 root 权限
sudo ./bitnet_test

# 或者配置 udev 规则
```

## 性能优化

### 1. 时序优化

修改 `pidan1_soc.py` 中的约束：

```python
self.platform.add_period_constraint(self.crg.cd_sys.clk, 1e9/sys_clk_freq)
```

### 2. 流水线优化

在 `bitnet_accel.v` 中添加流水线寄存器来提高工作频率。

### 3. 并行度调整

修改加速器架构以支持多行并行计算。

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

本项目采用 Apache 2.0 许可证。详见 LICENSE 文件。

## 联系方式

- Issue Tracker: <repository-url>/issues
- 讨论: <repository-url>/discussions

## 参考资料

- [LiteX Documentation](https://github.com/enjoy-digital/litex)
- [VexRiscv Documentation](https://github.com/SpinalHDL/VexRiscv)
- [BitNet Paper](https://arxiv.org/abs/2402.17764)
- [Xilinx 7 Series FPGAs](https://www.xilinx.com/products/silicon-devices/fpga/artix-7.html)

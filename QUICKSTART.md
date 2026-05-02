# 皮蛋一号 SoC - 快速开始指南

## 5 分钟快速体验

### 前提条件
- Xilinx Vivado 2024.2 已安装在 `/tools/Xilinx/Vivado/2024.2`
- LiteX 已安装在 `/tools/LiteX`
- MicroPhase Artix-7 200T 开发板通过 JTAG 和 UART 连接到主机

### 步骤 1: 检查依赖

```bash
cd /root/github/pidansoc
make check-deps
```

应该看到所有依赖都标记为 ✓

### 步骤 2: 构建 SoC Bitstream

```bash
make build
```

这将需要 10-30 分钟，取决于主机性能。构建完成后会生成：
- `build/microphase_artix7_200t/gateware/top.bit` - FPGA bitstream
- `csr.csv` / `csr.json` - 寄存器映射

### 步骤 3: 加载 Bitstream 到 FPGA

```bash
# 方法 1: 快速加载到 SRAM（重启后丢失）
make load

# 方法 2: 烧录到 Flash（永久保存）
make flash
```

### 步骤 4: 引导 Linux 系统

```bash
make boot
```

这将：
1. 通过 UART 连接到开发板
2. 等待 FPGA 初始化
3. 加载 OpenSBI, Kernel, DTB, RootFS
4. 引导进入 Linux shell

### 步骤 5: 测试 BitNet 加速器

在 Linux shell 中运行：

```bash
# 查看加速器内存映射
cat /proc/iomem | grep bitnet

# 运行测试程序
./bitnet_test
```

## 一键运行（推荐）

如果构建已完成，可以一键加载 + 引导：

```bash
make run
```

## 常见问题

### Q1: 构建失败 "Vivado not found"

```bash
# 设置 Vivado 环境
source /tools/Xilinx/Vivado/2024.2/settings64.sh

# 或在 Makefile 中修改 VIVADO_PATH
```

### Q2: JTAG 连接失败

```bash
# 检查 USB 设备
lsusb | grep Xilinx

# 安装驱动
cd /tools/Xilinx/Vivado/2024.2/data/xicom/cable_drivers/lin64/install_script/install_drivers
sudo ./install_drivers
```

### Q3: 串口无法连接

```bash
# 检查串口设备
ls -l /dev/ttyUSB*

# 添加权限
sudo usermod -a -G dialout $USER
# 需要重新登录
```

### Q4: 找不到引导镜像

所有引导镜像已包含在 `boot-images/` 目录中，无需额外下载。

### Q5: BitNet 测试失败

```bash
# 需要 root 权限访问 /dev/mem
sudo ./bitnet_test

# 或配置系统允许普通用户访问
```

## 自定义配置

### 修改系统时钟频率

```bash
# 默认 100MHz，修改为 125MHz
make build SYS_CLK_FREQ=125e6
```

### 修改加速器基地址

编辑 `pidan1_soc.py`:

```python
self.bus.add_slave(
    name="bitnet",
    slave=self.bitnet.bus,
    region=SoCRegion(
        origin=0x80002000,  # 修改这里
        size=0x1000,
        cached=False
    )
)
```

### 自定义设备树

构建后设备树会自动生成在：
```bash
build/microphase_artix7_200t/software/devicetree.dts
```

可以编辑后重新编译：
```bash
dtc -I dts -O dtb -o boot-images/devicetree.dtb devicetree.dts
```

## 性能测试

### 测试 DDR3 带宽

```bash
# 在 Linux shell 中
dd if=/dev/zero of=/dev/null bs=1M count=1000
```

### 测试以太网

```bash
# 配置 IP（如果使用静态 IP）
ifconfig eth0 192.168.1.100

# 测试 ping
ping 192.168.1.1
```

### BitNet 加速器基准测试

```bash
# 运行完整测试套件
./bitnet_test

# 查看不同矩阵大小的性能
# 测试会输出每个测试用例的延迟
```

## 下一步

1. **添加自定义应用**: 交叉编译你的应用并复制到板上
2. **优化加速器**: 修改 `bitnet_accel.v` 添加流水线
3. **集成自己的 IP**: 参考 BitNet 加速器的集成方式
4. **构建完整系统**: 添加更多外设（SPI, I2C, GPIO 等）

## 文档索引

- [README.md](README.md) - 项目概述
- [SETUP.md](SETUP.md) - 详细安装指南
- [OVERVIEW.md](OVERVIEW.md) - 技术架构详解
- [boot-images/README.md](boot-images/README.md) - 引导镜像说明
- [QUICKSTART.md](QUICKSTART.md) - 本文档

## 获取帮助

- 查看日志: `build/microphase_artix7_200t/gateware/vivado.log`
- LiteX 文档: https://github.com/enjoy-digital/litex
- VexRiscv 文档: https://github.com/SpinalHDL/VexRiscv

## 许可证

Apache License 2.0 - 详见 [LICENSE](LICENSE)

# MicroPhase A7-Lite 开发板硬件文档

## 板卡概述

A7-Lite 是一款基于 Xilinx Artix-7 的商业级 SoC 开发板，支持三种型号：
- XC7A35T-2FGG484L
- XC7A100T-2FGG484L
- **XC7A200T-2FGG484L** ← 本项目使用

### 主要特性

- **DDR3**: 1 个 4Gbit (512MB), 1066Mbps DDR3
- **Flash**: 128MB Quad-SPI Flash
- **以太网**: 10/100/1000M RJ45 (RTL8211F PHY)
- **USB JTAG**: 板载 JTAG 电路
- **USB UART**: CH340 串口芯片
- **HDMI**: 1080P@60Hz 输出
- **SD 卡**: Micro SD 接口
- **时钟**: 50MHz 有源晶振
- **LED**: 2 个用户 LED
- **按键**: 2 个用户按键
- **GPIO**: 2×50 针扩展接口

## FPGA 资源 (XC7A200T)

| 资源类型 | 数量 |
|---------|------|
| Logic Cells | 215,360 |
| Slices | 33,650 |
| CLB Flip-Flops | 269,200 |
| Maximum Distributed RAM | 2,888 Kb |
| Block RAM (36 Kb) | 365 |
| Total Block RAM | 13,140 Kb |
| CMTs (MMCM + PLL) | 10 |
| Maximum Single-Ended I/O | 500 |
| Maximum Differential I/O Pairs | 240 |
| DSP Slices | 740 |
| PCIe Gen2 | 1 |
| GTP Transceivers (6.6 Gb/s) | 16 |

## 引脚分配

### 1. DDR3 (MT41K256M16, 256M × 16bit)

#### 地址总线
| 信号名称 | 引脚号 | 信号名称 | 引脚号 |
|---------|--------|---------|--------|
| DDR3_A0 | P1 | DDR3_A8 | P2 |
| DDR3_A1 | M6 | DDR3_A9 | L1 |
| DDR3_A2 | K3 | DDR3_A10 | M2 |
| DDR3_A3 | K4 | DDR3_A11 | P6 |
| DDR3_A4 | M5 | DDR3_A12 | L4 |
| DDR3_A5 | J6 | DDR3_A13 | L5 |
| DDR3_A6 | N2 | DDR3_A14 | N5 |
| DDR3_A7 | K6 | | |

#### Bank 地址
| 信号名称 | 引脚号 |
|---------|--------|
| DDR3_BA0 | J4 |
| DDR3_BA1 | R1 |
| DDR3_BA2 | M1 |

#### 数据总线
| 信号名称 | 引脚号 | 信号名称 | 引脚号 |
|---------|--------|---------|--------|
| DDR3_D0 | B2 | DDR3_D8 | J5 |
| DDR3_D1 | F1 | DDR3_D9 | G2 |
| DDR3_D2 | B1 | DDR3_D10 | K1 |
| DDR3_D3 | D2 | DDR3_D11 | G3 |
| DDR3_D4 | C2 | DDR3_D12 | H2 |
| DDR3_D5 | F3 | DDR3_D13 | H5 |
| DDR3_D6 | A1 | DDR3_D14 | J1 |
| DDR3_D7 | G1 | DDR3_D15 | H4 |

#### 控制信号
| 信号名称 | 引脚号 | 说明 |
|---------|--------|------|
| DDR3_NCAS | N3 | Column Address Strobe |
| DDR3_CKE | N4 | Clock Enable |
| DDR3_CLK_N | P4 | 差分时钟负端 |
| DDR3_CLK_P | P5 | 差分时钟正端 |
| DDR3_DM0 | E2 | Data Mask 0 |
| DDR3_DM1 | H3 | Data Mask 1 |
| DDR3_DQS_N0 | D1 | Data Strobe 0 负端 |
| DDR3_DQS_P0 | E1 | Data Strobe 0 正端 |
| DDR3_DQS_N1 | J2 | Data Strobe 1 负端 |
| DDR3_DQS_P1 | K2 | Data Strobe 1 正端 |
| DDR3_RST | F4 | Reset |
| DDR3_ODT | L3 | On-Die Termination |
| DDR3_NRAS | M3 | Row Address Strobe |
| DDR3_NWE | L6 | Write Enable |

**注意**: DDR3 使用 SSTL15 电平标准

### 2. 时钟

| 位置 | 信号名称 | 频率 | 引脚号 |
|-----|---------|------|--------|
| U10 | CLK_50M | 50MHz | J19 |

### 3. LED

| 位置 | 信号名称 | 引脚号 | 说明 |
|-----|---------|--------|------|
| D6 | LED1 | M18 | 用户 LED 1 |
| D5 | LED2 | N18 | 用户 LED 2 |

### 4. 按键

| 位置 | 信号名称 | 引脚号 | 说明 |
|-----|---------|--------|------|
| K1 | KEY1 | AA1 | 用户按键 1 |
| K2 | KEY2 | W1 | 用户按键 2 |
| K3 | RESET | - | 复位按键 |

### 5. USB UART (CH340)

| 信号名称 | 引脚名称 | 引脚号 | 说明 |
|---------|---------|--------|------|
| UART_TX | IO_L2N_T0_34 | V2 | UART 数据输出 |
| UART_RX | IO_L2P_T0_34 | U2 | UART 数据输入 |

### 6. 千兆以太网 (RTL8211F)

**接口**: GMII (Gigabit Media Independent Interface)

> 注：RTL8211F 支持 10/100/1000M 网络传输，通过 GMII 接口与 FPGA MAC 层通信。
> 支持 MDI/MDX 自适应、速率自适应、主/从自适应及 MDIO 总线。

### 7. SPI Flash (IS25L128F-JBLE-TR)

| 位置 | 型号 | 容量 | 厂商 |
|-----|------|------|------|
| U2 | IS25L128FJBLE | 128MB | ISSI |

### 8. GPIO 扩展接口

#### JP1 (IO 电平可调，默认 3.3V)

**电平调整方法**:
- 卸下 B8，焊接 B9
- 向 VCCIO_A 输入所需电平 (1.2-3.3V)

| 引脚 | 信号名称 | 引脚号 | 引脚 | 信号名称 | 引脚号 |
|-----|---------|--------|-----|---------|--------|
| 1 | GPIO1_0P | F13 | 2 | GPIO1_0N | F14 |
| 3 | GPIO1_1P | E13 | 4 | GPIO1_1N | E14 |
| 5 | GPIO1_2P | D14 | 6 | GPIO1_2N | D15 |
| 7 | GPIO1_3P | E16 | 8 | GPIO1_3N | D16 |
| 9 | GPIO1_4P | D17 | 10 | GPIO1_4N | C17 |
| 11 | VCC_5V | - | 12 | GND | - |
| 13 | GPIO1_5P | C13 | 14 | GPIO1_5N | B13 |
| 15 | GPIO1_6P | A13 | 16 | GPIO1_6N | A14 |
| 17 | GPIO1_7P | C14 | 18 | GPIO1_7N | C15 |
| 19 | GPIO1_8P | A15 | 20 | GPIO1_8N | A16 |
| 21 | GPIO1_9P | B15 | 22 | GPIO1_9N | B16 |
| 23 | GPIO1_10P | F16 | 24 | GPIO1_10N | E17 |
| 25 | GPIO1_11P | A18 | 26 | GPIO1_11N | A19 |
| 27 | GPIO1_12P | B17 | 28 | GPIO1_12N | B18 |
| 29 | VCC_3V3 | - | 30 | GND | - |
| 31 | GPIO1_13P | B20 | 32 | GPIO1_13N | A20 |
| 33 | GPIO1_14P | F19 | 34 | GPIO1_14N | F20 |
| 35 | GPIO1_15P | E19 | 36 | GPIO1_15N | D19 |
| 37 | GPIO1_16P | C18 | 38 | GPIO1_16N | C19 |
| 39 | GPIO1_17P | F18 | 40 | GPIO1_17N | E18 |
| 41 | VCCIO_A | - | 42 | GND | - |
| 43 | GPIO1_18P | D20 | 44 | GPIO1_18N | C20 |
| 45 | GPIO1_19P | B21 | 46 | GPIO1_19N | A21 |
| 47 | GPIO1_20P | D21 | 48 | GPIO1_20N | G21 |
| 49 | GPIO1_21P | C22 | 50 | GPIO1_21N | B22 |

**注**: GPIO1_20P/N 只能作为单端使用

#### JP2 (IO 电平 3.3V)

| 引脚 | 信号名称 | 引脚号 | 引脚 | 信号名称 | 引脚号 |
|-----|---------|--------|-----|---------|--------|
| 1 | GPIO2_0P | W21 | 2 | GPIO2_0N | W22 |
| 3 | GPIO2_1P | N17 | 4 | GPIO2_1N | P17 |
| 5 | GPIO2_2P | P19 | 6 | GPIO2_2N | R19 |
| 7 | GPIO2_3P | R18 | 8 | GPIO2_3N | T18 |
| 9 | GPIO2_4P | T21 | 10 | GPIO2_4N | U21 |
| 11 | VCC_5V | - | 12 | GND | - |
| 13 | GPIO2_5P | U22 | 14 | GPIO2_5N | V22 |
| 15 | GPIO2_6P | Y21 | 16 | GPIO2_6N | Y22 |
| 17 | GPIO2_7P | AA20 | 18 | GPIO2_7N | AA21 |
| 19 | GPIO2_8P | AB21 | 20 | GPIO2_8N | AB22 |
| 21 | GPIO2_9P | AA19 | 22 | GPIO2_9N | AB20 |
| 23 | GPIO2_10P | U20 | 24 | GPIO2_10N | V20 |
| 25 | GPIO2_11P | Y18 | 26 | GPIO2_11N | Y19 |
| 27 | GPIO2_12P | W19 | 28 | GPIO2_12N | W20 |
| 29 | VCC_3V3 | - | 30 | GND | - |
| 31 | GPIO2_13P | AA18 | 32 | GPIO2_13N | AB18 |
| 33 | GPIO2_14P | V18 | 34 | GPIO2_14N | V19 |
| 35 | GPIO2_15P | V17 | 36 | GPIO2_15N | W17 |
| 37 | GPIO2_16P | U17 | 38 | GPIO2_16N | U18 |
| 39 | GPIO2_17P | P14 | 40 | GPIO2_17N | R14 |
| 41 | NC | - | 42 | GND | - |
| 43 | GPIO2_18P | P16 | 44 | GPIO2_18N | R17 |
| 45 | GPIO2_19P | N13 | 46 | GPIO2_19N | N14 |
| 47 | GPIO2_20P | P15 | 48 | GPIO2_20N | R16 |
| 49 | GPIO2_21P | AB7 | 50 | GPIO2_21N | AB6 |

## 电源

- **供电方式**: USB 5V 供电
- **接口**: 两个 USB 接口均可用于供电

## IO 标准

### 常用 IO 标准

- **LVCMOS33**: 3.3V 单端信号 (LED, 按键, UART, 时钟)
- **SSTL15**: DDR3 专用电平标准 (1.5V with termination)
- **DIFF_SSTL15**: DDR3 差分信号

### GPIO 阻抗特性

- **单端阻抗**: 50 欧姆
- **差分阻抗**: 100 欧姆
- **走线**: 等长差分处理

## 设计注意事项

### DDR3 设计要点

1. **电平标准**: 必须使用 SSTL15
2. **差分对**:
   - DQS 差分对需正确配对
   - CLK 差分对需正确配对
3. **VREF**: SSTL15 需要参考电压，注意 VREF 引脚配置
4. **ODT**: 片内终端匹配需要正确配置

### 时钟约束

```tcl
# 50MHz 输入时钟
create_clock -period 20.000 -name clk50 [get_ports CLK_50M]

# DDR3 时钟 (通常 400MHz for DDR3-800)
create_generated_clock -name ddr3_clk ...
```

### 常见问题

#### 问题 1: DDR3 DRC 错误 (BIVRU-1)

**错误信息**: Bank IO standard Vref utilization

**原因**: VREF 引脚被占用或配置不正确

**解决方案**:
```python
# 在 LiteX 中添加 INTERNAL_VREF 约束
platform.add_platform_command(
    "set_property INTERNAL_VREF 0.750 [get_iobanks 35]"
)
```

#### 问题 2: 差分对引脚错误

**错误信息**: Cannot place differential pair

**原因**: P/N 引脚颠倒或使用了非差分引脚

**解决方案**: 严格按照数据手册配对差分信号

## 参考资料

- 官方文档: https://fpga-docs.microphase.cn/
- 销售联系: sales@microphase.cn
- Artix-7 数据手册: https://www.xilinx.com/support/documentation/data_sheets/ds181_Artix_7_Data_Sheet.pdf

## 修订历史

| 版本 | 日期 | 说明 |
|-----|------|------|
| 1.0 | 2026-05-02 | 初始版本，基于官方文档整理 |

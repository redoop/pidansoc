# 引导镜像文件说明

本目录包含 Pidan1 SoC 引导 Linux 系统所需的所有镜像文件。

## 文件清单

| 文件 | 大小 | 说明 | 来源 |
|------|------|------|------|
| `opensbi.bin` | ~258KB | OpenSBI RISC-V 固件 (M-mode) | LiteX Buildroot |
| `Image` | ~8.4MB | Linux 内核镜像 (S-mode) | LiteX Linux on VexRiscv |
| `devicetree.dtb` | ~1.9KB | 设备树二进制文件 | LiteX 生成 |
| `rootfs.cpio` | ~9.8MB | 根文件系统 (initramfs) | LiteX Buildroot |
| `emulator.bin` | ~8.9KB | LiteX BIOS 模拟器 | LiteX 生成 |

## 文件来源

这些文件来自以下位置：

1. **opensbi.bin**
   - 原始文件: `/tools/LiteX/buildroot-new/output/images/fw_jump.bin`
   - 这是 OpenSBI 的 fw_jump 固件，作为 RISC-V 的 M-mode 引导加载程序

2. **Image**
   - 原始文件: `/root/vexriscv-bins/Image`
   - Linux 5.x 内核，为 VexRiscv RISC-V 核心编译

3. **devicetree.dtb**
   - 原始文件: `/root/vexriscv-bins/devicetree-litex-vexriscv-avalanche-linux.dtb`
   - 描述硬件配置的设备树

4. **rootfs.cpio**
   - 原始文件: `/root/vexriscv-bins/rootfs.cpio`
   - 包含基本 Linux 工具和应用的根文件系统

5. **emulator.bin**
   - 原始文件: `/root/vexriscv-bins/emulator-litex-vexriscv-avalanche-linux.bin`
   - LiteX BIOS 模拟器（可选）

## 内存地址映射

引导时，这些镜像会被加载到以下内存地址（参见 `../images-litex.json`）：

| 镜像 | 加载地址 | 说明 |
|------|----------|------|
| OpenSBI | 0x40F00000 | M-mode 固件 |
| Kernel | 0x40000000 | S-mode 内核 |
| DTB | 0x40EF0000 | 设备树 |
| RootFS | 0x41000000 | 文件系统 |

## 引导流程

```
1. FPGA 加载 bitstream
2. CPU 从 ROM 启动
3. 通过 UART 加载 OpenSBI (M-mode)
4. OpenSBI 跳转到 Kernel (S-mode)
5. Kernel 挂载 RootFS
6. 启动用户态 init
```

## 重新生成这些镜像

如果需要重新生成这些镜像（例如添加自定义软件或驱动），请参考：

### Linux 内核
```bash
cd /tools/LiteX/linux-on-litex-vexriscv
./make.py --board=arty --cpu-variant=linux --build
```

### OpenSBI
```bash
cd /tools/LiteX/buildroot-new
make
# 输出: output/images/fw_jump.bin
```

### 根文件系统
可以使用 Buildroot 自定义：
```bash
cd /tools/LiteX/buildroot-new
make menuconfig
make
```

### 设备树
设备树会在 LiteX SoC 构建时自动生成：
```bash
cd /root/github/pidansoc
python3 pidan1_soc.py --build
# DTB 会在 build/ 目录中生成
```

## 注意事项

1. **设备树可能需要更新**: 当前的 `devicetree.dtb` 是为 Avalanche 板生成的，可能需要根据 Pidan1 的硬件配置重新生成。

2. **内存地址**: 确保加载地址不与 SoC 的其他内存区域冲突。

3. **文件大小**:
   - OpenSBI: ~258KB (固定)
   - Kernel: 可能因配置而异 (5-15MB)
   - RootFS: 可以定制大小 (最小 ~5MB，完整 ~50MB+)

4. **版本兼容性**: 确保 OpenSBI、Kernel 和 Buildroot 版本相互兼容。

## 更新日期

- 复制日期: 2025-05-02
- 原始构建日期: 2024-04-26

## 许可证

这些二进制文件基于各自的开源许可证：
- OpenSBI: BSD-2-Clause
- Linux Kernel: GPL-2.0
- Buildroot 工具: 各自的许可证

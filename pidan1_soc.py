#!/usr/bin/env python3

"""
皮蛋一号 (Pidan1) SoC
基于 LiteX + VexRiscv-SMP 的 BitNet 加速器 SoC
硬件平台: MicroPhase Artix-7 200T (XC7A200T-FBG484)
"""

import os
import argparse

from migen import *

from litex.build.generic_platform import *
from litex.build.xilinx import Xilinx7SeriesPlatform, VivadoProgrammer

from litex.soc.cores.clock import S7PLL, S7MMCM
from litex.soc.cores.clock.xilinx_s7 import S7IDELAYCTRL
from litex.soc.cores.led import LedChaser
from litex.soc.cores.spi_flash import S7SPIFlash
from litex.soc.cores.gpio import GPIOOut

from litex.soc.integration.soc_core import *
from litex.soc.integration.soc import SoCRegion
from litex.soc.integration.builder import *

from litedram.modules import MT41K256M16
from litedram.phy import s7ddrphy

from liteeth.phy.rmii import LiteEthPHYRMII
from liteeth.phy.mii import LiteEthPHYMII

# 导入 BitNet 加速器
from bitnet_accel_litex import BitNetAccel


# MicroPhase Artix-7 200T 平台定义
_io = [
    # 时钟 (50MHz) - 基于官方文档
    ("clk50", 0, Pins("J19"), IOStandard("LVCMOS33")),

    # LED - 基于官方文档
    ("user_led", 0, Pins("M18"), IOStandard("LVCMOS33")),  # LED1
    ("user_led", 1, Pins("N18"), IOStandard("LVCMOS33")),  # LED2

    # 串口 (CH340 USB-UART) - 基于官方文档
    ("serial", 0,
        Subsignal("tx", Pins("V2")),
        Subsignal("rx", Pins("U2")),
        IOStandard("LVCMOS33")
    ),

    # DDR3 SDRAM (MT41K256M16, 256M × 16bit, 512MB)
    # 基于官方文档的正确引脚定义
    ("ddram", 0,
        Subsignal("a", Pins(
            "P1 M6 K3 K4 M5 J6 N2 K6",
            "P2 L1 M2 P6 L4 L5 N5"),
            IOStandard("SSTL15")),
        Subsignal("ba", Pins("J4 R1 M1"), IOStandard("SSTL15")),
        Subsignal("ras_n", Pins("M3"), IOStandard("SSTL15")),
        Subsignal("cas_n", Pins("N3"), IOStandard("SSTL15")),
        Subsignal("we_n", Pins("L6"), IOStandard("SSTL15")),
        Subsignal("dm", Pins("E2 H3"), IOStandard("SSTL15")),
        Subsignal("dq", Pins(
            "B2 F1 B1 D2 C2 F3 A1 G1",
            "J5 G2 K1 G3 H2 H5 J1 H4"),
            IOStandard("SSTL15"),
            Misc("IN_TERM=UNTUNED_SPLIT_40")),
        Subsignal("dqs_p", Pins("E1 K2"),
            IOStandard("DIFF_SSTL15"),
            Misc("IN_TERM=UNTUNED_SPLIT_40")),
        Subsignal("dqs_n", Pins("D1 J2"),
            IOStandard("DIFF_SSTL15"),
            Misc("IN_TERM=UNTUNED_SPLIT_40")),
        Subsignal("clk_p", Pins("P5"), IOStandard("DIFF_SSTL15")),
        Subsignal("clk_n", Pins("P4"), IOStandard("DIFF_SSTL15")),
        Subsignal("cke", Pins("N4"), IOStandard("SSTL15")),
        Subsignal("odt", Pins("L3"), IOStandard("SSTL15")),
        Subsignal("reset_n", Pins("F4"), IOStandard("SSTL15")),
        Misc("SLEW=FAST"),
    ),

    # 以太网 (RTL8211F) - 暂时禁用，待后续配置 GMII 接口
    # TODO: 添加 RTL8211F GMII 引脚定义

    # SPI Flash (IS25L128F-JBLE, 128MB) - 暂时禁用
    # TODO: 添加正确的 SPI Flash 引脚定义
]


class Platform(Xilinx7SeriesPlatform):
    default_clk_name = "clk50"
    default_clk_period = 1e9/50e6

    def __init__(self, toolchain="vivado"):
        Xilinx7SeriesPlatform.__init__(
            self, "xc7a200tfbg484-2", _io, toolchain=toolchain
        )

    def create_programmer(self):
        return VivadoProgrammer()

    def do_finalize(self, fragment):
        Xilinx7SeriesPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk50", loose=True), 1e9/50e6)


# Pidan1 SoC
class Pidan1SoC(SoCCore):
    def __init__(self, sys_clk_freq=100e6, **kwargs):
        platform = Platform()

        # 禁用集成的 ROM/SRAM，使用外部 DDR3
        kwargs["integrated_rom_size"] = 0x10000  # 64KB BootROM
        kwargs["integrated_sram_size"] = 0x2000   # 8KB SRAM
        kwargs["integrated_main_ram_size"] = 0    # 使用 DDR3

        # SoC 基类初始化
        SoCCore.__init__(self, platform, sys_clk_freq,
            cpu_type="vexriscv_smp",
            cpu_variant="linux",
            **kwargs)

        # 时钟复位 (50MHz 输入 -> 100MHz 系统时钟)
        self.submodules.crg = CRG(platform, sys_clk_freq)

        # DDR3 SDRAM
        self.submodules.ddrphy = s7ddrphy.A7DDRPHY(
            platform.request("ddram"),
            memtype="DDR3",
            nphases=4,
            sys_clk_freq=sys_clk_freq
        )
        self.add_sdram("sdram",
            phy=self.ddrphy,
            module=MT41K256M16(sys_clk_freq, "1:4"),
            l2_cache_size=8192,
            l2_cache_min_data_width=128,
            l2_cache_reverse=True
        )

        # 以太网 (RGMII)
        # TODO: 配置正确的 RGMII PHY
        # 暂时禁用以太网以便快速测试加速器
        # self.submodules.ethphy = LiteEthPHYMII(
        #     clock_pads=platform.request("eth_clocks"),
        #     pads=platform.request("eth"),
        #     with_hw_init_reset=True
        # )
        # self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

        # LED
        self.submodules.leds = LedChaser(
            pads=platform.request_all("user_led"),
            sys_clk_freq=sys_clk_freq
        )

        # BitNet 加速器
        # 映射到非缓存区域 0x80002000
        self.submodules.bitnet = BitNetAccel(platform)
        self.bus.add_slave(
            name="bitnet",
            slave=self.bitnet.bus,
            region=SoCRegion(
                origin=0x80002000,
                size=0x1000,  # 4KB
                cached=False
            )
        )
        self.logger.info(f"BitNet accelerator mapped at 0x80002000")


# 时钟复位生成器
class CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_sys4x = ClockDomain()
        self.clock_domains.cd_sys4x_dqs = ClockDomain()
        self.clock_domains.cd_idelay = ClockDomain()

        # 获取时钟输入
        clk50 = platform.request("clk50")

        # PLL: 50MHz -> 100MHz (sys), 400MHz (sys4x), 200MHz (idelay)
        self.submodules.pll = pll = S7MMCM(speedgrade=-2)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(clk50, 50e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        pll.create_clkout(self.cd_sys4x, 4*sys_clk_freq)
        pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
        pll.create_clkout(self.cd_idelay, 200e6)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin)

        # IDELAYCTRL
        self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_idelay)


# 构建和加载
def main():
    parser = argparse.ArgumentParser(description="Pidan1 SoC - BitNet Accelerator")
    parser.add_argument("--build", action="store_true", help="Build bitstream")
    parser.add_argument("--load", action="store_true", help="Load bitstream to FPGA")
    parser.add_argument("--sys-clk-freq", default=100e6, help="System clock frequency")
    parser.add_argument("--with-ethernet", action="store_true", help="Enable Ethernet")
    args = parser.parse_args()

    soc = Pidan1SoC(
        sys_clk_freq=int(float(args.sys_clk_freq)),
    )

    builder = Builder(soc, csr_csv="csr.csv", csr_json="csr.json")

    if args.build:
        builder.build()

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, "top.bit"))


if __name__ == "__main__":
    main()

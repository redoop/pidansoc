#!/usr/bin/env python3

"""
皮蛋一号 Lite (Pidan1 Lite) SoC
简化版本 - 去除 DDR3，使用内部 SRAM
专注于验证 BitNet 加速器功能
"""

import os
import argparse

from migen import *

from litex.build.generic_platform import *
from litex.build.xilinx import Xilinx7SeriesPlatform, VivadoProgrammer

from litex.soc.cores.clock import S7PLL
from litex.soc.cores.led import LedChaser

from litex.soc.integration.soc_core import *
from litex.soc.integration.soc import SoCRegion
from litex.soc.integration.builder import *

# 导入 BitNet 加速器
from bitnet_accel_litex import BitNetAccel


# 最小化平台定义 - 只包含基本 IO
# 引脚基于 MicroPhase A7-Lite 官方文档
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
        # 允许非 CCIO 引脚用作时钟输入
        # J19 不是 Clock Capable IO，需要此约束
        self.add_platform_command("set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk50_IBUF]")


# Pidan1 Lite SoC - 简化版
class Pidan1LiteSoC(SoCCore):
    def __init__(self, sys_clk_freq=100e6, **kwargs):
        platform = Platform()

        # 使用较大的集成 SRAM 代替 DDR3
        kwargs["integrated_rom_size"] = 0x10000   # 64KB BootROM
        kwargs["integrated_sram_size"] = 0x20000  # 128KB SRAM (增大以支持测试)
        kwargs["integrated_main_ram_size"] = 0    # 不使用 main_ram

        # SoC 基类初始化 - 使用 VexRiscv 单核版本
        SoCCore.__init__(self, platform, sys_clk_freq,
            cpu_type="vexriscv",
            cpu_variant="minimal",  # 使用最小变体以节省资源
            **kwargs)

        # 时钟复位 (50MHz 输入 -> 100MHz 系统时钟)
        self.submodules.crg = CRG(platform, sys_clk_freq)

        # LED 闪烁
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


# 简化的时钟复位生成器
class CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.clock_domains.cd_sys = ClockDomain()

        # 获取时钟输入
        clk50 = platform.request("clk50")

        # PLL: 50MHz -> 100MHz (sys)
        self.submodules.pll = pll = S7PLL(speedgrade=-2)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(clk50, 50e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin)


# 构建和加载
def main():
    parser = argparse.ArgumentParser(description="Pidan1 Lite SoC - BitNet Accelerator (No DDR3)")
    parser.add_argument("--build", action="store_true", help="Build bitstream")
    parser.add_argument("--load", action="store_true", help="Load bitstream to FPGA")
    parser.add_argument("--sys-clk-freq", default=100e6, help="System clock frequency")
    args = parser.parse_args()

    soc = Pidan1LiteSoC(
        sys_clk_freq=int(float(args.sys_clk_freq)),
    )

    builder = Builder(soc, csr_csv="csr.csv", csr_json="csr.json")

    if args.build:
        builder.build()

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, "impl/pidan1_litesoc.bit"))


if __name__ == "__main__":
    main()

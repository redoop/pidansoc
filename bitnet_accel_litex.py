#!/usr/bin/env python3

"""
BitNet 加速器 LiteX/Migen Wishbone 封装
将 Verilog 实现的 BitNet 加速器集成到 LiteX SoC
"""

from migen import *
from litex.soc.interconnect import wishbone
from litex.soc.integration.doc import AutoDoc, ModuleDoc


class BitNetAccel(Module, AutoDoc):
    """
    BitNet 矩阵向量乘法加速器

    1-bit 量化权重（-1, 0, +1）的矩阵向量乘法硬件加速
    最大支持 64×64 矩阵
    """

    def __init__(self, platform, pads=None):
        self.intro = ModuleDoc("""
        BitNet 加速器 Wishbone 从设备

        提供 4KB 地址空间用于寄存器、权重、输入和输出缓冲区访问
        基地址通常映射到 0x80002000（非缓存区域）
        """)

        # Wishbone 从接口
        self.bus = wishbone.Interface(data_width=32, adr_width=12)

        # 平台相关的源文件
        if platform is not None:
            platform.add_source("bitnet_accel.v")

        # 实例化 Verilog 模块
        self.specials += Instance(
            "bitnet_accel",

            # 参数
            p_MAX_DIM=64,
            p_ADDR_WIDTH=12,

            # 系统信号
            i_clk=ClockSignal(),
            i_rst=ResetSignal(),

            # Wishbone 从接口
            i_wb_adr_i=self.bus.adr,
            i_wb_dat_i=self.bus.dat_w,
            o_wb_dat_o=self.bus.dat_r,
            i_wb_we_i=self.bus.we,
            i_wb_stb_i=self.bus.stb,
            i_wb_cyc_i=self.bus.cyc,
            o_wb_ack_o=self.bus.ack,
        )


class BitNetAccelCSR(Module, AutoDoc):
    """
    BitNet 加速器 CSR 接口版本（可选）

    为了更方便的软件访问，提供 CSR 寄存器接口
    仅包含控制和状态寄存器，数据缓冲区通过 Wishbone 直接访问
    """

    def __init__(self, platform=None):
        from litex.soc.interconnect.csr import AutoCSR, CSRStorage, CSRStatus

        # 控制寄存器
        self.ctrl = CSRStorage(
            size=2,
            description="Control register: bit0=start, bit1=clear"
        )

        # 状态寄存器
        self.status = CSRStatus(
            size=2,
            description="Status register: bit0=done, bit1=busy"
        )

        # 矩阵维度配置
        self.size_m = CSRStorage(
            size=6,
            reset=1,
            description="Matrix rows (1~64)"
        )

        self.size_n = CSRStorage(
            size=6,
            reset=1,
            description="Matrix columns (1~64)"
        )

        # Wishbone 从接口用于数据缓冲区访问
        self.bus = wishbone.Interface(data_width=32, adr_width=12)

        # 实例化底层加速器
        self.submodules.accel = BitNetAccel(platform)

        # 注意：此版本中 CSR 仅用于控制/状态，
        # 权重/输入/输出数据仍通过 Wishbone 总线访问
        # 这样设计可以减少 CSR 地址空间占用

        # 直接连接 Wishbone 总线到加速器
        self.comb += self.bus.connect(self.accel.bus)


# 用于测试的简单包装器
if __name__ == "__main__":
    from migen.fhdl import verilog

    # 生成 Migen 输出用于验证
    class DummyPlatform:
        def add_source(self, filename):
            print(f"Would add source: {filename}")

    dut = BitNetAccel(platform=DummyPlatform())
    print(verilog.convert(dut,
                         ios={dut.bus.adr, dut.bus.dat_w, dut.bus.dat_r,
                              dut.bus.we, dut.bus.stb, dut.bus.cyc, dut.bus.ack}))

# Pidan1 SoC Makefile

# 工具链配置
PYTHON := python3
RISCV_PREFIX := riscv32-buildroot-linux-gnu-
RISCV_GCC := $(RISCV_PREFIX)gcc
RISCV_OBJCOPY := $(RISCV_PREFIX)objcopy

# 编译选项
CFLAGS := -O2 -Wall -Wextra
SYS_CLK_FREQ := 100e6

# 目标文件
SOC_SCRIPT := pidan1_soc.py
TEST_PROGRAM := bitnet_test
TEST_SOURCE := bitnet_test.c
FLASH_SCRIPT := flash_and_boot.sh

# LiteX 构建目录
BUILD_DIR := build/microphase_artix7_200t

.PHONY: all build load flash boot test clean help

all: build test

# 构建 SoC bitstream
build:
	@echo "Building Pidan1 SoC..."
	$(PYTHON) $(SOC_SCRIPT) --build --sys-clk-freq=$(SYS_CLK_FREQ)
	@echo "Build complete! Bitstream at: $(BUILD_DIR)/gateware/top.bit"

# 加载 bitstream 到 FPGA SRAM
load:
	@echo "Loading bitstream to FPGA..."
	$(PYTHON) $(SOC_SCRIPT) --load

# 使用脚本加载（替代方法）
load-script:
	@echo "Loading bitstream via script..."
	./$(FLASH_SCRIPT) load

# 烧录 bitstream 到 SPI Flash
flash:
	@echo "Flashing bitstream to SPI Flash..."
	./$(FLASH_SCRIPT) flash

# 引导 Linux 系统
boot:
	@echo "Booting Linux..."
	./$(FLASH_SCRIPT) boot

# 完整流程：加载 + 引导
run: load
	@echo "Waiting for FPGA initialization..."
	@sleep 2
	@$(MAKE) boot

# 编译测试程序（交叉编译）
test: $(TEST_PROGRAM)

$(TEST_PROGRAM): $(TEST_SOURCE)
	@echo "Compiling test program for RISC-V..."
	@if command -v $(RISCV_GCC) > /dev/null 2>&1; then \
		$(RISCV_GCC) $(CFLAGS) -o $@ $<; \
		echo "Test program compiled: $@"; \
	else \
		echo "WARNING: RISC-V toolchain not found ($(RISCV_GCC))"; \
		echo "Skipping test program compilation"; \
		echo "To compile on target, run: gcc $(CFLAGS) -o $(TEST_PROGRAM) $(TEST_SOURCE)"; \
	fi

# 生成文档
doc:
	@echo "Generating documentation..."
	$(PYTHON) $(SOC_SCRIPT) --doc

# 仿真（如果配置了仿真）
sim:
	@echo "Running simulation..."
	$(PYTHON) $(SOC_SCRIPT) --sim

# 清理构建产物
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -f $(TEST_PROGRAM)
	rm -f *.csv *.json csr.csv csr.json
	rm -f *.log *.jou *.str
	rm -f /tmp/load_bitstream.tcl /tmp/flash_bitstream.tcl
	@echo "Clean complete!"

# 深度清理（包括 LiteX 缓存）
distclean: clean
	@echo "Deep cleaning..."
	rm -rf __pycache__/
	rm -f *.pyc
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "Deep clean complete!"

# 显示帮助
help:
	@echo "Pidan1 SoC Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build        - Build SoC bitstream"
	@echo "  make load         - Load bitstream to FPGA SRAM (temporary)"
	@echo "  make flash        - Flash bitstream to SPI Flash (permanent)"
	@echo "  make boot         - Boot Linux via UART"
	@echo "  make run          - Load bitstream and boot Linux"
	@echo "  make test         - Compile test program"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make distclean    - Deep clean including caches"
	@echo "  make doc          - Generate documentation"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  SYS_CLK_FREQ      = $(SYS_CLK_FREQ)"
	@echo "  RISCV_PREFIX      = $(RISCV_PREFIX)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                          # Build bitstream"
	@echo "  make run                            # Load and boot"
	@echo "  SYS_CLK_FREQ=125e6 make build       # Build with 125MHz clock"
	@echo ""

# 检查依赖
check-deps:
	@echo "Checking dependencies..."
	@echo -n "Python3: "
	@command -v $(PYTHON) >/dev/null 2>&1 && echo "✓" || echo "✗ NOT FOUND"
	@echo -n "LiteX: "
	@$(PYTHON) -c "import litex" 2>/dev/null && echo "✓" || echo "✗ NOT FOUND"
	@echo -n "Migen: "
	@$(PYTHON) -c "import migen" 2>/dev/null && echo "✓" || echo "✗ NOT FOUND"
	@echo -n "RISC-V GCC: "
	@command -v $(RISCV_GCC) >/dev/null 2>&1 && echo "✓" || echo "✗ NOT FOUND"
	@echo -n "Vivado: "
	@command -v vivado >/dev/null 2>&1 && echo "✓" || echo "✗ NOT FOUND (check PATH)"
	@echo ""

#!/bin/bash
#
# Pidan1 SoC 构建监控脚本
#

BUILD_LOG="build.log"
BUILD_PID_FILE="build.pid"

if [ ! -f "$BUILD_LOG" ]; then
    echo "错误: 找不到构建日志文件 $BUILD_LOG"
    exit 1
fi

echo "===================================="
echo "  Pidan1 SoC 构建监控"
echo "===================================="
echo ""

# 检查构建进程是否还在运行
if [ -f "$BUILD_PID_FILE" ]; then
    BUILD_PID=$(cat "$BUILD_PID_FILE")
    if ps -p $BUILD_PID > /dev/null 2>&1; then
        echo "✓ 构建进程正在运行 (PID: $BUILD_PID)"
    else
        echo "✗ 构建进程已停止"
    fi
else
    echo "? 无法确定构建进程状态"
fi

echo ""
echo "---- 当前进度 ----"

# 检测构建阶段
if grep -q "Vivado" "$BUILD_LOG"; then
    echo "阶段: Vivado 综合与实现"

    if grep -q "Synthesis"  "$BUILD_LOG" | tail -1; then
        echo "  → 正在综合..."
    fi

    if grep -q "Implementation" "$BUILD_LOG" | tail -1; then
        echo "  → 正在实现..."
    fi

    if grep -q "Bitstream" "$BUILD_LOG" | tail -1; then
        echo "  → 正在生成 bitstream..."
    fi
elif grep -q "CC.*\.o" "$BUILD_LOG"; then
    echo "阶段: 编译 BIOS"
else
    echo "阶段: 初始化"
fi

echo ""
echo "---- 最新输出 (最后 20 行) ----"
tail -20 "$BUILD_LOG"

echo ""
echo "===================================="
echo "日志文件: $BUILD_LOG"
echo "使用 'tail -f $BUILD_LOG' 实时查看"
echo "===================================="

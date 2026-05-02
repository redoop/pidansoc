#!/bin/bash
# 监控简化版 SoC 构建进度

PID_FILE="build_lite.pid"
LOG_FILE="build_lite.log"

echo "=== Pidan1 Lite SoC 构建监控 ==="
echo ""

# 检查 PID 文件
if [ ! -f "$PID_FILE" ]; then
    echo "错误: 找不到 PID 文件 $PID_FILE"
    echo "请先启动构建: python3 pidan1_soc_lite.py --build"
    exit 1
fi

BUILD_PID=$(cat $PID_FILE)

# 检查进程是否运行
if ps -p $BUILD_PID > /dev/null 2>&1; then
    echo "✓ 构建进程正在运行 (PID: $BUILD_PID)"
    ELAPSED=$(ps -p $BUILD_PID -o etime= | tr -d ' ')
    echo "  运行时间: $ELAPSED"
else
    echo "✗ 构建进程已结束"
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "=== 构建结果检查 ==="
        if grep -q "ERROR:" "$LOG_FILE"; then
            echo "❌ 构建失败 - 发现错误"
            echo ""
            echo "=== 错误信息 ==="
            grep -E "ERROR:|CRITICAL|Error occured" "$LOG_FILE" | tail -10
        elif grep -q "Bitstream generation was successful" "$LOG_FILE"; then
            echo "✓ 构建成功!"
            echo ""
            BITSTREAM=$(find build/pidan1_soc_lite/gateware -name "*.bit" 2>/dev/null | head -1)
            if [ -n "$BITSTREAM" ]; then
                echo "比特流文件: $BITSTREAM"
                ls -lh "$BITSTREAM"
            fi
        else
            echo "⚠ 构建状态未知 - 请查看日志"
        fi
    fi
    exit 0
fi

echo ""
echo "=== 当前构建阶段 ==="

# 检测构建阶段
if grep -q "Starting Placer Task" "$LOG_FILE" 2>/dev/null; then
    echo "📍 布局 (Placement)"
elif grep -q "Starting Router Task" "$LOG_FILE" 2>/dev/null; then
    echo "🔀 布线 (Routing)"
elif grep -q "write_bitstream" "$LOG_FILE" 2>/dev/null; then
    echo "💾 生成比特流 (Bitstream Generation)"
elif grep -q "synth_design" "$LOG_FILE" 2>/dev/null; then
    echo "🔨 综合 (Synthesis)"
    # 显示综合进度
    if grep -q "Finished RTL Elaboration" "$LOG_FILE"; then
        echo "  ✓ RTL 详化完成"
    fi
    if grep -q "Finished RTL Optimization Phase 2" "$LOG_FILE"; then
        echo "  ✓ RTL 优化完成"
    fi
    if grep -q "Finished Technology Mapping" "$LOG_FILE"; then
        echo "  ✓ 技术映射完成"
    fi
elif grep -q "make.*进入目录.*software" "$LOG_FILE" 2>/dev/null; then
    echo "⚙️  编译软件库"
else
    echo "🚀 初始化"
fi

echo ""
echo "=== 最新输出 (最后 15 行) ==="
tail -15 "$LOG_FILE"

echo ""
echo "---"
echo "使用 'tail -f $LOG_FILE' 查看实时日志"

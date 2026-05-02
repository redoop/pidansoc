/*
 * BitNet 加速器用户态测试程序
 * 通过 /dev/mem mmap 访问硬件加速器
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

// 加速器基地址
#define BITNET_BASE_ADDR 0x80002000
#define BITNET_SIZE      0x1000  // 4KB

// 寄存器偏移
#define REG_CTRL         0x000
#define REG_STATUS       0x004
#define REG_SIZE_M       0x008
#define REG_SIZE_N       0x00C
#define REG_WEIGHT_BASE  0x010
#define REG_INPUT_BASE   0x410
#define REG_OUTPUT_BASE  0x450

// 控制位
#define CTRL_START       (1 << 0)
#define CTRL_CLEAR       (1 << 1)

// 状态位
#define STATUS_DONE      (1 << 0)
#define STATUS_BUSY      (1 << 1)

// 最大矩阵维度
#define MAX_DIM          64

// 全局指针：映射的加速器内存区域
static volatile uint32_t *accel_mem = NULL;

// 辅助函数：读寄存器
static inline uint32_t reg_read(uint32_t offset)
{
    return accel_mem[offset / 4];
}

// 辅助函数：写寄存器
static inline void reg_write(uint32_t offset, uint32_t value)
{
    accel_mem[offset / 4] = value;
}

// 编码权重：{-1, 0, +1} -> {0b10, 0b00, 0b01}
static void encode_weights(int8_t *weights, uint32_t m, uint32_t n, uint32_t *encoded)
{
    memset(encoded, 0, 256 * sizeof(uint32_t));

    for (uint32_t i = 0; i < m; i++) {
        for (uint32_t j = 0; j < n; j++) {
            uint32_t idx = i * MAX_DIM + j;  // 行优先
            uint32_t word_idx = idx / 16;
            uint32_t bit_offset = (idx % 16) * 2;

            int8_t w = weights[i * n + j];
            uint32_t encoded_val;

            if (w == 0) {
                encoded_val = 0b00;
            } else if (w > 0) {
                encoded_val = 0b01;  // +1
            } else {
                encoded_val = 0b10;  // -1
            }

            encoded[word_idx] |= (encoded_val << bit_offset);
        }
    }
}

// 打包输入向量：4 个 8-bit 元素打包到一个 32-bit word
static void pack_inputs(int8_t *inputs, uint32_t n, uint32_t *packed)
{
    memset(packed, 0, 16 * sizeof(uint32_t));

    for (uint32_t i = 0; i < n; i++) {
        uint32_t word_idx = i / 4;
        uint32_t byte_offset = i % 4;
        packed[word_idx] |= ((uint32_t)(uint8_t)inputs[i] << (byte_offset * 8));
    }
}

// 初始化加速器
static int bitnet_init(void)
{
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Failed to open /dev/mem");
        return -1;
    }

    accel_mem = mmap(NULL, BITNET_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                     fd, BITNET_BASE_ADDR);
    close(fd);

    if (accel_mem == MAP_FAILED) {
        perror("Failed to mmap accelerator");
        return -1;
    }

    printf("BitNet accelerator mapped at %p\n", (void *)accel_mem);

    // 复位加速器
    reg_write(REG_CTRL, CTRL_CLEAR);
    usleep(100);

    return 0;
}

// 清理
static void bitnet_cleanup(void)
{
    if (accel_mem != NULL && accel_mem != MAP_FAILED) {
        munmap((void *)accel_mem, BITNET_SIZE);
    }
}

// 执行矩阵向量乘法
static int bitnet_matvec(int8_t *weights, int8_t *input, int32_t *output,
                         uint32_t m, uint32_t n)
{
    if (m > MAX_DIM || n > MAX_DIM) {
        fprintf(stderr, "Matrix dimensions exceed maximum (%d)\n", MAX_DIM);
        return -1;
    }

    // 编码权重和打包输入
    uint32_t encoded_weights[256];
    uint32_t packed_input[16];

    encode_weights(weights, m, n, encoded_weights);
    pack_inputs(input, n, packed_input);

    // 配置矩阵维度
    reg_write(REG_SIZE_M, m);
    reg_write(REG_SIZE_N, n);

    // 写入权重
    for (int i = 0; i < 256; i++) {
        reg_write(REG_WEIGHT_BASE + i * 4, encoded_weights[i]);
    }

    // 写入输入向量
    for (int i = 0; i < 16; i++) {
        reg_write(REG_INPUT_BASE + i * 4, packed_input[i]);
    }

    // 启动计算
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    reg_write(REG_CTRL, CTRL_START);

    // 轮询等待完成
    uint32_t timeout = 1000000;  // 1M 次轮询
    while (timeout--) {
        uint32_t status = reg_read(REG_STATUS);
        if (status & STATUS_DONE) {
            break;
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    if (timeout == 0) {
        fprintf(stderr, "Accelerator timeout!\n");
        return -1;
    }

    // 读取结果
    for (uint32_t i = 0; i < m; i++) {
        output[i] = (int32_t)reg_read(REG_OUTPUT_BASE + i * 4);
    }

    // 计算耗时
    double elapsed = (end.tv_sec - start.tv_sec) * 1e9 +
                     (end.tv_nsec - start.tv_nsec);

    printf("Computation time: %.2f ns (%.2f us)\n", elapsed, elapsed / 1000.0);

    return 0;
}

// 软件参考实现（用于验证）
static void reference_matvec(int8_t *weights, int8_t *input, int32_t *output,
                            uint32_t m, uint32_t n)
{
    for (uint32_t i = 0; i < m; i++) {
        int32_t sum = 0;
        for (uint32_t j = 0; j < n; j++) {
            sum += weights[i * n + j] * input[j];
        }
        output[i] = sum;
    }
}

// 测试用例
static int run_test(const char *test_name, uint32_t m, uint32_t n)
{
    printf("\n=== Test: %s (M=%d, N=%d) ===\n", test_name, m, n);

    int8_t *weights = malloc(m * n * sizeof(int8_t));
    int8_t *input = malloc(n * sizeof(int8_t));
    int32_t *hw_output = malloc(m * sizeof(int32_t));
    int32_t *sw_output = malloc(m * sizeof(int32_t));

    if (!weights || !input || !hw_output || !sw_output) {
        fprintf(stderr, "Memory allocation failed\n");
        return -1;
    }

    // 生成随机测试数据
    srand(time(NULL));
    for (uint32_t i = 0; i < m * n; i++) {
        int r = rand() % 3;  // 0, 1, 2
        weights[i] = (r == 0) ? -1 : (r == 1) ? 0 : 1;
    }

    for (uint32_t i = 0; i < n; i++) {
        input[i] = (rand() % 256) - 128;  // -128 ~ 127
    }

    // 硬件加速计算
    if (bitnet_matvec(weights, input, hw_output, m, n) < 0) {
        fprintf(stderr, "Hardware computation failed\n");
        return -1;
    }

    // 软件参考计算
    reference_matvec(weights, input, sw_output, m, n);

    // 验证结果
    int errors = 0;
    for (uint32_t i = 0; i < m; i++) {
        if (hw_output[i] != sw_output[i]) {
            printf("Mismatch at row %d: HW=%d, SW=%d\n",
                   i, hw_output[i], sw_output[i]);
            errors++;
            if (errors >= 10) {
                printf("... (too many errors, stopping)\n");
                break;
            }
        }
    }

    if (errors == 0) {
        printf("✓ Test PASSED - All results match!\n");
    } else {
        printf("✗ Test FAILED - %d mismatches\n", errors);
    }

    free(weights);
    free(input);
    free(hw_output);
    free(sw_output);

    return (errors == 0) ? 0 : -1;
}

int main(int argc, char **argv)
{
    printf("BitNet Accelerator Test Program\n");
    printf("================================\n");

    if (bitnet_init() < 0) {
        fprintf(stderr, "Failed to initialize accelerator\n");
        return 1;
    }

    // 运行多个测试用例
    int pass_count = 0;
    int total_count = 0;

    // 小矩阵测试
    total_count++;
    if (run_test("Small matrix", 4, 4) == 0) pass_count++;

    // 中等矩阵测试
    total_count++;
    if (run_test("Medium matrix", 16, 16) == 0) pass_count++;

    // 大矩阵测试
    total_count++;
    if (run_test("Large matrix", 32, 32) == 0) pass_count++;

    // 最大矩阵测试
    total_count++;
    if (run_test("Maximum matrix", 64, 64) == 0) pass_count++;

    // 非方阵测试
    total_count++;
    if (run_test("Non-square matrix", 48, 32) == 0) pass_count++;

    printf("\n=== Summary ===\n");
    printf("Tests passed: %d / %d\n", pass_count, total_count);

    bitnet_cleanup();

    return (pass_count == total_count) ? 0 : 1;
}

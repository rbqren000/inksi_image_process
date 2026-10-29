#pragma once
#include <stdint.h>
#include <stddef.h>

// ============ 版本 ============
//
// 2.0.0：ABI 不兼容变更——InksiImageResult 删除 success / error，
//        改为单一 error_code（0 成功，非 0 见 INKSI_IMAGE_ERR_*）。
//        所有链接方必须与头文件同批重编；旧二进制读新库会读错字段。
// 2.0.1：行为修复——inksi_image_bitmap_to_rgb_bytes 由误输出的 B,G,R
//        改为 R,G,B（与函数名、各端 ImageProcessor、halftone_min::rgb_to_gray 一致）。
//        ABI 不变，但输出字节顺序变了，使用该函数的产物需重编。

#define INKSI_IMAGE_VERSION_MAJOR 2
#define INKSI_IMAGE_VERSION_MINOR 0
#define INKSI_IMAGE_VERSION_PATCH 1
#define INKSI_IMAGE_VERSION_STRING "2.0.1"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define INKSI_IMAGE_API __declspec(dllexport)
#else
#define INKSI_IMAGE_API __attribute__((visibility("default")))
#endif

/// 图像数据（RGBA 格式）
typedef struct {
    uint8_t* data;    ///< 像素数据（RGBA 连续排列）
    int width;
    int height;
    int channels;     ///< 1=灰度, 3=RGB, 4=RGBA
} InksiImage;

// ============ 错误码（与 SDK ErrorCodes 同号，便于上层直接透传） ============

/// 成功
#define INKSI_IMAGE_OK                    0
/// 参数非法（空指针 / 宽高非正 / 角点缺失）
#define INKSI_IMAGE_ERR_INVALID_INPUT   105
/// 处理失败（OpenCV 抛异常等未归类失败）
#define INKSI_IMAGE_ERR_PROCESS_FAILED  903
/// 内存不足（malloc / 图像分配失败）
#define INKSI_IMAGE_ERR_OUT_OF_MEMORY   904
/// 该平台/构建不支持此能力（未启用 OpenCV）
#define INKSI_IMAGE_ERR_UNSUPPORTED     905

/// 处理结果（调用方用 inksi_image_free_result 释放）
///
/// `error_code` 是唯一失败依据：0 表示成功，非 0 取 `INKSI_IMAGE_ERR_*`。
/// 失败原因不跨边界回传文案——上层按 error_code 映射文案（国际化）；
/// C 库只在 stderr 打印诊断信息（Android logcat / Xcode 控制台 / hilog 可见）。
typedef struct {
    uint8_t* data;
    int width;
    int height;
    int channels;
    int error_code;
} InksiImageResult;

/// 释放处理结果
INKSI_IMAGE_API void inksi_image_free_result(InksiImageResult* result);

// ============ 图像预处理 ============

/// 透明像素 → 白色
INKSI_IMAGE_API InksiImageResult inksi_image_transparent_to_white(const uint8_t* data, int w, int h);

/// 缩放到指定高度（等比例）
INKSI_IMAGE_API InksiImageResult inksi_image_resize_to_height(const uint8_t* data, int w, int h, int targetHeight);

/// 旋转（90°/180°/270°）
INKSI_IMAGE_API InksiImageResult inksi_image_rotate(const uint8_t* data, int w, int h, int channels, double degrees);

/// RGBA → RGB（3 字节/像素，R,G,B 顺序，可直接交给 rgb_to_gray 等下游）
INKSI_IMAGE_API InksiImageResult inksi_image_bitmap_to_rgb_bytes(const uint8_t* data, int w, int h);

/// RGBA → 灰度
INKSI_IMAGE_API InksiImageResult inksi_image_rgb_to_gray(const uint8_t* data, int w, int h);

// ============ OpenCV 增强预处理 ============

/// 底色清除（大核高斯模糊 + 除法去背景）
INKSI_IMAGE_API InksiImageResult inksi_image_clear_background(const uint8_t* data, int w, int h, int channels);

/// 透视矫正（corners: [x1,y1, x2,y2, x3,y3, x4,y4]）
INKSI_IMAGE_API InksiImageResult inksi_image_correct_perspective(const uint8_t* data, int w, int h,
                                                                  int channels, const double* corners);

#ifdef __cplusplus
}
#endif

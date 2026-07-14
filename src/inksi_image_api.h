#pragma once
#include <stdint.h>
#include <stddef.h>

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

/// 处理结果（调用方用 inksi_image_free_result 释放）
typedef struct {
    uint8_t* data;
    int width;
    int height;
    int channels;
    int success;      ///< 0=失败, 1=成功
    const char* error;///< 失败时的错误描述
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

/// RGBA → BGR（打印机半色调引擎需要的格式）
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

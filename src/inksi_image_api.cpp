#include "inksi_image_api.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifdef INKSI_USE_OPENCV
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#endif

static InksiImageResult make_result(uint8_t* data, int w, int h, int ch, int success, const char* err) {
    InksiImageResult r;
    r.data = data; r.width = w; r.height = h; r.channels = ch; r.success = success; r.error = err;
    return r;
}

static InksiImageResult make_error(const char* msg) {
    return make_result(NULL, 0, 0, 0, 0, msg);
}

INKSI_IMAGE_API void inksi_image_free_result(InksiImageResult* result) {
    if (result && result->data) { free(result->data); result->data = NULL; }
}

// ── 透明 → 白底 ──

INKSI_IMAGE_API InksiImageResult inksi_image_transparent_to_white(const uint8_t* data, int w, int h) {
    if (!data || w <= 0 || h <= 0) return make_error("invalid input");
    int size = w * h * 4;
    uint8_t* out = (uint8_t*)malloc(size);
    if (!out) return make_error("malloc failed");
    for (int i = 0; i < size; i += 4) {
        out[i] = data[i]; out[i+1] = data[i+1]; out[i+2] = data[i+2];
        out[i+3] = 255;
    }
    return make_result(out, w, h, 4, 1, NULL);
}

// ── 缩放到指定高度 ──

INKSI_IMAGE_API InksiImageResult inksi_image_resize_to_height(const uint8_t* data, int w, int h, int targetHeight) {
    if (!data || w <= 0 || h <= 0 || targetHeight <= 0) return make_error("invalid input");
#ifdef INKSI_USE_OPENCV
    cv::Mat src(h, w, CV_8UC4, (void*)data);
    float ratio = (float)targetHeight / h;
    int newW = (int)(w * ratio);
    cv::Mat dst;
    cv::resize(src, dst, cv::Size(newW, targetHeight));
    uint8_t* out = (uint8_t*)malloc(newW * targetHeight * 4);
    if (!out) return make_error("malloc failed");
    memcpy(out, dst.data, newW * targetHeight * 4);
    return make_result(out, newW, targetHeight, 4, 1, NULL);
#else
    return make_error("OpenCV required: resize_to_height");
#endif
}

// ── 旋转 ──

INKSI_IMAGE_API InksiImageResult inksi_image_rotate(const uint8_t* data, int w, int h, int channels, double degrees) {
    if (!data || w <= 0 || h <= 0) return make_error("invalid input");
#ifdef INKSI_USE_OPENCV
    int type = (channels == 4) ? CV_8UC4 : (channels == 3) ? CV_8UC3 : CV_8UC1;
    cv::Mat src(h, w, type, (void*)data);
    cv::Mat dst;
    cv::Mat rot = cv::getRotationMatrix2D(cv::Point2f(w/2.0f, h/2.0f), degrees, 1.0);
    cv::warpAffine(src, dst, rot, cv::Size(w, h));
    uint8_t* out = (uint8_t*)malloc(w * h * channels);
    if (!out) return make_error("malloc failed");
    memcpy(out, dst.data, w * h * channels);
    return make_result(out, w, h, channels, 1, NULL);
#else
    return make_error("OpenCV required: rotate");
#endif
}

// ── RGBA → BGR ──

INKSI_IMAGE_API InksiImageResult inksi_image_bitmap_to_rgb_bytes(const uint8_t* data, int w, int h) {
    if (!data || w <= 0 || h <= 0) return make_error("invalid input");
    int size = w * h * 3;
    uint8_t* out = (uint8_t*)malloc(size);
    if (!out) return make_error("malloc failed");
    for (int i = 0; i < w * h; i++) {
        int src = i * 4, dst = i * 3;
        out[dst]     = data[src + 2];
        out[dst + 1] = data[src + 1];
        out[dst + 2] = data[src];
    }
    return make_result(out, w, h, 3, 1, NULL);
}

// ── RGBA → 灰度 ──

INKSI_IMAGE_API InksiImageResult inksi_image_rgb_to_gray(const uint8_t* data, int w, int h) {
    if (!data || w <= 0 || h <= 0) return make_error("invalid input");
    int size = w * h;
    uint8_t* out = (uint8_t*)malloc(size);
    if (!out) return make_error("malloc failed");
    for (int i = 0; i < size; i++) {
        int p = i * 4;
        out[i] = (uint8_t)(data[p] * 0.299f + data[p+1] * 0.587f + data[p+2] * 0.114f);
    }
    return make_result(out, w, h, 1, 1, NULL);
}

// ── 底色清除 ──

INKSI_IMAGE_API InksiImageResult inksi_image_clear_background(const uint8_t* data, int w, int h, int channels) {
    if (!data || w <= 0 || h <= 0) return make_error("invalid input");
#ifdef INKSI_USE_OPENCV
    int type = (channels == 4) ? CV_8UC4 : (channels == 3) ? CV_8UC3 : CV_8UC1;
    cv::Mat src(h, w, type, (void*)data);
    cv::Mat gray, norm, blur, bg;
    if (channels >= 3) cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);
    else gray = src.clone();
    cv::normalize(gray, norm, 0, 255, cv::NORM_MINMAX);
    cv::GaussianBlur(norm, blur, cv::Size(101, 101), 0);
    cv::divide(blur, cv::Scalar(255), bg);
    cv::normalize(bg, bg, 0, 255, cv::NORM_MINMAX);
    uint8_t* out = (uint8_t*)malloc(w * h);
    if (!out) return make_error("malloc failed");
    memcpy(out, bg.data, w * h);
    return make_result(out, w, h, 1, 1, NULL);
#else
    return make_error("OpenCV required: clear_background");
#endif
}

// ── 透视矫正 ──

INKSI_IMAGE_API InksiImageResult inksi_image_correct_perspective(const uint8_t* data, int w, int h,
                                                                  int channels, const double* corners) {
    if (!data || w <= 0 || h <= 0 || !corners) return make_error("invalid input");
#ifdef INKSI_USE_OPENCV
    int type = (channels == 4) ? CV_8UC4 : (channels == 3) ? CV_8UC3 : CV_8UC1;
    cv::Mat src(h, w, type, (void*)data);
    cv::Point2f srcPts[4] = {
        {(float)corners[0], (float)corners[1]},
        {(float)corners[2], (float)corners[3]},
        {(float)corners[4], (float)corners[5]},
        {(float)corners[6], (float)corners[7]},
    };
    double dstW = fmax(fabs(srcPts[1].x - srcPts[0].x), fabs(srcPts[3].x - srcPts[2].x));
    double dstH = fmax(fabs(srcPts[3].y - srcPts[0].y), fabs(srcPts[2].y - srcPts[1].y));
    cv::Point2f dstPts[4] = {
        {0, 0}, {(float)dstW, 0}, {(float)dstW, (float)dstH}, {0, (float)dstH}
    };
    cv::Mat M = cv::getPerspectiveTransform(srcPts, dstPts);
    cv::Mat dst;
    cv::warpPerspective(src, dst, M, cv::Size((int)dstW, (int)dstH));
    uint8_t* out = (uint8_t*)malloc((int)(dstW * dstH * channels));
    if (!out) return make_error("malloc failed");
    memcpy(out, dst.data, (int)(dstW * dstH * channels));
    return make_result(out, (int)dstW, (int)dstH, channels, 1, NULL);
#else
    return make_error("OpenCV required: correct_perspective");
#endif
}

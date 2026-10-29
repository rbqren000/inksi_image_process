# inksi_image_process

跨平台图像处理 C API。各端编译出动态库后供 Dart FFI 统一调用。

## 支持的平台

| 平台 | 输出 | CI 环境 |
|------|------|--------|
| Android | `.so` (ARM64/ARM32) | ubuntu-latest + NDK |
| iOS | `.a` (ARM64) | macos-latest |
| macOS | `.dylib` (ARM64/x86_64) | macos-latest |
| Windows | `.dll` (x86_64) | windows-latest |
| Linux | `.so` (x86_64) | ubuntu-latest |
| OHOS | `.so` (ARM64) | 本地 DevEco |

## 使用

```c
#include "inksi_image_api.h"

// 图像预处理
InksiImageResult result = inksi_image_clear_background(input_data, width, height, channels);
inksi_image_free_result(&result);
```

## 依赖

编译时自动从 OpenCV 官方 GitHub 下载 OpenCV 4.13.0。OHOS 需要使用本地 DevEco 环境手动编译。

## 版本与兼容性

| 版本 | 变更 |
|------|------|
| 2.0.0 | **ABI 不兼容**：`InksiImageResult` 删除 `success` / `error`，改为单一 `error_code`（`0` 成功；`105` 参数非法、`903` 处理失败、`904` 内存不足、`905` 未启用 OpenCV）。失败诊断只写 stderr，不跨边界；文案由调用方按码映射（便于国际化）。所有链接方必须与头文件同批重编。 |
| 1.0.x | `success` + `const char* error` 双字段 |

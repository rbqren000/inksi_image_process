#!/bin/bash
set -euo pipefail

# ============================================================
# Android 编译脚本（macOS/Linux）
# 从源码编译 OpenCV 4.13.0 + 合并到 inksi_image.a
# 产物: inksi_image-android-{ABI}.a（自包含 OpenCV）
# 用法: ./build-android.sh [arm64-v8a|armeabi-v7a]  (默认 arm64-v8a)
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"
ABI="${1:-arm64-v8a}"

if [[ "$ABI" != "arm64-v8a" && "$ABI" != "armeabi-v7a" ]]; then
    echo "Error: unsupported ABI '$ABI'. Use arm64-v8a or armeabi-v7a"
    exit 1
fi
echo "=== Building for ABI: $ABI ==="

# 检查 NDK
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        ANDROID_NDK_HOME=$(ls -d "$HOME/Library/Android/sdk/ndk"/*/ 2>/dev/null | sort -V | tail -1)
    elif [ -d "$HOME/Android/Sdk/ndk" ]; then
        ANDROID_NDK_HOME=$(ls -d "$HOME/Android/Sdk/ndk"/*/ 2>/dev/null | sort -V | tail -1)
    fi
fi
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "Error: ANDROID_NDK_HOME not set"
    exit 1
fi
echo "NDK: $ANDROID_NDK_HOME"

# 编译 OpenCV 静态库（flags 变更时自动清理旧缓存）
OPENCV_INSTALL_DIR="/tmp/opencv-android-install-$ABI"
_OCV_FLAGS_FILE="$OPENCV_INSTALL_DIR/.opencv_flags"

_OCV_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-21 -DBUILD_SHARED_LIBS=OFF -DBUILD_LIST=core,imgproc -DWITH_KLEIDICV=OFF -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DBUILD_ANDROID_EXAMPLES=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_OPENEXR=OFF -DWITH_AVIF=OFF -DWITH_WEBP=OFF -DWITH_JASPER=OFF -DENABLE_PRECOMPILED_HEADERS=OFF -DCMAKE_BUILD_TYPE=Release -Wno-dev"

_NEED_BUILD=false
if [ ! -f "$OPENCV_INSTALL_DIR/sdk/native/jni/OpenCVConfig.cmake" ]; then
    _NEED_BUILD=true
elif [ ! -f "$_OCV_FLAGS_FILE" ] || [ "$_OCV_FLAGS" != "$(cat "$_OCV_FLAGS_FILE")" ]; then
    echo "OpenCV flags changed, discarding stale cache..."
    rm -rf "$OPENCV_INSTALL_DIR"
    _NEED_BUILD=true
fi

if $_NEED_BUILD; then
    echo "Building OpenCV $OPENCV_VERSION for Android ($ABI) from source..."
    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
            "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p "/tmp/opencv-android-build-$ABI" && cd "/tmp/opencv-android-build-$ABI"
    # shellcheck disable=SC2086
    cmake "/tmp/opencv-${OPENCV_VERSION}" $_OCV_FLAGS
    cmake --build . -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
    cmake --install .
    echo "$_OCV_FLAGS" > "$_OCV_FLAGS_FILE"
    echo "OpenCV installed to $OPENCV_INSTALL_DIR"
else
    echo "OpenCV cached at $OPENCV_INSTALL_DIR"
fi

# 编译 inksi_image（此时仅含自己代码，不含 OpenCV）
echo "Building inksi_image for Android $ABI..."
BUILD_DIR="$SCRIPT_DIR/build-android-$ABI"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake "$SCRIPT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=$ABI \
    -DANDROID_PLATFORM=android-21 \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/sdk/native/jni" \
    -DINKSI_USE_OPENCV=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -Wno-dev
cmake --build . -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

# 合并 OpenCV 静态库到 inksi_image.a
echo "Merging OpenCV static libs..."

# 使用 NDK 的 llvm-ar（支持 MRI），macOS 系统 ar 是 BSD 版不支持 MRI
AR_CMD=$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -name "llvm-ar" -type f 2>/dev/null | head -1)
if [ -z "$AR_CMD" ]; then
    echo "Warning: llvm-ar not found, falling back to system ar (may fail on macOS)"
    AR_CMD="ar"
fi
echo "Using: $AR_CMD"

# 先将 cmake 编译出的 libinksi_image.a 改名，避免被 MRI 的 create 覆盖
cp libinksi_image.a libinksi_image_own.a

MRI=merge_opencv.mri
echo "create libinksi_image.a" > "$MRI"
echo "addlib libinksi_image_own.a" >> "$MRI"
find "$OPENCV_INSTALL_DIR" -name '*.a' | sort | while read lib; do
    echo "addlib $lib" >> "$MRI"
done
echo "save" >> "$MRI"
echo "end" >> "$MRI"
"$AR_CMD" -M < "$MRI"
rm -f "$MRI" libinksi_image_own.a

OUTPUT="$SCRIPT_DIR/inksi_image-android-$ABI.a"
cp libinksi_image.a "$OUTPUT"
echo "Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"

#!/bin/bash
set -euo pipefail

# ============================================================
# Android 编译脚本（macOS/Linux）
# 产物: build-android-arm64-v8a/libinksi_image.a
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"
OPENCV_ZIP="/tmp/opencv-${OPENCV_VERSION}-android-sdk.zip"
OPENCV_DIR="/tmp/OpenCV-android-sdk"

# 检查 NDK
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    # 尝试常见路径
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

# 下载 OpenCV Android SDK
if [ ! -d "$OPENCV_DIR" ]; then
    echo "Downloading OpenCV Android SDK..."
    curl -L -o "$OPENCV_ZIP" "https://github.com/opencv/opencv/releases/download/$OPENCV_VERSION/opencv-${OPENCV_VERSION}-android-sdk.zip"
    unzip -q "$OPENCV_ZIP" -d /tmp/
fi

# 编译
echo "Building inksi_image for Android arm64-v8a..."
mkdir -p "$SCRIPT_DIR/build-android-arm64-v8a"
cd "$SCRIPT_DIR/build-android-arm64-v8a"
cmake "$SCRIPT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-21 \
    -DOpenCV_DIR="$OPENCV_DIR/sdk/native/jni" \
    -DINKSI_USE_OPENCV=ON \
    -DCMAKE_BUILD_TYPE=Release
cmake --build . -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
cp libinksi_image.a "$SCRIPT_DIR/inksi_image-android-arm64-v8a.a"
echo "Done: $SCRIPT_DIR/inksi_image-android-arm64-v8a.a ($(du -h "$SCRIPT_DIR/inksi_image-android-arm64-v8a.a" | cut -f1))"

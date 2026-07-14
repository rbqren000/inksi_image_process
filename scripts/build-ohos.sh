#!/bin/bash
set -euo pipefail

# ============================================================
# OHOS（鸿蒙）编译脚本（macOS/Windows/Linux，需 DevEco NDK）
# 产物: build-ohos/libinksi_image.so → inksi_image-ohos-arm64-v8a.so
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"
OPENCV_SRC="$SCRIPT_DIR/opencv-${OPENCV_VERSION}"

# 查找 OHOS NDK
OHOS_NDK="${OHOS_NDK_HOME:-}"
if [ -z "$OHOS_NDK" ]; then
    # macOS 常见路径
    for p in \
        "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native" \
        "$HOME/Library/Huawei/DevEcoStudio/sdk/default/openharmony/native"; do
        if [ -f "$p/build/cmake/ohos.toolchain.cmake" ]; then
            OHOS_NDK="$p"
            break
        fi
    done
fi
TOOLCHAIN="$OHOS_NDK/build/cmake/ohos.toolchain.cmake"
if [ ! -f "$TOOLCHAIN" ]; then
    echo "Error: OHOS NDK not found. Set OHOS_NDK_HOME or install DevEco Studio."
    exit 1
fi
echo "OHOS NDK: $OHOS_NDK"

# 检查 OpenCV 源码
if [ ! -f "$OPENCV_SRC/CMakeLists.txt" ]; then
    echo "Downloading OpenCV $OPENCV_VERSION source..."
    curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
        "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
    unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    OPENCV_SRC="/tmp/opencv-${OPENCV_VERSION}"
fi

# 编译 OpenCV for OHOS（flags 变更时自动清理旧缓存）
OPENCV_INSTALL_DIR="/tmp/opencv-ohos-install"
_OCV_FLAGS_FILE="$OPENCV_INSTALL_DIR/.opencv_flags"

_OCV_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN -DOHOS_ARCH=arm64-v8a -DBUILD_SHARED_LIBS=OFF -DWITH_KLEIDICV=OFF -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_FFMPEG=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_CUDA=OFF -DWITH_V4L=OFF -DWITH_GSTREAMER=OFF -DENABLE_PRECOMPILED_HEADERS=OFF -DCMAKE_BUILD_TYPE=Release"

_NEED_BUILD=false
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    _NEED_BUILD=true
elif [ ! -f "$_OCV_FLAGS_FILE" ] || [ "$_OCV_FLAGS" != "$(cat "$_OCV_FLAGS_FILE")" ]; then
    echo "OpenCV flags changed, discarding stale cache..."
    rm -rf "$OPENCV_INSTALL_DIR"
    _NEED_BUILD=true
fi

if $_NEED_BUILD; then
    echo "Building OpenCV $OPENCV_VERSION for OHOS (arm64-v8a)..."
    mkdir -p /tmp/opencv-ohos-build && cd /tmp/opencv-ohos-build
    # shellcheck disable=SC2086
    cmake "$OPENCV_SRC" $_OCV_FLAGS
    cmake --build . -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
    cmake --install .
    echo "$_OCV_FLAGS" > "$_OCV_FLAGS_FILE"
    echo "OpenCV installed to $OPENCV_INSTALL_DIR"
else
    echo "OpenCV cached at $OPENCV_INSTALL_DIR"
fi

# 编译 inksi_image for OHOS
echo "Building inksi_image for OHOS arm64-v8a..."
mkdir -p "$SCRIPT_DIR/build-ohos"
cd "$SCRIPT_DIR/build-ohos"
cmake "$SCRIPT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DOHOS_ARCH=arm64-v8a \
    -DINKSI_USE_OPENCV=ON \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/lib/cmake/opencv4" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build . -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

cp libinksi_image.so "$SCRIPT_DIR/inksi_image-ohos-arm64-v8a.so"
echo "Done: $SCRIPT_DIR/inksi_image-ohos-arm64-v8a.so ($(du -h "$SCRIPT_DIR/inksi_image-ohos-arm64-v8a.so" | cut -f1))"

#!/bin/bash
set -euo pipefail

# ============================================================
# macOS 编译脚本（仅 macOS）
# 编译本机架构（arm64 或 x86_64），不支持 universal
# 如需 universal 产物，请使用 CI（matrix 双架构编译 + lipo 合成）
# 产物: build-macos/libinksi_image.dylib → inksi_image-macos-{arch}.dylib
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"

if [ "$(uname)" != "Darwin" ]; then
    echo "Error: macOS build requires macOS"
    exit 1
fi

# 检测本机架构
ARCH=$(uname -m)  # arm64 或 x86_64
echo "Host architecture: $ARCH"

# 编译 OpenCV（flags 变更时自动清理旧缓存）
OPENCV_INSTALL_DIR="/tmp/opencv-macos-${ARCH}"
_OCV_FLAGS_FILE="$OPENCV_INSTALL_DIR/.opencv_flags"

_OCV_FLAGS="-DBUILD_SHARED_LIBS=OFF -DBUILD_LIST=core,imgproc -DWITH_KLEIDICV=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_OPENEXR=OFF -DWITH_AVIF=OFF -DWITH_WEBP=OFF -DWITH_JASPER=OFF -DWITH_EIGEN=OFF -DENABLE_PRECOMPILED_HEADERS=OFF"

_NEED_BUILD=false
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    _NEED_BUILD=true
elif [ ! -f "$_OCV_FLAGS_FILE" ] || [ "$_OCV_FLAGS" != "$(cat "$_OCV_FLAGS_FILE")" ]; then
    echo "OpenCV flags changed, discarding stale cache..."
    rm -rf "$OPENCV_INSTALL_DIR"
    _NEED_BUILD=true
fi

if $_NEED_BUILD; then
    echo "Building OpenCV $OPENCV_VERSION from source (macOS $ARCH)..."
    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
            "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p /tmp/opencv-macos-build-${ARCH} && cd /tmp/opencv-macos-build-${ARCH}
    # shellcheck disable=SC2086
    cmake "/tmp/opencv-${OPENCV_VERSION}" $_OCV_FLAGS
    cmake --build . -j"$(sysctl -n hw.ncpu)"
    cmake --install .
    echo "$_OCV_FLAGS" > "$_OCV_FLAGS_FILE"
    echo "OpenCV installed to $OPENCV_INSTALL_DIR"
else
    echo "OpenCV cached at $OPENCV_INSTALL_DIR"
fi

# 编译 inksi_image（本机架构）
echo "Building inksi_image for macOS ($ARCH)..."
mkdir -p "$SCRIPT_DIR/build-macos-${ARCH}"
cd "$SCRIPT_DIR/build-macos-${ARCH}"
cmake "$SCRIPT_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DINKSI_USE_OPENCV=ON \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/lib/cmake/opencv4"
cmake --build . -j"$(sysctl -n hw.ncpu)"

cp libinksi_image.dylib "$SCRIPT_DIR/inksi_image-macos-${ARCH}.dylib"
echo "Architecture: $ARCH"
echo "Done: $SCRIPT_DIR/inksi_image-macos-${ARCH}.dylib ($(du -h "$SCRIPT_DIR/inksi_image-macos-${ARCH}.dylib" | cut -f1))"

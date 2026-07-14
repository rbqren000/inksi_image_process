#!/bin/bash
set -euo pipefail

# ============================================================
# Linux 编译脚本（仅 Linux）
# 依赖: cmake build-essential wget unzip
# 产物: build-linux/libinksi_image.so → inksi_image-linux-x86_64.so
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"

if [ "$(uname)" != "Linux" ]; then
    echo "Error: this script must be run on Linux"
    exit 1
fi

# 编译 OpenCV（flags 变更时自动清理旧缓存）
OPENCV_INSTALL_DIR="/tmp/opencv-install"
_OCV_FLAGS_FILE="$OPENCV_INSTALL_DIR/.opencv_flags"

_OCV_FLAGS="-DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_OPENEXR=OFF -DWITH_AVIF=OFF -DWITH_WEBP=OFF -DWITH_JASPER=OFF -DWITH_EIGEN=OFF -DENABLE_PRECOMPILED_HEADERS=OFF"

_NEED_BUILD=false
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    _NEED_BUILD=true
elif [ ! -f "$_OCV_FLAGS_FILE" ] || [ "$_OCV_FLAGS" != "$(cat "$_OCV_FLAGS_FILE")" ]; then
    echo "OpenCV flags changed, discarding stale cache..."
    rm -rf "$OPENCV_INSTALL_DIR"
    _NEED_BUILD=true
fi

if $_NEED_BUILD; then
    echo "Building OpenCV $OPENCV_VERSION from source (Linux)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cmake build-essential wget unzip

    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        wget -q "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip" -O "/tmp/opencv-${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p /tmp/opencv-linux-build && cd /tmp/opencv-linux-build
    # shellcheck disable=SC2086
    cmake "/tmp/opencv-${OPENCV_VERSION}" $_OCV_FLAGS
    cmake --build . -j"$(nproc)"
    cmake --install .
    echo "$_OCV_FLAGS" > "$_OCV_FLAGS_FILE"
    echo "OpenCV installed to $OPENCV_INSTALL_DIR"
else
    echo "OpenCV cached at $OPENCV_INSTALL_DIR"
fi

# 编译 inksi_image
echo "Building inksi_image for Linux x86_64..."
mkdir -p "$SCRIPT_DIR/build-linux"
cd "$SCRIPT_DIR/build-linux"
cmake "$SCRIPT_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DINKSI_USE_OPENCV=ON \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/lib/cmake/opencv4"
cmake --build . -j"$(nproc)"

cp libinksi_image.so "$SCRIPT_DIR/inksi_image-linux-x86_64.so"
echo "Done: $SCRIPT_DIR/inksi_image-linux-x86_64.so ($(du -h "$SCRIPT_DIR/inksi_image-linux-x86_64.so" | cut -f1))"

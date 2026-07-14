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

# 编译 OpenCV（如 cached 则跳过）
OPENCV_INSTALL_DIR="/tmp/opencv-macos-${ARCH}"
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    echo "Building OpenCV $OPENCV_VERSION from source (macOS $ARCH)..."
    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
            "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p /tmp/opencv-macos-build-${ARCH} && cd /tmp/opencv-macos-build-${ARCH}
    cmake "/tmp/opencv-${OPENCV_VERSION}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_INSTALL_PREFIX="$OPENCV_INSTALL_DIR" \
        -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
        -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF \
        -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF \
        -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF \
        -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF \
        -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF \
        -DENABLE_PRECOMPILED_HEADERS=OFF
    cmake --build . -j"$(sysctl -n hw.ncpu)"
    cmake --install .
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

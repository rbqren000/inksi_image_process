#!/bin/bash
set -euo pipefail

# ============================================================
# macOS 编译脚本（仅 macOS）
# 产物: build-macos/libinksi_image.dylib → inksi_image-macos-universal.dylib
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"

if [ "$(uname)" != "Darwin" ]; then
    echo "Error: macOS build requires macOS"
    exit 1
fi

# 编译 OpenCV（如 cached 则跳过）
# 使用独立目录，避免与旧的单架构缓存混淆
OPENCV_INSTALL_DIR="/tmp/opencv-macos-install-universal"
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    echo "Building OpenCV $OPENCV_VERSION from source (macOS)..."
    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
            "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p /tmp/opencv-macos-build && cd /tmp/opencv-macos-build
    cmake "/tmp/opencv-${OPENCV_VERSION}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_KLEIDICV=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$OPENCV_INSTALL_DIR" \
        -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
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

# 编译 inksi_image
echo "Building inksi_image for macOS..."
mkdir -p "$SCRIPT_DIR/build-macos"
cd "$SCRIPT_DIR/build-macos"
cmake "$SCRIPT_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DINKSI_USE_OPENCV=ON \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/lib/cmake/opencv4"
cmake --build . -j"$(sysctl -n hw.ncpu)"

cp libinksi_image.dylib "$SCRIPT_DIR/inksi_image-macos-universal.dylib"
echo "Architectures: $(lipo -info "$SCRIPT_DIR/inksi_image-macos-universal.dylib" | sed 's/.*://')"
echo "Done: $SCRIPT_DIR/inksi_image-macos-universal.dylib ($(du -h "$SCRIPT_DIR/inksi_image-macos-universal.dylib" | cut -f1))"

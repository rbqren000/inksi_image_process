#!/bin/bash
set -euo pipefail

# ============================================================
# iOS 编译脚本（仅 macOS）
# 从源码编译 OpenCV 4.13.0 + 合并到 inksi_image.a
# 产物: inksi_image-ios-arm64.a（自包含 OpenCV）
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"

if [ "$(uname)" != "Darwin" ]; then
    echo "Error: iOS build requires macOS"
    exit 1
fi

# 编译 OpenCV 静态库（flags 变更时自动清理旧缓存）
OPENCV_INSTALL_DIR="/tmp/opencv-ios-install"
_OCV_FLAGS_FILE="$OPENCV_INSTALL_DIR/.opencv_flags"

_OCV_FLAGS="-G Xcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_EIGEN=OFF -DENABLE_PRECOMPILED_HEADERS=OFF"

_NEED_BUILD=false
if [ ! -f "$OPENCV_INSTALL_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]; then
    _NEED_BUILD=true
elif [ ! -f "$_OCV_FLAGS_FILE" ] || [ "$_OCV_FLAGS" != "$(cat "$_OCV_FLAGS_FILE")" ]; then
    echo "OpenCV flags changed, discarding stale cache..."
    rm -rf "$OPENCV_INSTALL_DIR"
    _NEED_BUILD=true
fi

if $_NEED_BUILD; then
    echo "Building OpenCV $OPENCV_VERSION for iOS (arm64) from source..."
    if [ ! -d "/tmp/opencv-${OPENCV_VERSION}" ]; then
        curl -L -o "/tmp/opencv-${OPENCV_VERSION}.zip" \
            "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip"
        unzip -q "/tmp/opencv-${OPENCV_VERSION}.zip" -d /tmp/
    fi
    mkdir -p /tmp/opencv-ios-build && cd /tmp/opencv-ios-build
    # shellcheck disable=SC2086
    cmake "/tmp/opencv-${OPENCV_VERSION}" $_OCV_FLAGS
    cmake --build . --config Release -j"$(sysctl -n hw.ncpu)"
    cmake --install . --config Release
    echo "$_OCV_FLAGS" > "$_OCV_FLAGS_FILE"
    echo "OpenCV installed to $OPENCV_INSTALL_DIR"
else
    echo "OpenCV cached at $OPENCV_INSTALL_DIR"
fi

# 编译 inksi_image（此时仅含自己代码，不含 OpenCV）
echo "Building inksi_image for iOS arm64..."
mkdir -p "$SCRIPT_DIR/build-ios"
cd "$SCRIPT_DIR/build-ios"
cmake "$SCRIPT_DIR" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DOpenCV_DIR="$OPENCV_INSTALL_DIR/lib/cmake/opencv4" \
    -DINKSI_USE_OPENCV=ON
cmake --build . --config Release -j"$(sysctl -n hw.ncpu)"

# 定位产物（Xcode 输出可能因版本不同路径不同）
ARTIFACT=$(find . -name "libinksi_image.a" -type f | head -1)
if [ -z "$ARTIFACT" ]; then
    echo "Error: libinksi_image.a not found"
    exit 1
fi

# 合并 OpenCV 静态库到 inksi_image.a
echo "Merging OpenCV static libs..."
OPENCV_LIBS=$(find "$OPENCV_INSTALL_DIR" -name '*.a' | sort | tr '\n' ' ')
libtool -static -o merged.a "$ARTIFACT" $OPENCV_LIBS
cp merged.a "$ARTIFACT"
rm -f merged.a

cp "$ARTIFACT" "$SCRIPT_DIR/inksi_image-ios-arm64.a"
echo "Done: $SCRIPT_DIR/inksi_image-ios-arm64.a ($(du -h "$SCRIPT_DIR/inksi_image-ios-arm64.a" | cut -f1))"

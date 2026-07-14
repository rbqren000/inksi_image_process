#!/bin/bash
set -euo pipefail

# ============================================================
# iOS 编译脚本（仅 macOS）
# 产物: build-ios-arm64/libinksi_image.a → inksi_image-ios-arm64.a
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCV_VERSION="4.13.0"
OPENCV_ZIP="/tmp/opencv-${OPENCV_VERSION}-ios-framework.zip"
OPENCV_DIR="/tmp"

if [ "$(uname)" != "Darwin" ]; then
    echo "Error: iOS build requires macOS"
    exit 1
fi

# 下载 OpenCV iOS framework
if [ ! -d /tmp/opencv2.framework ]; then
    echo "Downloading OpenCV iOS framework..."
    curl -L -o "$OPENCV_ZIP" "https://github.com/opencv/opencv/releases/download/$OPENCV_VERSION/opencv-${OPENCV_VERSION}-ios-framework.zip"
    unzip -q "$OPENCV_ZIP" -d /tmp/
fi

# 编译
echo "Building inksi_image for iOS arm64..."
mkdir -p "$SCRIPT_DIR/build-ios-arm64"
cd "$SCRIPT_DIR/build-ios-arm64"
cmake "$SCRIPT_DIR" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DOpenCV_DIR=$OPENCV_DIR \
    -DINKSI_USE_OPENCV=ON
cmake --build . --config Release -j"$(sysctl -n hw.ncpu)"

# 定位产物（Xcode 输出可能因版本不同路径不同）
ARTIFACT=$(find . -name "libinksi_image.a" -type f | head -1)
if [ -z "$ARTIFACT" ]; then
    echo "Error: libinksi_image.a not found"
    exit 1
fi
cp "$ARTIFACT" "$SCRIPT_DIR/inksi_image-ios-arm64.a"
echo "Done: $SCRIPT_DIR/inksi_image-ios-arm64.a ($(du -h "$SCRIPT_DIR/inksi_image-ios-arm64.a" | cut -f1))"

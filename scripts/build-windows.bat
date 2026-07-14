@echo off
REM ============================================================
REM Windows 编译脚本（仅 Windows）
REM 从源码编译 OpenCV 4.13.0 + 静态链接到 inksi_image.dll
REM 依赖: CMake, Visual Studio 2022+, 7-Zip (加入 PATH)
REM 产物: inksi_image-windows-x86_64.dll（自包含 OpenCV）
REM ============================================================
setlocal enabledelayedexpansion

set OPENCV_VERSION=4.13.0
set SCRIPT_DIR=%~dp0..
set OPENCV_SRC=%TEMP%\opencv-%OPENCV_VERSION%
set OPENCV_INSTALL=%TEMP%\opencv-windows-install

REM 编译 OpenCV 源码头像（flags 变更时自动清理旧缓存）
set FLAGS_FILE=%OPENCV_INSTALL%\.opencv_flags
set OPENCV_FLAGS=-DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="%OPENCV_INSTALL%" -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_PYTHON=OFF -DBUILD_opencv_js=OFF -DBUILD_opencv_ts=OFF -DWITH_IPP=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_EIGEN=OFF -DENABLE_PRECOMPILED_HEADERS=OFF -DCMAKE_BUILD_TYPE=Release

set NEED_BUILD=1
if exist "%OPENCV_INSTALL%\OpenCVConfig.cmake" (
    if exist "%FLAGS_FILE%" (
        set /p CACHED_FLAGS=<"%FLAGS_FILE%"
        if "!CACHED_FLAGS!"=="%OPENCV_FLAGS%" (
            set NEED_BUILD=0
        ) else (
            echo OpenCV flags changed, discarding stale cache...
            rmdir /s /q "%OPENCV_INSTALL%"
        )
    ) else (
        echo OpenCV flags file missing, discarding stale cache...
        rmdir /s /q "%OPENCV_INSTALL%"
    )
)

if !NEED_BUILD! equ 1 (
    echo Building OpenCV %OPENCV_VERSION% for Windows from source...
    if not exist "%OPENCV_SRC%" (
        if not exist "%TEMP%\opencv-%OPENCV_VERSION%.zip" (
            echo Downloading...
            curl -L -o "%TEMP%\opencv-%OPENCV_VERSION%.zip" "https://github.com/opencv/opencv/archive/refs/tags/%OPENCV_VERSION%.zip"
        )
        echo Extracting...
        7z x "%TEMP%\opencv-%OPENCV_VERSION%.zip" -o"%TEMP%" -y >nul
        if !errorlevel! neq 0 (
            echo Error: extraction failed. Ensure 7-Zip is installed and in PATH.
            exit /b 1
        )
    )
    if not exist "%TEMP%\opencv-win-build" mkdir "%TEMP%\opencv-win-build"
    cd /d "%TEMP%\opencv-win-build"
    cmake "%OPENCV_SRC%" %OPENCV_FLAGS%
    if !errorlevel! neq 0 exit /b !errorlevel!
    cmake --build . --config Release -j
    if !errorlevel! neq 0 exit /b !errorlevel!
    cmake --install . --config Release
    echo %OPENCV_FLAGS%> "%FLAGS_FILE%"
    echo OpenCV installed to %OPENCV_INSTALL%
) else (
    echo OpenCV cached at %OPENCV_INSTALL%
)

REM 编译 inksi_image（静态链接 OpenCV → .dll 自包含）
echo Building inksi_image for Windows x86_64...
if not exist "%SCRIPT_DIR%\build-windows" mkdir "%SCRIPT_DIR%\build-windows"
cd /d "%SCRIPT_DIR%\build-windows"
cmake "%SCRIPT_DIR%" -DINKSI_USE_OPENCV=ON -DOpenCV_DIR="%OPENCV_INSTALL%" -DOpenCV_STATIC=ON
if !errorlevel! neq 0 exit /b !errorlevel!
cmake --build . --config Release -j
if !errorlevel! neq 0 exit /b !errorlevel!

copy /y Release\inksi_image.dll "%SCRIPT_DIR%\inksi_image-windows-x86_64.dll"
echo Done: %SCRIPT_DIR%\inksi_image-windows-x86_64.dll

@echo off
REM ============================================================
REM Windows 编译脚本（仅 Windows）
REM 依赖: CMake, Visual Studio 2022+, 7-Zip (加入 PATH)
REM 产物: build-windows\Release\inksi_image.dll → inksi_image-windows-x86_64.dll
REM ============================================================
setlocal enabledelayedexpansion

set OPENCV_VERSION=4.13.0
set SCRIPT_DIR=%~dp0..
set OPENCV_DIR=%TEMP%\opencv-windows

REM 下载 OpenCV Windows 预编译包（7z SFX，用 7z 解压）
if not exist "%OPENCV_DIR%\opencv\build\OpenCVConfig.cmake" (
    echo Downloading OpenCV %OPENCV_VERSION% Windows prebuilt...
    curl -L -o "%TEMP%\opencv-windows.exe" "https://github.com/opencv/opencv/releases/download/%OPENCV_VERSION%/opencv-%OPENCV_VERSION%-windows.exe"
    echo Extracting...
    7z x "%TEMP%\opencv-windows.exe" -o"%OPENCV_DIR%" -y >nul
    if !errorlevel! neq 0 (
        echo Error: extraction failed. Ensure 7-Zip is installed and in PATH.
        exit /b 1
    )
    echo OpenCV extracted to %OPENCV_DIR%
) else (
    echo OpenCV cached at %OPENCV_DIR%
)

REM 编译 inksi_image
echo Building inksi_image for Windows x86_64...
if not exist "%SCRIPT_DIR%\build-windows" mkdir "%SCRIPT_DIR%\build-windows"
cd /d "%SCRIPT_DIR%\build-windows"
cmake "%SCRIPT_DIR%" -DINKSI_USE_OPENCV=ON -DOpenCV_DIR="%OPENCV_DIR%\opencv\build"
if !errorlevel! neq 0 exit /b !errorlevel!
cmake --build . --config Release -j
if !errorlevel! neq 0 exit /b !errorlevel!

copy /y Release\inksi_image.dll "%SCRIPT_DIR%\inksi_image-windows-x86_64.dll"
echo Done: %SCRIPT_DIR%\inksi_image-windows-x86_64.dll

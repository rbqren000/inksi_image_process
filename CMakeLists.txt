cmake_minimum_required(VERSION 3.16)
project(inksi_image_process VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(INKSI_USE_OPENCV "Use OpenCV for image processing" ON)

if(INKSI_USE_OPENCV)
    if(IOS)
        # iOS: OpenCV 是 .framework 包，无 OpenCVConfig.cmake
        # OpenCV_DIR 应指向包含 opencv2.framework 的上级目录
        set(OpenCV_LIBS "${OpenCV_DIR}/opencv2.framework/opencv2")
        set(OpenCV_INCLUDE_DIRS "${OpenCV_DIR}/opencv2.framework/Headers")
        add_definitions(-DINKSI_USE_OPENCV)
        message(STATUS "OpenCV iOS framework at: ${OpenCV_DIR}/opencv2.framework")
    else()
        find_package(OpenCV REQUIRED)
        add_definitions(-DINKSI_USE_OPENCV)
        message(STATUS "OpenCV found: ${OpenCV_VERSION} at ${OpenCV_DIR}")
    endif()
endif()

set(SOURCES src/inksi_image_api.cpp)

if(ANDROID OR IOS)
    add_library(inksi_image STATIC ${SOURCES})
else()
    add_library(inksi_image SHARED ${SOURCES})
endif()

if(INKSI_USE_OPENCV)
    target_include_directories(inksi_image PRIVATE ${OpenCV_INCLUDE_DIRS})
    target_link_libraries(inksi_image PRIVATE ${OpenCV_LIBS})
endif()

install(TARGETS inksi_image
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)
install(FILES src/inksi_image_api.h DESTINATION include)

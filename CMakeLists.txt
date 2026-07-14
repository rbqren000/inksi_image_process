cmake_minimum_required(VERSION 3.16)
project(inksi_image_process VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(INKSI_USE_OPENCV "Use OpenCV for image processing" ON)

if(INKSI_USE_OPENCV)
    find_package(OpenCV REQUIRED)
    add_definitions(-DINKSI_USE_OPENCV)
    message(STATUS "OpenCV found: ${OpenCV_VERSION} at ${OpenCV_DIR}")
    message(STATUS "OpenCV libraries: ${OpenCV_LIBS}")
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

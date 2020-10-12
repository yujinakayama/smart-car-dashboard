
# (Automatically converted from project Makefile by convert_to_cmake.py.)

# The following lines of boilerplate have to be in your project's CMakeLists
# in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.5)

set(HOMEKIT_PATH ${CMAKE_CURRENT_LIST_DIR}/esp-homekit-sdk)
set(EXTRA_COMPONENT_DIRS ${HOMEKIT_PATH}/components ${HOMEKIT_PATH}/components/homekit ${HOMEKIT_PATH}/examples/common)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp32-wifi-accessory)

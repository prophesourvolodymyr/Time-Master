cmake_minimum_required(VERSION 3.20)
project(TimeMasterRouting LANGUAGES C CXX OBJCXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(TM_BUILD_TOOLS "Build macOS regional graph preparation tools" OFF)
set(ENABLE_HTTP OFF CACHE BOOL "" FORCE)
set(ENABLE_SERVICES OFF CACHE BOOL "" FORCE)
set(ENABLE_TOOLS ${TM_BUILD_TOOLS} CACHE BOOL "" FORCE)
set(ENABLE_DATA_TOOLS ${TM_BUILD_TOOLS} CACHE BOOL "" FORCE)
set(ENABLE_PYTHON_BINDINGS OFF CACHE BOOL "" FORCE)
set(ENABLE_TESTS OFF CACHE BOOL "" FORCE)
set(ENABLE_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(ENABLE_GEOTIFF OFF CACHE BOOL "" FORCE)
set(ENABLE_SINGLE_FILES_WERROR OFF CACHE BOOL "" FORCE)
if(NOT VALHALLA_SOURCE)
  message(FATAL_ERROR "Set VALHALLA_SOURCE to the pinned Valhalla 3.6.3 checkout")
endif()
find_package(fmt CONFIG REQUIRED)
add_subdirectory("${VALHALLA_SOURCE}" valhalla)
if(TM_BUILD_TOOLS)
  add_library(TMNativeRouting STATIC TMOfflineRouter.mm)
else()
  add_library(TMNativeRouting SHARED TMOfflineRouter.mm include/TMOfflineRouter.h)
  set_target_properties(TMNativeRouting PROPERTIES
    FRAMEWORK TRUE
    OUTPUT_NAME TimeMasterRouting
    MACOSX_FRAMEWORK_IDENTIFIER com.timemaster.routing
    PUBLIC_HEADER include/TMOfflineRouter.h
    INSTALL_NAME_DIR "@rpath"
    BUILD_WITH_INSTALL_NAME_DIR TRUE)
  target_link_options(TMNativeRouting PRIVATE "-Wl,-dead_strip" "-Wl,-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/exports.txt")
  add_custom_command(TARGET TMNativeRouting POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:TMNativeRouting>/Modules"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/framework.modulemap" "$<TARGET_BUNDLE_DIR:TMNativeRouting>/Modules/module.modulemap")
endif()
target_include_directories(TMNativeRouting PUBLIC include PRIVATE "${VALHALLA_SOURCE}/third_party/date/include")
target_link_libraries(TMNativeRouting PRIVATE valhalla "-framework Foundation")
target_compile_options(TMNativeRouting PRIVATE -fobjc-arc)
install(TARGETS TMNativeRouting ARCHIVE DESTINATION lib FRAMEWORK DESTINATION Frameworks)
install(FILES include/TMOfflineRouter.h include/module.modulemap DESTINATION include)

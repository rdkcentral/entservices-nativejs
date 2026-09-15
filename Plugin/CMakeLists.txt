set(PLUGIN_NAME NativeJS)
set(MODULE_NAME ${NAMESPACE}${PLUGIN_NAME})

option(NATIVEJS_HOST_BUILD "Build without the RDK JavaScriptCore SDK" OFF)

find_package(${NAMESPACE}Plugins REQUIRED)
find_package(${NAMESPACE}Definitions REQUIRED)

add_library(${MODULE_NAME} SHARED
	NativeJSPlugin.cpp
	NativeJSImplementation.cpp
        Module.cpp
)

set_target_properties(${MODULE_NAME} PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED YES)

target_include_directories(${MODULE_NAME} PRIVATE $ENV{PKG_CONFIG_SYSROOT_DIR}/usr/include/jsruntime ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../rdkNativeScript/include ${CMAKE_CURRENT_SOURCE_DIR}/../rdkNativeScript/include/jsc)

target_link_libraries(${MODULE_NAME} PRIVATE ${NAMESPACE}Plugins::${NAMESPACE}Plugins ${NAMESPACE}Definitions::${NAMESPACE}Definitions ${NAMESPACE}::${NAMESPACE}Helpers -L${CMAKE_INSTALL_PREFIX}/lib -L${CMAKE_CURRENT_SOURCE_DIR}/../../build/NativeJS -lJSRuntimeJSC)

if(NOT NATIVEJS_HOST_BUILD)
        target_link_libraries(${MODULE_NAME} PRIVATE -L$ENV{PKG_CONFIG_SYSROOT_DIR}/usr/lib/javascriptcore -lJavaScriptCore)
endif()

install(TARGETS ${MODULE_NAME}
        DESTINATION lib/${STORAGE_DIRECTORY}/plugins)

write_config(PLUGINS ${PLUGIN_NAME})

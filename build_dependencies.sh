#!/bin/bash
set -x
set -e
##############################
THUNDER_TOOLS_COMMIT_SHA="d5dd83c7c19c49c7f25c558c126500bd2d64f7a4"
THUNDER_COMMIT_SHA="2c0fcc5529e7da734be558ca6efa05d934dcce31"
GITHUB_WORKSPACE="${PWD}"
ls -la ${GITHUB_WORKSPACE}
cd ${GITHUB_WORKSPACE}

# # ############################# 
#1. Install Dependencies and packages

apt update
apt install -y libsqlite3-dev libcurl4-openssl-dev valgrind lcov clang libsystemd-dev libboost-all-dev libwebsocketpp-dev meson libcunit1 libcunit1-dev curl protobuf-compiler-grpc libgrpc-dev libgrpc++-dev libunwind-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
pip install jsonref

############################
# Build trevor-base64
if [ ! -d "trower-base64" ]; then
git clone https://github.com/xmidt-org/trower-base64.git
fi
cd trower-base64
meson setup --warnlevel 3 --werror build
ninja -C build
ninja -C build install
cd ..
###########################################
# Clone the required repositories


git clone --branch R4_4-RDK https://github.com/rdkcentral/ThunderTools.git
cd ThunderTools
git checkout $THUNDER_TOOLS_COMMIT_SHA
cd ..

git clone --branch R4_4-RDK https://github.com/rdkcentral/Thunder.git
cd Thunder
git checkout $THUNDER_COMMIT_SHA
cd ..

git clone --branch 4.2.0 https://github.com/rdkcentral/entservices-apis.git

git clone --branch develop https://github.com/rdkcentral/entservices-helpers.git

git clone --branch 2.0.0 https://github.com/rdkcentral/entservices-testframework.git

git clone --branch develop https://github.com/rdkcentral/rdkNativeScript.git

############################
# Build Thunder-Tools
echo "======================================================================================"
echo "buliding thunderTools"
cd ThunderTools
cd -


cmake -G Ninja -S ThunderTools -B build/ThunderTools \
    -DEXCEPTIONS_ENABLE=ON \
    -DCMAKE_INSTALL_PREFIX="$GITHUB_WORKSPACE/install/usr" \
    -DCMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \
    -DGENERIC_CMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \

cmake --build build/ThunderTools --target install


############################
# Build Thunder
echo "======================================================================================"
echo "buliding thunder"

cd Thunder
cd -

cmake -G Ninja -S Thunder -B build/Thunder \
    -DMESSAGING=ON \
    -DCMAKE_INSTALL_PREFIX="$GITHUB_WORKSPACE/install/usr" \
    -DCMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \
    -DGENERIC_CMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \
    -DBUILD_TYPE=Debug \
    -DBINDING=127.0.0.1 \
    -DPORT=55555 \
    -DEXCEPTIONS_ENABLE=ON \

cmake --build build/Thunder --target install


############################
# Build entservices-apis
echo "======================================================================================"
echo "buliding entservices-apis"
cd entservices-apis
rm -rf jsonrpc/DTV.json
cd ..

cmake -G Ninja -S entservices-apis  -B build/entservices-apis \
    -DEXCEPTIONS_ENABLE=ON \
    -DCMAKE_INSTALL_PREFIX="$GITHUB_WORKSPACE/install/usr" \
    -DCMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \

cmake --build build/entservices-apis --target install

############################
# Prepare compatibility headers required by entservices-helpers.
cd "$GITHUB_WORKSPACE/entservices-testframework/Tests"
mkdir -p headers/rdk/iarmbus
touch headers/secure_wrapper.h
touch headers/wpa_ctrl.h
touch headers/rdk_logger_milestone.h
touch headers/iarm.h
touch headers/tr181api.h
touch headers/rdk/iarmbus/libIARM.h
touch headers/rdk/iarmbus/libIBus.h
cd "$GITHUB_WORKSPACE"

############################
# Build entservices-helpers
echo "======================================================================================"
echo "building entservices-helpers"
cmake -G Ninja -S entservices-helpers -B build/entservices-helpers \
    -DEXCEPTIONS_ENABLE=ON \
    -DCMAKE_INSTALL_PREFIX="$GITHUB_WORKSPACE/install/usr" \
    -DCMAKE_MODULE_PATH="$GITHUB_WORKSPACE/install/tools/cmake" \
    -DUSE_THUNDER_R4=ON \
    -DHIDE_NON_EXTERNAL_SYMBOLS=OFF \
    -DPLUGIN_HELPERS=ON \
    "-DCMAKE_CXX_FLAGS=-I$GITHUB_WORKSPACE/entservices-testframework/Tests/mocks -I$GITHUB_WORKSPACE/entservices-testframework/Tests/headers -I$GITHUB_WORKSPACE/entservices-testframework/Tests/headers/rdk/iarmbus -include $GITHUB_WORKSPACE/entservices-testframework/Tests/mocks/Iarm.h -include $GITHUB_WORKSPACE/entservices-testframework/Tests/mocks/tr181api.h" \

cmake --build build/entservices-helpers --target install

############################
# Build the NativeJS API shim used by the native Coverity build. The complete
# runtime requires the RDK sysroot (custom JavaScriptCore, pxCore, and rtCore).
echo "======================================================================================"
echo "building rdkNativeScript API shim"
mkdir -p build/rdkNativeScript
cat > build/rdkNativeScript/NativeJSRuntimeStub.cpp <<'EOF'
#include "ModuleSettings.h"
#include "NativeJSRenderer.h"

std::string JsRuntime::DEFAULT_USER_AGENT;

ModuleSettings::ModuleSettings()
        : enableHttp(false), enableXHR(false), enableWebSocket(false),
            enableWebSocketEnhanced(false), enableFetch(false), enableJSDOM(false),
            enableWindow(false), enablePlayer(false), enableMiniJSDOM(false) {}
ModuleSettings::ModuleSettings(ModuleSettings& settings)
        : enableHttp(settings.enableHttp), enableXHR(settings.enableXHR),
            enableWebSocket(settings.enableWebSocket),
            enableWebSocketEnhanced(settings.enableWebSocketEnhanced),
            enableFetch(settings.enableFetch), enableJSDOM(settings.enableJSDOM),
            enableWindow(settings.enableWindow), enablePlayer(settings.enablePlayer),
            enableMiniJSDOM(settings.enableMiniJSDOM) {}
void ModuleSettings::fromString(std::string& options) {
        enableHttp = options.find("http") != std::string::npos;
        enableXHR = options.find("xhr") != std::string::npos;
        enableWebSocket = options.find("ws") != std::string::npos;
        enableWebSocketEnhanced = options.find("wsenhanced") != std::string::npos;
        enableFetch = options.find("fetch") != std::string::npos;
        enableMiniJSDOM = options.find("minijsdom") != std::string::npos;
        enableJSDOM = !enableMiniJSDOM && options.find("jsdom") != std::string::npos;
        enableWindow = options.find("window") != std::string::npos;
        enablePlayer = options.find("player") != std::string::npos;
}

namespace JsRuntime {
NativeJSRenderer::NativeJSRenderer(std::string) {}
NativeJSRenderer::~NativeJSRenderer() = default;
bool NativeJSRenderer::terminate() { return true; }
void NativeJSRenderer::run() {}
bool NativeJSRenderer::runApplication(uint32_t, std::string) { return true; }
bool NativeJSRenderer::runJavaScript(uint32_t, std::string) { return true; }
uint32_t NativeJSRenderer::createApplication(ModuleSettings&, std::string) { return 1; }
bool NativeJSRenderer::terminateApplication(uint32_t) { return true; }
std::list<ApplicationDetails> NativeJSRenderer::getApplications() { return {}; }
}
EOF

c++ -std=c++17 -fPIC -shared \
    -IrdkNativeScript/include \
    build/rdkNativeScript/NativeJSRuntimeStub.cpp \
    -o "$GITHUB_WORKSPACE/install/usr/lib/libJSRuntimeJSC.so"



cp -r /usr/include/gstreamer-1.0/gst /usr/include/glib-2.0/* /usr/lib/x86_64-linux-gnu/glib-2.0/include/* /usr/local/include/trower-base64/base64.h .

ls -la ${GITHUB_WORKSPACE}

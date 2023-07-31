#!/bin/sh

#获取当前脚本所在目录
SCRIPTROOT="$( cd "$( dirname "$0"  )" && pwd  )"
#回到项目根目录
cd $( pwd )/../../../
#项目根目录
SRCROOT=$( pwd )

WORKSPACE_NAME="ToDesk"
PROJECT_DIR="${SRCROOT}/build_mac"
PROJECT_NAME="ToDesk_SDK_Slave"
TARGET_NAME=${PROJECT_NAME}
BUILD_DIR="${SRCROOT}/bin/mac/Release/sdkslave/${TARGET_NAME}.framework"
UNIVERSAL_OUTPUT_FOLDER="${SRCROOT}/bin/mac/SDK/slave"
OUTPUT_X86_64_DIR="${UNIVERSAL_OUTPUT_FOLDER}/x86_64"
OUTPUT_ARM64_DIR="${UNIVERSAL_OUTPUT_FOLDER}/arm64"
OUTPUT_DIR="${UNIVERSAL_OUTPUT_FOLDER}/${TARGET_NAME}.framework"

rm -rf "$SRCROOT/bin/mac/Release"
 
#创建输出目录，并删除之前的framework文件夹
mkdir -p ${UNIVERSAL_OUTPUT_FOLDER}
if [ -d ${OUTPUT_DIR} ]; then
    rm -rf ${OUTPUT_DIR}
fi
mkdir -p ${OUTPUT_DIR}

if [ -d ${OUTPUT_X86_64_DIR} ]; then
    rm -rf ${OUTPUT_X86_64_DIR}
fi
mkdir -p ${OUTPUT_X86_64_DIR}

if [ -d ${OUTPUT_ARM64_DIR} ]; then
    rm -rf ${OUTPUT_ARM64_DIR}
fi
mkdir -p ${OUTPUT_ARM64_DIR}

#加载资源和协议
sh ./init_mac.sh

#分别编译不同架构的Framework
########################################################################
#加载x86_64 conan
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

cd ${PROJECT_DIR}
xcodebuild -workspace ${WORKSPACE_NAME}.xcworkspace \
            -scheme ${PROJECT_NAME} \
            ONLY_ACTIVE_ARCH=NO \
            -configuration Release \
            -arch x86_64 \
            -sdk macosx \
            clean build
           

#拷贝framework到univer目录
cp -R "${BUILD_DIR}" ${OUTPUT_X86_64_DIR}
if [ ! -d "${OUTPUT_X86_64_DIR}/${TARGET_NAME}.framework" ]; then
    echo "路径不存在:${OUTPUT_X86_64_DIR}/${TARGET_NAME}.framework"
    exit 1
fi

#加载arm64 conan
cd ..
sh ./conaninstall_mac.sh 
sh ./gen_xcode.sh 
cd ${PROJECT_DIR}
xcodebuild -workspace ${WORKSPACE_NAME}.xcworkspace \
           -scheme ${PROJECT_NAME} \
           ONLY_ACTIVE_ARCH=NO \
           -configuration Release \
           -arch arm64 \
           -sdk macosx \
           clean build
           
 
#拷贝framework到univer目录
cp -R ${BUILD_DIR} ${OUTPUT_ARM64_DIR}
cp -R ${BUILD_DIR} ${UNIVERSAL_OUTPUT_FOLDER}

########################################################################

if [ ! -d ${OUTPUT_DIR} ]; then
    echo "路径不存在: ${OUTPUT_DIR}"
    exit 1
fi

#合并framework，输出最终的framework
lipo -create ${OUTPUT_X86_64_DIR}/${TARGET_NAME}.framework/${TARGET_NAME} \
             ${OUTPUT_ARM64_DIR}/${TARGET_NAME}.framework/${TARGET_NAME} \
     -output ${OUTPUT_DIR}/Versions/A/${TARGET_NAME}
     #-output ${OUTPUT_DIR}/${TARGET_NAME}
 
#判断build文件夹是否存在，存在则删除
if [ -d ${OUTPUT_X86_64_DIR} ]; then
    rm -rf ${OUTPUT_X86_64_DIR}
fi

if [ -d ${OUTPUT_ARM64_DIR} ]; then
    rm -rf ${OUTPUT_ARM64_DIR}
fi
 
#打开合并后的文件夹
open "${UNIVERSAL_OUTPUT_FOLDER}"
 

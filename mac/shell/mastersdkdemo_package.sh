#!/bin/sh

#eg. sh mastersdkdemo_package.sh 1.0.0 1

#版本
archive_version=""
archive_build=""
dynamic_ui=false
if [ $# != 2 ] ; then
    echo "\033[31;1m"
    echo "参数数量错误"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
else
    archive_version=$1
    archive_build=$2
fi


######################## sdk demo 工程信息 ########################
#获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
#回到项目根目录
cd $( pwd )/../../../
#项目根目录
project_root_dir=$( pwd )

workspace_name="ToDesk"
#工程名称
project_name="ToDesk"
project_output_directory="SDKDemo/master"
#项目BundleID
bundle_id="com.zuler.MasterSDKDemo"
#指定项目的scheme名称（也就是工程的target名称），必填
target_name="MasterSDKDemoMac"
#App名称
master_app_name="MasterSDKDemoMac"
#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/${project_output_directory}"

#dSYM路径
master_dsym_source_path="$project_root_dir/bin/mac/Release/mastersdkdemo"
dsym_dest_path="$project_root_dir/bin/mac/${project_output_directory}"

#dSYM文件名
master_client_dsym_name="${master_app_name}.app.dSYM"
export_method="DeveloperID"

export SCRIPT_BUILD_CMD=-DSCRIPT_BUILD=ON

echo "--------------------编译项目(双架构编译两次) Start--------------------"
rm -rf "$export_path/arm64"
rm -rf "$export_path/x86_64"

#加载资源和协议
sh ./init_mac.sh

#加载x86_64 conan
rm -rf "$project_root_dir/bin/mac/Release"
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

#X86架构编译
sh ${script_dir}/sdkdemo_build.sh ${archive_version} ${archive_build} x86_64 \
    ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${master_app_name} ${dynamic_ui}

if [[ ! -e "$export_path/x86_64/${master_app_name}.app" ]]; then
    echo "\033[31;1m"
    echo "app: $export_path/x86_64/${master_app_name}.app 不存在！！！ "
    echo "\033[0m"
    exit 1
fi

#Master X86 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/x86_64/$master_client_dsym_name"


#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh

#ARM架构编译
sh ${script_dir}/sdkdemo_build.sh ${archive_version} ${archive_build} arm64 \
    ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${master_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${master_app_name} 编译失败😢 😢 😢"
    exit 1
fi
#Master ARM64 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/arm64/$master_client_dsym_name"


######################## 合并架构 ########################
master_client_path="${master_app_name}.app/Contents/MacOS/${master_app_name}"
master_sdk_path="${master_app_name}.app/Contents/Frameworks/ToDesk_SDK_Master"

cd ${export_path}

master_build_success=0
if [ -f "./x86_64/${master_client_path}" -a -f "./arm64/${master_client_path}" ] ; then
    master_build_success=1
fi



if [ $master_build_success == 1 ]; then
    echo "\033[32;1m编译成功😺 😺 😺\033[0m"
else
    echo "\033[31;1m"
    echo "编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

echo "合并架构"
rm -rf ./${master_app_name}.app
cp -R ./arm64/${master_app_name}.app ./${master_app_name}.app
lipo -create ./arm64/${master_client_path} ./x86_64/${master_client_path} \
    -output ./${master_client_path}


#APP包重新签名
master_entitlements_path="$project_root_dir/MasterSDKDemoMac/MasterSDKDemoMac.entitlements"
codesign --force \
        --deep \
        --entitlements ${master_entitlements_path} \
        --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${master_app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"



echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#Master dSYM架构合并
cp -R "./arm64/$master_client_dsym_name" "./$master_client_dsym_name"
lipo -create "./arm64/$master_client_dsym_name/$dsym_prefix/MasterSDKDemoMac" "./x86_64/$master_client_dsym_name/$dsym_prefix/MasterSDKDemoMac" \
    -output "./$master_client_dsym_name/$dsym_prefix/MasterSDKDemoMac"
tar -zcf "./${master_app_name}_${archive_build}_dSYM.tar.gz" "./$master_client_dsym_name" 


echo "--------------------dSYM架构合并与压缩 End--------------------\n"

echo "dmg package.."
#dmg资源路径
dmg_resources_path="$script_dir/../packages/master_dmg/"
sh ${script_dir}/dmg_sdkdemo_sign.sh ${archive_version} ${archive_build} ${project_name} ${master_app_name} ${export_path} ${dmg_resources_path} ${bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${master_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi
echo "End"

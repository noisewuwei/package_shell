#!/bin/sh

#eg. sh slavesdkdemo_package.sh 1.0.0 1

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
project_output_directory="SDKDemo/slave"
#项目BundleID
bundle_id="com.zuler.SlaveSDKDemo"
#指定项目的scheme名称（也就是工程的target名称），必填
target_name="SlaveSDKDemoMac"
#App名称
app_name="SlaveSDKDemoMac"
#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/${project_output_directory}"

#dSYM路径
dsym_source_path="$project_root_dir/bin/mac/Release/slavesdkdemo"
dsym_dest_path="$project_root_dir/bin/mac/${project_output_directory}"

#dSYM文件名
dsym_name="${app_name}.app.dSYM"
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
    ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${app_name} ${dynamic_ui}

if [[ ! -e "$export_path/x86_64/${app_name}.app" ]]; then
    echo "\033[31;1m"
    echo "app: $export_path/x86_64/${app_name}.app 不存在！！！ "
    echo "\033[0m"
    exit 1
fi

#slave X86 dSYM
cp -R "$dsym_source_path/$dsym_name" "$dsym_dest_path/x86_64/$dsym_name"


#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh

#ARM架构编译
sh ${script_dir}/sdkdemo_build.sh ${archive_version} ${archive_build} arm64 \
    ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${app_name} 编译失败😢 😢 😢"
    exit 1
fi
#slave ARM64 dSYM
cp -R "$dsym_source_path/$dsym_name" "$dsym_dest_path/arm64/$dsym_name"


######################## 合并架构 ########################
excutable_path="${app_name}.app/Contents/MacOS/${app_name}"

cd ${export_path}

build_success=0
if [ -f "./x86_64/${excutable_path}" -a -f "./arm64/${excutable_path}" ] ; then
    build_success=1
fi



if [ $build_success == 1 ]; then
    echo "\033[32;1m编译成功😺 😺 😺\033[0m"
else
    echo "\033[31;1m"
    echo "编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

echo "合并架构"
rm -rf ./${app_name}.app
cp -R ./arm64/${app_name}.app ./${app_name}.app
lipo -create "./arm64/${excutable_path}" "./x86_64/${excutable_path}" \
     -output ./${excutable_path}


#APP包重新签名
entitlements_path="$project_root_dir/${target_name}/${target_name}.entitlements"
codesign --force \
        --deep \
        --entitlements ${entitlements_path} \
        --options=runtime \
        -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"



echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#slave dSYM架构合并
cp -R "./arm64/$dsym_name" "./$dsym_name"
lipo -create "./arm64/$dsym_name/$dsym_prefix/${target_name}" "./x86_64/$dsym_name/$dsym_prefix/${target_name}" \
    -output "./$dsym_name/$dsym_prefix/${target_name}"
tar -zcf "./${app_name}_${archive_build}_dSYM.tar.gz" "./$dsym_name" 


echo "--------------------dSYM架构合并与压缩 End--------------------\n"

echo "dmg package.."
#dmg资源路径
dmg_resources_path="$script_dir/../packages/slave_dmg/"
sh ${script_dir}/dmg_sdkdemo_sign.sh ${archive_version} ${archive_build} ${project_name} ${app_name} ${export_path} ${dmg_resources_path} ${bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

echo "End"


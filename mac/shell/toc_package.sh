#!/bin/sh

#版本
archive_version=""
archive_build=""
dynamic_ui="" #动态加载UI
if [ $# != 3 ] ; then
    echo "\033[31;1m"
    echo "参数数量错误"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
else
    archive_version=$1
    archive_build=$2
    dynamic_ui=$3
fi

#获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"

######################## ToDesk 工程信息 ######################## 
#工程名称
project_name="ToDesk"
project_output_directory="ToC"
#项目BundleID
target_bundle_id="com.youqu.todesk.mac"
#指定项目的scheme名称（也就是工程的target名称），必填
target_name="ToDesk_Client"
#App名称
app_name="ToDesk"

#回到项目根目录
cd $( pwd )/../../../ 
#项目根目录
project_root_dir=$( pwd )
#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
#pkg工程地址
pkgproj_path="$script_dir/../packages/ToC/${project_name}.pkgproj"
#pkg输出地址
pkg_export_path="${export_path}/${app_name}.pkg"
#dSYM路径
dsym_source_path="$project_root_dir/bin/mac/Release/todesk"
dsym_dest_path="$project_root_dir/bin/mac/ToC"
#dSYM文件名
client_dsym_name="ToDesk.app.dSYM"
service_dsym_name="ToDesk_Service.dSYM"
session_dsym_name="ToDesk_Session.dSYM"

echo "--------------------编译项目(双架构编译两次) Start--------------------"
rm -rf "$export_path/arm64"
rm -rf "$export_path/x86_64"

#加载资源和协议
sh ./init_mac.sh

#加载x86_64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${app_name} 编译失败😢 😢 😢"
    exit 1
fi

cp -R "$dsym_source_path/$client_dsym_name" "$dsym_dest_path/x86_64/$client_dsym_name"
cp -R "$dsym_source_path/$service_dsym_name" "$dsym_dest_path/x86_64/$service_dsym_name"
cp -R "$dsym_source_path/$session_dsym_name" "$dsym_dest_path/x86_64/$session_dsym_name"

echo "\033[32;1mX86_64编译完成 😺 😺 😺\033[0m"

#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${target_name} ${app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${app_name} 编译失败😢 😢 😢"
    exit 1
fi

cp -R "$dsym_source_path/$client_dsym_name" "$dsym_dest_path/arm64/$client_dsym_name"
cp -R "$dsym_source_path/$service_dsym_name" "$dsym_dest_path/arm64/$service_dsym_name"
cp -R "$dsym_source_path/$session_dsym_name" "$dsym_dest_path/arm64/$session_dsym_name"

######################## 合并架构 ########################
cd ${export_path}
client_path="${app_name}.app/Contents/MacOS/${app_name}"
service_path="${app_name}.app/Contents/MacOS/ToDesk_Service"
session_path="${app_name}.app/Contents/MacOS/ToDesk_Session"


if [ -f "./x86_64/${client_path}" -a -f "./arm64/${client_path}" ] ; then
    echo "\033[32;1m"
    echo "双架构编译成功"
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "双架构编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

#应用/服务双架构合并
rm -rf ./${app_name}.app
cp -R ./arm64/${app_name}.app ./${app_name}.app
lipo -create "./arm64/${client_path}" "./x86_64/${client_path}" -output "./${client_path}"
lipo -create "./arm64/${service_path}" "./x86_64/${service_path}" -output "./${service_path}"
lipo -create "./arm64/${session_path}" "./x86_64/${session_path}" -output "./${session_path}"

#APP包重新签名
entitlements_path="$project_root_dir/ToDesk_Client/Mac/Resources/ToDesk_Client.entitlements"
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"




echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#dSYM双架构合并
cp -R "./arm64/$client_dsym_name" "./$client_dsym_name"
lipo -create "./arm64/$client_dsym_name/$dsym_prefix/ToDesk" "./x86_64/$client_dsym_name/$dsym_prefix/ToDesk" -output "./$client_dsym_name/$dsym_prefix/ToDesk"

cp -R "./arm64/$service_dsym_name" "./$service_dsym_name"
lipo -create "./arm64/$service_dsym_name/$dsym_prefix/ToDesk_Service" "./x86_64/$service_dsym_name/$dsym_prefix/ToDesk_Service" -output "./$service_dsym_name/$dsym_prefix/ToDesk_Service"

cp -R "./arm64/$session_dsym_name" "./$session_dsym_name"
lipo -create "./arm64/$session_dsym_name/$dsym_prefix/ToDesk_Session" "./x86_64/$session_dsym_name/$dsym_prefix/ToDesk_Session" -output "./$session_dsym_name/$dsym_prefix/ToDesk_Session"

tar -zcf "./${app_name}_${archive_build}_dSYM.tar.gz" "./$client_dsym_name" "./$service_dsym_name" "./$session_dsym_name"
echo "--------------------dSYM架构合并与压缩 End--------------------\n"



sh ${script_dir}/pkg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${app_name} ${export_path} ${pkgproj_path} ${target_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi



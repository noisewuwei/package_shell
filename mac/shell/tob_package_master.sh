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


######################## ToDesk 工程信息 ########################
#获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
#回到项目根目录
cd $( pwd )/../../../
#项目根目录
project_root_dir=$( pwd )

#工程名称
project_name="ToDesk"
project_output_directory="ToB"
#项目BundleID
master_bundle_id="com.todesk.business.client"
#指定项目的scheme名称（也就是工程的target名称），必填
master_target_name="ToDesk_Client_Master"
#App名称
master_app_name="ToDesk_Client_Master"


#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
#pkg工程地址
master_pkgproj_path="$script_dir/../packages/Master/${project_name}.pkgproj"
#pkg输出地址
master_pkg_export_path="${export_path}/${master_app_name}.pkg"
#dSYM路径
master_dsym_source_path="$project_root_dir/bin/mac/Release/master"
dsym_dest_path="$project_root_dir/bin/mac/ToB"
#dSYM文件名
master_client_dsym_name="ToDesk_Client_Master.app.dSYM"
master_service_dsym_name="ToDesk_Service_Master.dSYM"

echo "--------------------编译项目(双架构编译两次) Start--------------------"
rm -rf "$export_path/arm64"
rm -rf "$export_path/x86_64"

#加载资源和协议
sh ./init_mac.sh

#加载x86_64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

#Master X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${master_target_name} ${master_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${master_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Master X86 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/x86_64/$master_client_dsym_name"
cp -R "$master_dsym_source_path/$master_service_dsym_name" "$dsym_dest_path/x86_64/$master_service_dsym_name"
echo "\033[32;1mX86编译完成 😺 😺 😺\033[0m"






#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh

#Master ARM架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${master_target_name} ${master_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${master_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Master ARM64 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/arm64/$master_client_dsym_name"
cp -R "$master_dsym_source_path/$master_service_dsym_name" "$dsym_dest_path/arm64/$master_service_dsym_name"
echo "\033[32;1mARM64编译完成 😺 😺 😺\033[0m"


######################## 合并架构 ########################
master_client_path="${master_app_name}.app/Contents/MacOS/${master_app_name}"
master_service_path="${master_app_name}.app/Contents/MacOS/ToDesk_Service_Master"

cd ${export_path}

master_build_success=0
if [ -f "./x86_64/${master_client_path}" -a -f "./arm64/${master_client_path}" ] ; then
    master_build_success=1
fi


if [ $master_build_success == 1 ]; then
    echo "\033[32;1m仅Master编译成功\033[0m"
else
    echo "\033[31;1m"
    echo "Master编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

rm -rf ./${master_app_name}.app
cp -R ./arm64/${master_app_name}.app ./${master_app_name}.app
lipo -create ./arm64/${master_client_path} ./x86_64/${master_client_path} -output ./${master_client_path}
lipo -create ./arm64/${master_service_path} ./x86_64/${master_service_path} -output ./${master_service_path}


#APP包重新签名
entitlements_path="$project_root_dir/ToDesk_Client/Mac/Resources/ToDesk_Client.entitlements"
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${master_app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"



echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#Master dSYM架构合并
cp -R "./arm64/$master_client_dsym_name" "./$master_client_dsym_name"
lipo -create "./arm64/$master_client_dsym_name/$dsym_prefix/ToDesk_Client_Master" "./x86_64/$master_client_dsym_name/$dsym_prefix/ToDesk_Client_Master" -output "./$master_client_dsym_name/$dsym_prefix/ToDesk_Client_Master"
cp -R "./arm64/$master_service_dsym_name" "./$master_service_dsym_name"
lipo -create "./arm64/$master_service_dsym_name/$dsym_prefix/ToDesk_Service_Master" "./x86_64/$master_service_dsym_name/$dsym_prefix/ToDesk_Service_Master" -output "./$master_service_dsym_name/$dsym_prefix/ToDesk_Service_Master"
tar -zcf "./${master_app_name}_${archive_build}_dSYM.tar.gz" "./$master_client_dsym_name" "./$master_service_dsym_name"
echo "--------------------dSYM架构合并与压缩 End--------------------\n"




sh ${script_dir}/pkg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${master_app_name} ${export_path} ${master_pkgproj_path} ${master_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${master_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

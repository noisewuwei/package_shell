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
sos_bundle_id="com.todesk.business.sos"
#指定项目的scheme名称（也就是工程的target名称），必填
sos_target_name="ToDesk_SOS"
#App名称
sos_app_name="ToDesk_SOS"


#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
#dmg资源路径
sos_pkgproj_path="$script_dir/../packages/SOS/"
#pkg输出地址
slave_pkg_export_path="${export_path}/${sos_app_name}.pkg"
#dSYM路径
sos_dsym_source_path="$project_root_dir/bin/mac/Release/sos"
dsym_dest_path="$project_root_dir/bin/mac/ToB"
#dSYM文件名
sos_client_dsym_name="ToDesk_SOS.app.dSYM"
sos_service_dsym_name="ToDesk_Service_SOS.dSYM"

echo "--------------------编译项目(双架构编译两次) Start--------------------"
rm -rf "$export_path/arm64"
rm -rf "$export_path/x86_64"

#加载资源和协议
sh ./init_mac.sh

#加载x86_64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

#SOS X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${sos_target_name} ${sos_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${sos_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#SOS X86 dSYM
cp -R "$sos_dsym_source_path/$sos_client_dsym_name" "$dsym_dest_path/x86_64/$sos_client_dsym_name"
cp -R "$sos_dsym_source_path/$sos_service_dsym_name" "$dsym_dest_path/x86_64/$sos_service_dsym_name"
echo "\033[32;1mX86编译完成 😺 😺 😺\033[0m"






#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh

#SOS ARM架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${sos_target_name} ${sos_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${sos_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#SOS ARM64 dSYM
cp -R "$sos_dsym_source_path/$sos_client_dsym_name" "$dsym_dest_path/arm64/$sos_client_dsym_name"
cp -R "$sos_dsym_source_path/$sos_service_dsym_name" "$dsym_dest_path/arm64/$sos_service_dsym_name"
echo "\033[32;1mARM64编译完成 😺 😺 😺\033[0m"


######################## 合并架构 ########################
sos_client_path="${sos_app_name}.app/Contents/MacOS/${sos_app_name}"
sos_service_path="${sos_app_name}.app/Contents/MacOS/ToDesk_Service_SOS"

cd ${export_path}

slave_build_success=0
if [ -f "./x86_64/${sos_client_path}" -a -f "./arm64/${sos_client_path}" ] ; then
    slave_build_success=1
fi


if [ $slave_build_success == 1 ]; then
    echo "\033[32;1m仅Slave编译成功\033[0m"
else
    echo "\033[31;1m"
    echo "SOS编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

rm -rf ./${sos_app_name}.app
cp -R ./arm64/${sos_app_name}.app ./${sos_app_name}.app
lipo -create ./arm64/${sos_client_path} ./x86_64/${sos_client_path} -output ./${sos_client_path}
lipo -create ./arm64/${sos_service_path} ./x86_64/${sos_service_path} -output ./${sos_service_path}

#APP包重新签名
entitlements_path="$project_root_dir/ToDesk_Client/Mac/Resources/ToDesk_Client.entitlements"
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${sos_app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"


echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#SOS dSYM架构合并
cp -R "./arm64/$sos_client_dsym_name" "./$sos_client_dsym_name"
lipo -create "./arm64/$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS" "./x86_64/$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS" -output "./$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS"
cp -R "./arm64/$sos_service_dsym_name" "./$sos_service_dsym_name"
lipo -create "./arm64/$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS" "./x86_64/$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS" -output "./$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS"
tar -zcf "./${sos_app_name}_${archive_build}_dSYM.tar.gz" "./$sos_client_dsym_name" "./$sos_service_dsym_name"
echo "--------------------dSYM架构合并与压缩 End--------------------\n"



sh ${script_dir}/dmg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${sos_app_name} ${export_path} ${sos_pkgproj_path} ${sos_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${sos_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

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
slave_bundle_id="com.todesk.business.host"
#指定项目的scheme名称（也就是工程的target名称），必填
slave_target_name="ToDesk_Client_Slave"
#App名称
slave_app_name="ToDesk_Client_Slave"


#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
#pkg工程地址
slave_pkgproj_path="$script_dir/../packages/Slave/${project_name}.pkgproj"
#pkg输出地址
slave_pkg_export_path="${export_path}/${slave_app_name}.pkg"
#dSYM路径
slave_dsym_source_path="$project_root_dir/bin/mac/Release/slave"
dsym_dest_path="$project_root_dir/bin/mac/ToB"
#dSYM文件名
slave_client_dsym_name="ToDesk_Client_Slave.app.dSYM"
slave_service_dsym_name="ToDesk_Host_Service.dSYM"

echo "--------------------编译项目(双架构编译两次) Start--------------------"
 rm -rf "$export_path/arm64"
 rm -rf "$export_path/x86_64"

#加载资源和协议
sh ./init_mac.sh

#加载x86_64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh -x86
sh ./gen_xcode.sh -x86

#Slave X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${slave_target_name} ${slave_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${slave_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Slave X86 dSYM
cp -R "$slave_dsym_source_path/$slave_client_dsym_name" "$dsym_dest_path/x86_64/$slave_client_dsym_name"
cp -R "$slave_dsym_source_path/$slave_service_dsym_name" "$dsym_dest_path/x86_64/$slave_service_dsym_name"
echo "\033[32;1mX86编译完成 😺 😺 😺\033[0m"






#加载arm64 conan
rm -rf "$project_root_dir/bin/mac/Release/"
sh ./conaninstall_mac.sh
sh ./gen_xcode.sh

#Slave ARM架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${slave_target_name} ${slave_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${slave_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Slave ARM64 dSYM
cp -R "$slave_dsym_source_path/$slave_client_dsym_name" "$dsym_dest_path/arm64/$slave_client_dsym_name"
cp -R "$slave_dsym_source_path/$slave_service_dsym_name" "$dsym_dest_path/arm64/$slave_service_dsym_name"
echo "\033[32;1mARM64编译完成 😺 😺 😺\033[0m"


######################## 合并架构 ########################
slave_client_path="${slave_app_name}.app/Contents/MacOS/${slave_app_name}"
slave_service_path="${slave_app_name}.app/Contents/MacOS/ToDesk_Host_Service"
#slave_session_path="${slave_app_name}.app/Contents/Helpers"

cd ${export_path}

slave_build_success=0
if [ -f "./x86_64/${slave_client_path}" -a -f "./arm64/${slave_client_path}" ] ; then
    slave_build_success=1
fi


if [ $slave_build_success == 1 ]; then
    echo "\033[32;1m仅Slave编译成功\033[0m"
else
    echo "\033[31;1m"
    echo "Slave编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

rm -rf ./${slave_app_name}.app
cp -R ./arm64/${slave_app_name}.app ./${slave_app_name}.app
lipo -create ./arm64/${slave_client_path} ./x86_64/${slave_client_path} -output ./${slave_client_path}
lipo -create ./arm64/${slave_service_path} ./x86_64/${slave_service_path} -output ./${slave_service_path}
#mkdir ${slave_session_path}
#cp -R ./${slave_service_path} ./${slave_session_path}

#APP包重新签名
entitlements_path="$project_root_dir/ToDesk_Client/Mac/Resources/ToDesk_Client.entitlements"
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${slave_app_name}.app
echo "--------------------编译项目(双架构编译两次) End--------------------\n"


echo "--------------------dSYM架构合并与压缩 Start--------------------"
cd ${export_path}
dsym_prefix="Contents/Resources/DWARF"

#Slave dSYM架构合并
cp -R "./arm64/$slave_client_dsym_name" "./$slave_client_dsym_name"
lipo -create "./arm64/$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave" "./x86_64/$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave" -output "./$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave"
cp -R "./arm64/$slave_service_dsym_name" "./$slave_service_dsym_name"
lipo -create "./arm64/$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service" "./x86_64/$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service" -output "./$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service"
tar -zcf "./${slave_app_name}_${archive_build}_dSYM.tar.gz" "./$slave_client_dsym_name" "./$slave_service_dsym_name"
echo "--------------------dSYM架构合并与压缩 End--------------------\n"



sh ${script_dir}/pkg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${slave_app_name} ${export_path} ${slave_pkgproj_path} ${slave_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${slave_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

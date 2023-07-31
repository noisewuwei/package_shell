#!/bin/sh

#版本
archive_version=""
archive_build=""
archive_client=""
dynamic_ui="" #动态加载UI
if [ $# != 4 ] ; then
    echo "\033[31;1m"
    echo "参数数量错误"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
else
    archive_version=$1
    archive_build=$2
    archive_client=$3
    dynamic_ui=$4
fi

echo "编译${archive_client}😺 😺 😺"
if [[ "$archive_client" = "master" ]]; then
    sh ./tob_package_master.sh $archive_version $archive_build $dynamic_ui
    exit 0
elif [[ "$archive_client" = "slave" ]]; then
    sh ./tob_package_slave.sh $archive_version $archive_build $dynamic_ui
    exit 0
elif [[ "$archive_client" = "sos" ]]; then
    sh ./tob_package_sos.sh $archive_version $archive_build $dynamic_ui
    exit 0
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
slave_bundle_id="com.todesk.business.host"
sos_bundle_id="com.todesk.business.sos"
#指定项目的scheme名称（也就是工程的target名称），必填
master_target_name="ToDesk_Client_Master"
slave_target_name="ToDesk_Client_Slave"
sos_target_name="ToDesk_SOS"
#App名称
master_app_name="ToDesk_Client_Master"
slave_app_name="ToDesk_Client_Slave"
sos_app_name="ToDesk_SOS"

#工程根目录
project_dir="$project_root_dir/build_mac" 
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
#pkg工程地址
master_pkgproj_path="$script_dir/../packages/Master/${project_name}.pkgproj"
slave_pkgproj_path="$script_dir/../packages/Slave/${project_name}.pkgproj"
sos_pkgproj_path="$script_dir/../packages/SOS/"
#pkg输出地址
master_pkg_export_path="${export_path}/${master_app_name}.pkg"
slave_pkg_export_path="${export_path}/${slave_app_name}.pkg"
sos_pkg_export_path="${export_path}/${sos_app_name}.dmg"
#dSYM路径
master_dsym_source_path="$project_root_dir/bin/mac/Release/master"
slave_dsym_source_path="$project_root_dir/bin/mac/Release/slave"
sos_dsym_source_path="$project_root_dir/bin/mac/Release/sos"
dsym_dest_path="$project_root_dir/bin/mac/ToB"
#dSYM文件名
master_client_dsym_name="ToDesk_Client_Master.app.dSYM"
master_service_dsym_name="ToDesk_Service_Master.dSYM"
slave_client_dsym_name="ToDesk_Client_Slave.app.dSYM"
slave_service_dsym_name="ToDesk_Host_Service.dSYM"
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

#Master X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${master_target_name} ${master_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${master_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Slave X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${slave_target_name} ${slave_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${slave_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#SOS X86架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} x86_64 ${project_name} ${project_root_dir} ${project_output_directory} ${sos_target_name} ${sos_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "x86_64 ${sos_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Master X86 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/x86_64/$master_client_dsym_name"
cp -R "$master_dsym_source_path/$master_service_dsym_name" "$dsym_dest_path/x86_64/$master_service_dsym_name"

#Slave X86 dSYM
cp -R "$slave_dsym_source_path/$slave_client_dsym_name" "$dsym_dest_path/x86_64/$slave_client_dsym_name"
cp -R "$slave_dsym_source_path/$slave_service_dsym_name" "$dsym_dest_path/x86_64/$slave_service_dsym_name"

#SOS X86 dSYM
cp -R "$sos_dsym_source_path/$sos_client_dsym_name" "$dsym_dest_path/x86_64/$sos_client_dsym_name"
cp -R "$sos_dsym_source_path/$sos_service_dsym_name" "$dsym_dest_path/x86_64/$sos_service_dsym_name"
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

#Slave ARM架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${slave_target_name} ${slave_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${slave_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#SOS ARM架构编译
sh ${script_dir}/project_build.sh ${archive_version} ${archive_build} arm64 ${project_name} ${project_root_dir} ${project_output_directory} ${sos_target_name} ${sos_app_name} ${dynamic_ui}
result=$?
if [ $result == 1 ] ; then
    echo "arm64 ${sos_app_name} 编译失败😢 😢 😢"
    exit 1
fi

#Master ARM64 dSYM
cp -R "$master_dsym_source_path/$master_client_dsym_name" "$dsym_dest_path/arm64/$master_client_dsym_name"
cp -R "$master_dsym_source_path/$master_service_dsym_name" "$dsym_dest_path/arm64/$master_service_dsym_name"

#Slave ARM64 dSYM
cp -R "$slave_dsym_source_path/$slave_client_dsym_name" "$dsym_dest_path/arm64/$slave_client_dsym_name"
cp -R "$slave_dsym_source_path/$slave_service_dsym_name" "$dsym_dest_path/arm64/$slave_service_dsym_name"

#SOS ARM64 dSYM
cp -R "$sos_dsym_source_path/$sos_client_dsym_name" "$dsym_dest_path/arm64/$sos_client_dsym_name"
cp -R "$sos_dsym_source_path/$sos_service_dsym_name" "$dsym_dest_path/arm64/$sos_service_dsym_name"
echo "\033[32;1mARM64编译完成 😺 😺 😺\033[0m"


######################## 合并架构 ########################
master_client_path="${master_app_name}.app/Contents/MacOS/${master_app_name}"
master_service_path="${master_app_name}.app/Contents/MacOS/ToDesk_Service_Master"
slave_client_path="${slave_app_name}.app/Contents/MacOS/${slave_app_name}"
slave_service_path="${slave_app_name}.app/Contents/MacOS/ToDesk_Host_Service"
#slave_session_path="${slave_app_name}.app/Contents/Helpers"
sos_client_path="${sos_app_name}.app/Contents/MacOS/${sos_app_name}"
sos_service_path="${sos_app_name}.app/Contents/Helpers/ToDesk_Service_SOS"

cd ${export_path}

master_build_success=0
if [ -f "./x86_64/${master_client_path}" -a -f "./arm64/${master_client_path}" ] ; then
    master_build_success=1
fi


slave_build_success=0
if [ -f "./x86_64/${slave_client_path}" -a -f "./arm64/${slave_client_path}" ] ; then
    slave_build_success=1
fi

sos_build_success=0
if [ -f "./x86_64/${sos_client_path}" -a -f "./arm64/${sos_client_path}" ] ; then
    sos_build_success=1
fi


if [ $master_build_success == 1 -a $slave_build_success == 1 -a $sos_build_success == 1 ]; then
    echo "\033[32;1mMaster/Slave/SOS编译成功😺 😺 😺\033[0m"
elif [ $master_build_success == 1 -a $slave_build_success == 0 -a $sos_build_success == 0 ]; then
    echo "\033[32;1m仅Master编译成功\033[0m"
elif [ $master_build_success == 0 -a $slave_build_success == 1 -a $sos_build_success == 0 ]; then
    echo "\033[32;1m仅Slave编译成功\033[0m"
elif [ $master_build_success == 0 -a $slave_build_success == 0  -a $sos_build_success == 1 ]; then
    echo "\033[32;1m仅SOS编译成功\033[0m"
else
    echo "\033[31;1m"
    echo "Master/Slave编译失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

rm -rf ./${master_app_name}.app
cp -R ./arm64/${master_app_name}.app ./${master_app_name}.app
lipo -create ./arm64/${master_client_path} ./x86_64/${master_client_path} -output ./${master_client_path}
lipo -create ./arm64/${master_service_path} ./x86_64/${master_service_path} -output ./${master_service_path}

rm -rf ./${slave_app_name}.app
cp -R ./arm64/${slave_app_name}.app ./${slave_app_name}.app
lipo -create ./arm64/${slave_client_path} ./x86_64/${slave_client_path} -output ./${slave_client_path}
lipo -create ./arm64/${slave_service_path} ./x86_64/${slave_service_path} -output ./${slave_service_path}
#mkdir ${slave_session_path}
#cp -R ./${slave_service_path} ./${slave_session_path}

rm -rf ./${sos_app_name}.app
cp -R ./arm64/${sos_app_name}.app ./${sos_app_name}.app
lipo -create ./arm64/${sos_client_path} ./x86_64/${sos_client_path} -output ./${sos_client_path}
lipo -create ./arm64/${sos_service_path} ./x86_64/${sos_service_path} -output ./${sos_service_path}

#APP包重新签名
entitlements_path="$project_root_dir/ToDesk_Client/Mac/Resources/ToDesk_Client.entitlements"
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${master_app_name}.app
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${slave_app_name}.app
codesign --force --deep --entitlements $entitlements_path --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${sos_app_name}.app
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

#Slave dSYM架构合并
cp -R "./arm64/$slave_client_dsym_name" "./$slave_client_dsym_name"
lipo -create "./arm64/$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave" "./x86_64/$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave" -output "./$slave_client_dsym_name/$dsym_prefix/ToDesk_Client_Slave"
cp -R "./arm64/$slave_service_dsym_name" "./$slave_service_dsym_name"
lipo -create "./arm64/$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service" "./x86_64/$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service" -output "./$slave_service_dsym_name/$dsym_prefix/ToDesk_Host_Service"
tar -zcf "./${slave_app_name}_${archive_build}_dSYM.tar.gz" "./$slave_client_dsym_name" "./$slave_service_dsym_name"

#SOS dSYM架构合并
cp -R "./arm64/$sos_client_dsym_name" "./$sos_client_dsym_name"
lipo -create "./arm64/$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS" "./x86_64/$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS" -output "./$sos_client_dsym_name/$dsym_prefix/ToDesk_SOS"
cp -R "./arm64/$sos_service_dsym_name" "./$sos_service_dsym_name"
lipo -create "./arm64/$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS" "./x86_64/$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS" -output "./$sos_service_dsym_name/$dsym_prefix/ToDesk_Service_SOS"
tar -zcf "./${sos_app_name}_${archive_build}_dSYM.tar.gz" "./$sos_client_dsym_name" "./$sos_service_dsym_name"

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

sh ${script_dir}/pkg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${slave_app_name} ${export_path} ${slave_pkgproj_path} ${slave_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${slave_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

sh ${script_dir}/dmg_apple_sign.sh ${archive_version} ${archive_build} ${project_name} ${sos_app_name} ${export_path} ${sos_pkgproj_path} ${sos_bundle_id}
result=$?
if [ $result == 1 ] ; then
    echo "\033[31;1m"
    echo "${sos_app_name} 公签失败 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

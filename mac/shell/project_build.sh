#!/bin/sh

#版本号/架构
archive_version=""
archive_build=""
archive_type=""
#工程名/工程根目录/输出目录
project_name=""
project_root_dir=""
project_output_directory=""
#BundleID/Target
target_name=""
#App名称
app_name=""
#动态加载
dynamic_ui=""
if [ $# != 9 ] ; then
    echo "\033[31;1m"
    echo "project_build参数数量错误"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
else
    archive_version=$1
    archive_build=$2
    archive_type=$3
    project_name=$4
    project_root_dir=$5
    project_output_directory=$6
    target_name=$7
    app_name=$8
    dynamic_ui=$9
fi

# 导出方式
export_method="DeveloperID"
env="online"
# build config
config="release"

# 获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"

######################## ToDesk 工程信息 ########################
#工程根目录
project_dir="$project_root_dir/build_mac"
#工程pbxproj文件
project_pbxproj="${project_dir}/${project_name}.xcodeproj/project.pbxproj"
#工程Version
version_number=`sed -n '/MARKETING_VERSION/{s/MARKETING_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ${project_pbxproj}`
#获取Build
build_number=`sed -n '/CURRENT_PROJECT_VERSION/{s/CURRENT_PROJECT_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ${project_pbxproj}`
#工程编译输出路径
export_path="$project_root_dir/bin/mac/$project_output_directory"
if [[ "$archive_type" = "arm64" ]]; then
    export_path="${export_path}/arm64"
    echo "archive_type:${export_path}"
else
    export_path="${export_path}/x86_64"
    echo "archive_type:${export_path}"
fi


######################## ToDesk 编译参数 ########################
# 是否编译工作空间 (例:若是用Cocopods管理的.xcworkspace项目,赋值true;用Xcode默认创建的.xcodeproj,赋值false)
is_workspace="true"

# .xcworkspace的名字，如果is_workspace为true，则必须填。否则可不填
workspace_name="ToDesk"

# 指定导出app包需要用到的plist配置文件的路径
export_options_plist_path="$export_app_path/ExportOptions.plist"

# 指定export方式
if [[ "$export_method" = "DeveloperID" ]]; then
    export_options_plist_path="$script_dir/ExportOptions_DelevoperID.plist"
elif [[ "$export_method" = "Development" ]]; then
    export_options_plist_path="$script_dir/ExportOptions_Delevopment.plist"
else
    echo "\033[31;1m请选择export方式DeveloperID/Development \033[0m"
    echo "BUILD FAIL"
    exit 1
fi

# 指定编译方式
build_configuration=""
if [[ "$config" = "release" ]]; then
    build_configuration="Release"
elif [[ "$config" = "debug" ]]; then
    build_configuration="Debug"
else
    echo "\033[31;1m请选择构建版本release/debug \033[0m"
    echo "BUILD FAIL"
    exit 1
fi

#  下面两个参数只是在手动指定Pofile文件的时候用到，如果使用Xcode自动管理Profile,直接留空就好
# (跟method对应的)mobileprovision文件名，需要先双击安装.mobileprovision文件.手动管理Profile时必填
mobileprovision_name=""

# =======================脚本的一些固定参数定义(无特殊情况不用修改)====================== #
# 指定输出归档文件路径
export_archive_path="$export_path/$target_name.xcarchive"
# 指定输出app文件夹路径
export_app_path="$export_path"
# 制定目标
#build_destination="platform=macOS,arch=arm64"

echo "--------------------脚本配置参数检查--------------------"
echo "\033[33;1m"
echo "归档版本(archive_version):${archive_version}"
echo "script_dir:${script_dir}"
echo "project_root_dir:${project_root_dir}"
echo "project_dir:${project_dir}"
echo "export_method:${export_method} "
echo "env:${env}"
echo "config:${config}"
echo "version_number:${version_number}"
echo "build_number:${build_number}"
echo "export_path:${export_path}"
echo "is_workspace:${is_workspace} "
echo "workspace_name:${workspace_name}"
echo "project_name:${project_name}"
echo "target_name:${target_name}"
echo "build_configuration:${build_configuration}"
echo "export_method:${export_method}"
echo "mobileprovision_name:${mobileprovision_name}"
echo "build_flag:$(printf '%q ' "${define[@]}")"
echo "project_root_dir:${project_root_dir}"
echo "构建目标(archive_type):${archive_type}"
echo "xcarchive(export_archive_path):${export_archive_path}"
echo "输出路径(export_path):${export_path}"
echo "App导出路径(export_app_path):${export_app_path}"
echo "ExportOptions(export_options_plist_path):${export_options_plist_path}"
echo "app_name:${app_name}"
echo "\033[0m"

echo "--------------------设置Info.plist Sparkle信息 Start--------------------"
sparkle_path="${script_dir}/Sparkle/bin"

generate_key_file_path="${sparkle_path}/generate_keys"
generate_key_output_path="${sparkle_path}/generate_key_output"
info_plist_path="${project_root_dir}/${target_name}/Mac/Resources/info.plist"

if [ ! -f "$info_plist_path" ] ; then
    echo "\033[31;1m缺少${info_plist_path}"
    echo "BUILD FAIL\033[0m"
    exit 1
elif [ ! -f "$generate_key_file_path" ]; then
    echo "\033[31;1m缺少${generate_key_file_path}"
    echo "BUILD FAIL\033[0m"
    exit 1
else
    echo "\033[32;1m修改info.plist文件信息中\033[0m"
fi

# 将key写入文件并从文件中获取generate_key然后进行截取
${generate_key_file_path} &> ${generate_key_output_path}
generate_key=`cat ${generate_key_output_path} | grep -Eo '<string>\S{10,}</string>'`
generate_key=${generate_key#*>} # 从*>之后截取到字符串结尾
generate_key=${generate_key%<*} # 从字符串开头截取到<*之前
rm -rf ${generate_key_output_path}

# 修改plist.info内容
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${generate_key}" ${info_plist_path}
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${archive_version}" ${info_plist_path}
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${archive_build}" ${info_plist_path}

echo "generate_key:$generate_key info_plist_path:$info_plist_path"
echo "\033[32;1m修改info.plist文件信息修改成功\033[0m"
echo "--------------------设置Info.plist Sparkle信息 End--------------------\n"


echo "--------------------修改宏 Start--------------------"
echo "TODESK_CENTER_NORMAL_VERSION="$archive_version" TODESK_CENTER_BUSINESS_VERSION="$archive_version" isDynamicUI="$dynamic_ui""
declare -a define
define=( ${define[*]} 'TODESK_CENTER_NORMAL_VERSION="'$archive_version'"')
define=( ${define[*]} 'TODESK_CENTER_BUSINESS_VERSION="'$archive_version'"')
if [[ "$dynamic_ui" = "true" ]]; then
     define=( ${define[*]} 'TESTUI='1'')
fi
 
echo "--------------------修改宏 End--------------------\n"


curren_date=`date '+%Y-%m-%d_%H-%M-%S'`
echo "--------------------开始构建项目 ${curren_date}--------------------"
# 进入项目工程目录
cd ${project_dir}

# 指定输出文件目录不存在则创建
if [ -d "$export_path" ] ; then
    echo $export_path
else
    mkdir -pv $export_path
fi

# 判断编译的项目类型是workspace还是project
if $is_workspace ; then
# 编译前清理工程
xcodebuild clean -workspace ${workspace_name}.xcworkspace \
                 -scheme ${target_name} \
                 -configuration ${build_configuration} \
                 -quiet

# xcodebuild -workspace build_mac/ToDesk.xcworkspace -scheme ToDesk_Client -configuration Release -arch arm64
# -destination ${build_destination}
xcodebuild archive -workspace ${workspace_name}.xcworkspace \
                   -scheme ${target_name} \
                   -configuration ${build_configuration} \
                   -archivePath ${export_archive_path} \
                   -arch ${archive_type} \
                   GCC_PREPROCESSOR_DEFINITIONS=" \$(inherited) $GCC_PREPROCESSOR_DEFINITIONS $(printf '%q ' "${define[@]}") " \
                   -quiet
                   
                   
else
# 编译前清理工程
xcodebuild clean -project ${project_name}.xcodeproj \
                 -scheme ${target_name} \
                 -configuration ${build_configuration} \
                 -quiet


xcodebuild archive -project ${project_name}.xcodeproj \
                   -scheme ${target_name} \
                   -configuration ${build_configuration} \
                   -archivePath ${export_archive_path}  \
                   -arch ${archive_type} \
                   GCC_PREPROCESSOR_DEFINITIONS=" \$(inherited) $GCC_PREPROCESSOR_DEFINITIONS ""$(printf '%q ' "${define[@]}") " \
                   -quiet
fi

#  检查是否构建成功
#  xcarchive 实际是一个文件夹不是一个文件所以使用 -d 判断
if [ -d "$export_archive_path" ] ; then
    echo "\033[32;1m"
    echo "项目构建成功 🚀 🚀 🚀  "
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "项目构建失败 😢 😢 😢  "
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

curren_date=`date '+%Y-%m-%d_%H-%M-%S'`
echo "--------------------开始导出App ${curren_date}--------------------"
echo "\033[33;1m"
echo "导出地址：${export_app_path}/${app_name}.app"
echo "\033[0m"

xcodebuild  -exportArchive \
            -archivePath ${export_archive_path} \
            -exportPath ${export_app_path} \
            -exportOptionsPlist $export_options_plist_path
            # -allowProvisioningUpdates

echo "验证路径: ${export_app_path}/${app_name}.app"

# 检查app文件是否存在
if [ -d "${export_app_path}/${app_name}.app" ] ; then
    echo "\033[32;1m"
    echo "app包导出成功"
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "${export_app_path}/${app_name}.app不存在 😢 😢 😢"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

echo "\033[36;1m"
echo "使用AutoPackageScript打包总用时: ${SECONDS}s "
echo "\033[0m"


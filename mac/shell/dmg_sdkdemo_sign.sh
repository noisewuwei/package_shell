archive_version=""
archive_build=""
project_name=""
app_name=""
export_path=""
pkgproj_path=""
target_bundle_id=""
if [ $# != 7 ] ; then
    echo "\033[31;1m"
    echo "参数数量错误"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
else
    archive_version=$1
    archive_build=$2
    project_name=$3
    app_name=$4
    export_path=$5
    pkgproj_path=$6
    target_bundle_id=$7
fi

#获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"

#dmg输出地址
dmg_export_path="${export_path}/${app_name}.dmg"

echo "--------------------dmg构建 Start--------------------"
temp_dmg_export_path="${export_path}/${app_name}_signed.dmg"
rm -rf $dmg_export_path;
rm -rf $temp_dmg_export_path;

curren_date=`date '+%Y-%m-%d_%H-%M-%S'`
echo "\033[33;1m构建时间：${curren_date}"
echo "dmg输出地址：${temp_dmg_export_path}"
echo "\033[0m"

#拷贝dmg资源到输出路径下
cp -R ${pkgproj_path}/ ${export_path}/

#cd到输出路径并进行dmg打包
appdmg ${export_path}/appdmg.json ${dmg_export_path}
codesign -f -o runtime -s "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" -v ${dmg_export_path} --deep
if [ -f "$dmg_export_path" ] ; then
    echo "\033[32;1m"
    echo "dmg构建成功 🚀 🚀 🚀  "
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "dmg构建失败 😢 😢 😢  "
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi
echo "--------------------dmg构建 End--------------------\n"



echo "--------------------dmg公签 Start--------------------"
#公签
xcrun notarytool submit $dmg_export_path --keychain-profile "ToDeskNotarization" --wait

#获取公签结果
spctl --assess -vv --type install $dmg_export_path  &> tmp;
tempcontent=`cat tmp`
status=`cat tmp | grep -Eo 'Notarized Developer ID'`
echo "$tempcontent"
if [[ $status == "Notarized Developer ID" ]]; then
    echo "\033[32;1m"
    echo "公签成功!"
    echo "BUILD SUCCESS"
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "公签失败!"
    echo "BUILD FAIL"
    echo "\033[0m"
fi

#修改dmg名
new_dmg_export_path="${export_path}/${app_name}-v${archive_version}_${archive_build}.dmg"
rm -rf tmp;
mv $dmg_export_path $new_dmg_export_path
rm -rf $dmg_export_path;
echo "--------------------dmg公签 End--------------------\n"
exit 0

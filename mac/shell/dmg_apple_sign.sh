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

echo "--------------------Sparkle xml配置 Start--------------------"
sparkle_path="${script_dir}/Sparkle/bin"

sign_update_file_path="${sparkle_path}/sign_update"
sign_update_output_path="${sparkle_path}/sign_update_output"
sparkle_xml_path="${script_dir}/sparkletestcast.xml"
copy_sparkle_xml_path="${export_path}/${app_name}_sparkletestcast.xml"
cp -R ${sparkle_xml_path} ${copy_sparkle_xml_path}

if [ ! -f "$sign_update_file_path" ]; then
    echo "\033[31;1m缺少${sign_update_file_path}"
    echo "BUILD FAIL\033[0m"
    exit 1
elif [ ! -f "$sparkle_xml_path" ]; then
    echo "\033[31;1m缺少${sparkle_xml_path}"
    echo "BUILD FAIL\033[0m"
    exit 1
elif [ ! -f "$copy_sparkle_xml_path" ]; then
    echo "\033[31;1m缺少${copy_sparkle_xml_path}"
    echo "BUILD FAIL\033[0m"
    exit 1
else
    echo "\033[32;1m修改sparkletestcast.xml文件信息中\033[0m"
fi



#将sign_update内容写入文件并读取出来，然后进行字符串获取
${sign_update_file_path} ${dmg_export_path} &> ${sign_update_output_path}
echo "sign_update_file_path:${sign_update_file_path} dmg_export_path:${dmg_export_path} sign_update_output_path:${sign_update_output_path}"

#length
sign_file_size=`cat ${sign_update_output_path} | grep -Eo 'length="\d{1,}"' | grep -Eo '[0-9]{1,}'`
old_sign_file_size=`cat ${copy_sparkle_xml_path} | grep -Eo 'length="\d{1,}"' | grep -Eo '[0-9]{1,}'`

#edSignature
sign_file_edSignature=`cat ${sign_update_output_path} | grep -Eo 'edSignature="\S{1,}"' | grep -Eo '"\S{1,}"'`
sign_file_edSignature=${sign_file_edSignature//\//\\/} #替换所有(/)为为(\/)
old_sign_file_edSignature=`cat ${copy_sparkle_xml_path} | grep -Eo 'edSignature="\S{1,}"' | grep -Eo '"\S{1,}"'`
old_sign_file_edSignature=${old_sign_file_edSignature//\//\\/} #替换所有(")为为()

sed -i '' 's/'$old_sign_file_size'/'$sign_file_size'/g' ${copy_sparkle_xml_path}
sed -i '' 's/'$old_sign_file_edSignature'/'$sign_file_edSignature'/g' ${copy_sparkle_xml_path}
rm -rf ${sign_update_output_path}
echo "\033[32;1m修改sparkletestcast.xml文件成功\033[0m"
echo "--------------------Sparkle xml配置 End--------------------\n"


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

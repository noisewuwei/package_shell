
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

#pkg输出地址
pkg_export_path="${export_path}/${app_name}.pkg"

echo "--------------------pkg构建 Start--------------------"
temp_pkg_export_path="${export_path}/${app_name}_signed.pkg"
rm -rf $pkg_export_path;
rm -rf $temp_pkg_export_path;

curren_date=`date '+%Y-%m-%d_%H-%M-%S'`
echo "\033[33;1m构建时间：${curren_date}"
echo "pkg输出地址：${temp_pkg_export_path}"
echo "\033[0m"

/usr/local/bin/packagesbuild --package-version ${archive_build} ${pkgproj_path}
if [ -f "$pkg_export_path" ] ; then
    echo "\033[32;1m"
    echo "pkg构建成功 🚀 🚀 🚀  "
    echo "\033[0m"
else
    echo "\033[31;1m"
    echo "pkg构建失败 😢 😢 😢  "
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi
echo "--------------------pkg构建 End--------------------\n"



echo "--------------------pkg Developer ID Installer签名 Start--------------------"
#使用Developer ID Installer对pkg包进行签名并生成一个新的pkg包
productsign --sign  "Developer ID Installer: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" \
            ${pkg_export_path} ${temp_pkg_export_path};

if [ -f "$temp_pkg_export_path" ] ; then
    echo "\033[32;1m签名成功 🚀 🚀 🚀  \033[0m"
else
    echo "\033[31;1m签名失败 😢 😢 😢  "
    echo "BUILD FAIL\033[0m"
    exit 1
fi
echo "--------------------pkg Developer ID Installer签名 End--------------------\n"





echo "--------------------pkg公签 Start--------------------"
#公签
xcrun notarytool submit $temp_pkg_export_path --keychain-profile "ToDeskNotarization" --wait

#获取公签结果
spctl --assess -vv --type install $temp_pkg_export_path  &> tmp;
tempcontent=`cat tmp`
status=`cat tmp | grep -Eo 'Notarized Developer ID'`
echo "$tempcontent"

# 添加票据（没网络时可通过验证）
if [[ $status == "Notarized Developer ID" ]]; then
    xcrun stapler staple $temp_pkg_export_path
    echo "\033[32;1m"
    echo "公签成功!"
    echo "BUILD SUCCESS"
    echo "\033[0m"
fi

#修改pkg名
# rm -rf tmp;
rm -rf $pkg_export_path;
pkg_export_path="${export_path}/${app_name}-v${archive_version}_${archive_build}.pkg"
mv $temp_pkg_export_path $pkg_export_path

if [[ $status != "Notarized Developer ID" ]]; then
    echo "\033[31;1m"
    echo "公签失败!"
    echo "执行 xcrun notarytool log \"uuid\" --keychain-profile ToDeskNotarization 查询失败原因"
    echo "BUILD FAIL"
    echo "\033[0m"
    exit 1
fi

echo "--------------------pkg公签 End--------------------\n"




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
${sign_update_file_path} ${pkg_export_path} &> ${sign_update_output_path}
echo "sign_update_file_path:${sign_update_file_path} pkg_export_path:${pkg_export_path} sign_update_output_path:${sign_update_output_path}"

#length
sign_file_size=`cat ${sign_update_output_path} | grep -Eo 'length="\d{1,}"' | grep -Eo '[0-9]{1,}'`
old_sign_file_size=`cat ${copy_sparkle_xml_path} | grep -Eo 'length="\d{1,}"' | grep -Eo '[0-9]{1,}'`

#edSignature
sign_file_edSignature=`cat ${sign_update_output_path} | grep -Eo 'edSignature="\S{1,}"' | grep -Eo '"\S{1,}"'`
sign_file_edSignature=${sign_file_edSignature//\//\\/} #替换所有(/)为为(\/)
old_sign_file_edSignature=`cat ${copy_sparkle_xml_path} | grep -Eo 'edSignature="\S{1,}"' | grep -Eo '"\S{1,}"'`
old_sign_file_edSignature=${old_sign_file_edSignature//\//\\/} #替换所有(")为为()

# 设置Sparkle更新信息中的应用名
update_title="ToDesk"
if [[ "$app_name" = "ToDesk_Client_Master" ]]; then
    update_title="ToDesk企业主控"
elif [[ "$app_name" = "ToDesk_Client_Slave" ]]; then
    update_title="ToDesk企业被控"
elif [[ "$app_name" = "ToDesk_SOS" ]]; then
    update_title="ToDesk SOS"
fi

sed -i '' "s/<title>ToDesk<\/title>/<title>${update_title}<\/title>/"  ${copy_sparkle_xml_path}
sed -i '' "s/<sparkle:version>.*<\/sparkle:version>/<sparkle:version>${archive_build}<\/sparkle:version>/" ${copy_sparkle_xml_path}
sed -i '' "s/<sparkle:shortVersionString>.*<\/sparkle:shortVersionString>/<sparkle:shortVersionString>${archive_version}<\/sparkle:shortVersionString>/" ${copy_sparkle_xml_path}
sed -i '' 's/'$old_sign_file_size'/'$sign_file_size'/g' ${copy_sparkle_xml_path}
sed -i '' 's/'$old_sign_file_edSignature'/'$sign_file_edSignature'/g' ${copy_sparkle_xml_path}

rm -rf ${sign_update_output_path}
echo "\033[32;1m修改sparkletestcast.xml文件成功\033[0m"
echo "--------------------Sparkle xml配置 End--------------------\n"

exit 0

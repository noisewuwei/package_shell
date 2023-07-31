# codesign --force --deep --options=runtime -s  "Developer ID Application: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${app_name}.app
pkgproj_path="./ToDeskAudioDrive.pkgproj"
pkg_export_path="../ToDeskAudioDrive.pkg"
temp_pkg_export_path="../ToDeskAudioDrive_signed.pkg"
target_bundle_id="com.youqu.todesk.ToDeskAudioDrive"
#编译pkg
/usr/local/bin/packagesbuild --package-version "1" ${pkgproj_path}

#签名
productsign --sign  "Developer ID Installer: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" ${pkg_export_path} ${temp_pkg_export_path};
echo "--------------------pkg公签 Start--------------------"
xcrun altool --notarize-app \
             --primary-bundle-id ${target_bundle_id} \
             --username "appstore@54nb.com" \
             --password "ptli-tlxh-fauj-ftrb" \
             --asc-provider "KM56KD59W4" \
             --file $temp_pkg_export_path &> tmp;


#获取UUID
uuid=`cat tmp | grep -Eo '\w{8}-(\w{4}-){3}\w{12}$'`
#验证次数
checkcount=0
#循环判断公证结果
while true; do
    echo "checking for notarization...uuid = " $uuid
    xcrun altool --notarization-info "$uuid" \
                 --username "appstore@54nb.com" \
                 --password "ptli-tlxh-fauj-ftrb" &> tmp
    r=`cat tmp`
    t=`echo "$r" | grep "success"`
    f=`echo "$r" | grep "invalid"`
    if [[ "$t" != "" ]]; then
        xcrun stapler staple $temp_pkg_export_path
        echo "\033[32;1m"
        echo "公签成功!"
        echo "BUILD SUCCESS"
        echo "\033[0m"
        break
    fi
    if [[ "$f" != "" ]]; then
        echo "$r"
        echo "BUILD FAIL"
        break
    fi
    checkcount=$((${checkcount} + 1))
    if [ $checkcount -ge 60 ]; then
        echo "验证超时"
        echo "BUILD FAIL"
        break
    fi
    echo "not finish yet, sleep 10s then check again..."
    sleep 10
done

#修改pkg名
rm -rf tmp;
rm -rf $pkg_export_path;
mv $temp_pkg_export_path $pkg_export_path
echo "--------------------pkg公签 End--------------------\n"

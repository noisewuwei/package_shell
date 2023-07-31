
# 特别注意：
# 公证所使用的App包不能事先通过Xcode进行公证，否则会无法公证
# App需要先通过Developer ID证书进行签名

# 获取当前脚本所在目录
script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
# 工程根目录
project_dir=$script_dir
# 指定项目的scheme名称（也就是工程的target名称），必填
scheme_name="ToDesk"
# 指定输出导出文件夹路径
pkg_path="$project_dir/Package"

echo "$pkg_path/${scheme_name}/${scheme_name}.pkg"
exit 1

# 使用Developer ID Installer对pkg包进行签名并生成一个新的pkg包
productsign --sign  "Developer ID Installer: Hainan Youqu Technology Co., Ltd. (KM56KD59W4)" \
            $pkg_path/${scheme_name}/${scheme_name}.pkg \
            $pkg_path/${scheme_name}/${scheme_name}_signed.pkg;

# 进行公证
xcrun altool --notarize-app \
             --primary-bundle-id "com.youqu.todesk.mac" \
             --username "appstore@54nb.com" \
             --password "ptli-tlxh-fauj-ftrb" \
             --asc-provider "KM56KD59W4" \
             --file $pkg_path/${scheme_name}_signed.pkg &> tmp;

# 获取UUID
uuid=`cat tmp | grep -Eo '\w{8}-(\w{4}-){3}\w{12}$'`
# 循环判断公证结果
while true; do
    echo "checking for notarization...uuid = " $uuid
    xcrun altool --notarization-info "$uuid" \
                 --username "appstore@54nb.com" \
                 --password "ptli-tlxh-fauj-ftrb" &> tmp
    r=`cat tmp`
    t=`echo "$r" | grep "success"`
    f=`echo "$r" | grep "invalid"`
    if [[ "$t" != "" ]]; then
        echo "notarization done!"
        xcrun stapler staple "ToDesk1.pkg"
        echo "stapler done!"
        break
    fi
    if [[ "$f" != "" ]]; then
        echo "$r"
        return 1
    fi
    echo "not finish yet, sleep 20s then check again..."
    sleep 10
done

#改变包名
rm -rf tmp;
rm -rf $pkg_path/${scheme_name}/${scheme_name}.pkg;
mv $pkg_path/${scheme_name}/${scheme_name}_signed.pkg $pkg_path/${scheme_name}/${scheme_name}.pkg;

# xcrun altool --notarization-info "8480a702-c15a-4178-ac04-ec7c86d632d3" --username "appstore@54nb.com" --password "ptli-tlxh-fauj-ftrb"

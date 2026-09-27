#!/bin/bash
set -e

# Linux .deb 安装包构建脚本
APP_NAME="mellow-music"
VERSION="1.0.0"
ARCH="amd64"
PKG_DIR="build/deb_pkg"
OUTPUT_DEB="Mellow-Music-Linux-amd64.deb"

echo "=== 开始构建 Linux .deb 原生安装包 ==="
rm -rf "$PKG_DIR" "$OUTPUT_DEB"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/lib/$APP_NAME"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"

# 1. 复制二进制与依赖资源
cp -R build/linux/x64/release/bundle/* "$PKG_DIR/usr/lib/$APP_NAME/"

# 2. 赋予执行权限并创建 /usr/bin 快捷启动器
chmod +x "$PKG_DIR/usr/lib/$APP_NAME/mellow_music"
cat << 'EOF' > "$PKG_DIR/usr/bin/mellow-music"
#!/bin/bash
exec /usr/lib/mellow-music/mellow_music "$@"
EOF
chmod +x "$PKG_DIR/usr/bin/mellow-music"

# 3. 复制应用图标
if [ -f "assets/icons/app_icon_256.png" ]; then
    cp assets/icons/app_icon_256.png "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
elif [ -f "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" ]; then
    cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
fi

# 4. 生成桌面启动入口 .desktop
cat << EOF > "$PKG_DIR/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=Mellow Music
Name[zh_CN]=润音
Comment=Modern Soft UI Hi-Fi Music Player
Comment[zh_CN]=温润微拟物高保真全网流媒体音乐播放器
Exec=/usr/bin/mellow-music
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;Music;
StartupWMClass=mellow_music
EOF
chmod 644 "$PKG_DIR/usr/share/applications/$APP_NAME.desktop"

# 5. 生成标准 DEBIAN/control 元数据
cat << EOF > "$PKG_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: Mellow Music Team <dev@mellowmusic.io>
Depends: libgtk-3-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, liblzma5
Section: sound
Priority: optional
Homepage: https://github.com/Kline-x/mellow-music-player
Description: Mellow Music - Modern Soft UI Hi-Fi Music Player
 A soothing, tactile cross-platform music experience with lossless streaming.
EOF

# 6. 使用 dpkg-deb 压制成标准 .deb 包
dpkg-deb --build --root-owner-group "$PKG_DIR" "$OUTPUT_DEB"
rm -rf "$PKG_DIR"
echo "=== Linux 原生安装包构建完成: $OUTPUT_DEB ==="

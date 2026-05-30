#!/usr/bin/env bash
# build-fcitx5.sh — fcitx5 기반 한글 COSMIC 리마스터 (신규 rootfs)
set -e
BUILD=/home/nmsglobal/korean-popos-build
ORIGSQ="$BUILD/filesystem.squashfs"
ORIG="$BUILD/pop-os_24.04_amd64_intel_20.iso"
RF="$BUILD/rootfs-fc"
NEWSQ="$BUILD/filesystem-fc.squashfs"
NEWISO="$BUILD/pop-cosmic-korean-fcitx5.iso"
SRC=/mnt/c/DEVEL/korean-popos
[ "$(id -u)" = 0 ] || { echo "root"; exit 1; }

echo "=== unsquash fresh rootfs-fc ==="
[ -f "$RF/usr/bin/dpkg" ] || { rm -rf "$RF"; mkdir -p "$RF"; unsquashfs -f -d "$RF" "$ORIGSQ" >/dev/null 2>&1; }
cp -f /etc/resolv.conf "$RF/etc/resolv.conf"
cp -f "$SRC/libhangul-test.py" "$SRC/gtk-ime-test.py" "$RF/usr/local/bin/"
cp -f "$SRC/selftest-fcitx5.sh" "$RF/usr/local/bin/korean-selftest.sh"
sed -i 's/\r$//' "$RF/usr/local/bin/"*.py "$RF/usr/local/bin/korean-selftest.sh"
chmod +x "$RF/usr/local/bin/"*.py "$RF/usr/local/bin/korean-selftest.sh"

mount --bind /proc "$RF/proc"; mount --bind /sys "$RF/sys"; mount --bind /dev "$RF/dev"; mount --bind /dev/pts "$RF/dev/pts"
trap 'umount "$RF/dev/pts" "$RF/dev" "$RF/sys" "$RF/proc" 2>/dev/null||true' EXIT

chroot "$RF" /bin/bash <<'CH'
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y --no-install-recommends \
  fcitx5 fcitx5-hangul fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 \
  fonts-noto-cjk fonts-noto-cjk-extra language-pack-ko language-pack-gnome-ko \
  gnome-text-editor wtype xdotool python3-gi gir1.2-gtk-3.0 2>&1 | tail -4 || echo "install warn"
locale-gen ko_KR.UTF-8 en_US.UTF-8 || true
update-locale LANG=ko_KR.UTF-8 LANGUAGE=ko_KR:ko || true
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime; echo Asia/Seoul >/etc/timezone
for f in /etc/profile.d/pop-im-ibus.sh /etc/profile.d/pop-im-fcitx.sh; do [ -f "$f" ] && mv "$f" "$f.disabled"; done
mkdir -p /etc/environment.d
cat >/etc/environment.d/90-korean-fcitx.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
GLFW_IM_MODULE=fcitx
SDL_IM_MODULE=fcitx
EOF
for kv in GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx GLFW_IM_MODULE=fcitx SDL_IM_MODULE=fcitx MOZ_ENABLE_WAYLAND=0; do
  grep -q "^${kv%%=*}=" /etc/environment || echo "$kv" >>/etc/environment
done
printf 'export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx\n' >/etc/profile.d/zz-korean-fcitx.sh
mkdir -p /etc/gtk-3.0 /etc/gtk-4.0
printf '[Settings]\ngtk-im-module=fcitx\n' >/etc/gtk-3.0/settings.ini
printf '[Settings]\ngtk-im-module=fcitx\n' >/etc/gtk-4.0/settings.ini
mkdir -p /etc/xdg/fcitx5 /etc/skel/.config/fcitx5
cat >/etc/skel/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
EOF
cp /etc/skel/.config/fcitx5/profile /etc/xdg/fcitx5/profile
cat >/etc/xdg/autostart/zz-fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d --replace
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
cat >/etc/xdg/autostart/zz-korean-selftest.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Korean Selftest
Exec=bash /usr/local/bin/korean-selftest.sh
X-GNOME-Autostart-enabled=true
EOF
for d in /etc/xdg/autostart/*nstall* /etc/xdg/autostart/com.system76.CosmicInitialSetup*; do [ -f "$d" ] && mv "$d" "$d.disabled"; done
echo "fcitx5=$(command -v fcitx5||echo NO) hangul.so=$(find /usr/lib -name 'hangul.so' -path '*fcitx5*' 2>/dev/null|head -1) wtype=$(command -v wtype||echo NO) xdotool=$(command -v xdotool||echo NO) gtk-im=$(cat /etc/gtk-3.0/settings.ini|tr -d '\n')"
CH
umount "$RF/dev/pts" "$RF/dev" "$RF/sys" "$RF/proc" 2>/dev/null||true
trap - EXIT

echo "=== squash ==="
COMP=$(unsquashfs -s "$ORIGSQ" 2>/dev/null|awk -F': *' '/Compression/{print $2}'|tr -d ' ');[ -n "$COMP" ]||COMP=zstd
rm -f "$NEWSQ"; mksquashfs "$RF" "$NEWSQ" -comp "$COMP" -noappend -no-progress 2>&1|tail -2
CASPERDIR=$(xorriso -indev "$ORIG" -lsl / 2>/dev/null|grep '^d'|grep -o "casper_pop-os[^']*"|head -1)
du -sb --apparent-size "$RF" 2>/dev/null|cut -f1 > "$BUILD/fs-fc.size"
rm -f "$NEWISO"
xorriso -indev "$ORIG" -outdev "$NEWISO" -boot_image any replay -overwrite on \
  -map "$NEWSQ" "/$CASPERDIR/filesystem.squashfs" \
  -map "$BUILD/fs-fc.size" "/$CASPERDIR/filesystem.size" 2>&1|tail -5
ls -lh "$NEWISO" && echo BUILD_OK

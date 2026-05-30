#!/usr/bin/env bash
# fcitx5 한영키 다중(Mac Caps Lock + Win 한영키/우Alt + Ctrl/Shift+Space) + 부팅 자동시작 견고화
set -e
BUILD=/home/nmsglobal/korean-popos-build
RF="$BUILD/rootfs-fc"; ORIGSQ="$BUILD/filesystem.squashfs"; ORIG="$BUILD/pop-os_24.04_amd64_intel_20.iso"
NEWSQ="$BUILD/filesystem-final.squashfs"; NEWISO="$BUILD/pop-cosmic-korean-final.iso"
pkill mksquashfs 2>/dev/null||true; sleep 1; rm -f "$NEWSQ"
[ -d "$RF/usr" ] || { echo "rootfs-fc missing"; exit 1; }

# 1) fcitx5 hotkey config (한영 전환키 5종)
mkdir -p "$RF/etc/xdg/fcitx5" "$RF/etc/skel/.config/fcitx5"
cat > "$RF/etc/xdg/fcitx5/config" <<'EOF'
[Hotkey]
EnumerateWithTriggerKeys=True

[Hotkey/TriggerKeys]
0=Control+space
1=Shift+space
2=Hangul
3=Caps_Lock
4=Alt_R
EOF
cp "$RF/etc/xdg/fcitx5/config" "$RF/etc/skel/.config/fcitx5/config"

# 2) 부팅 자동시작 3중 (systemd user service + skel autostart + xdg autostart) + provisioning
cat > "$RF/usr/lib/systemd/user/fcitx5-korean.service" <<'EOF'
[Unit]
Description=Fcitx5 Korean IME
PartOf=graphical-session.target
After=graphical-session.target
[Service]
Type=simple
ExecStartPre=/bin/sh -c 'mkdir -p %h/.config/fcitx5; [ -f %h/.config/fcitx5/profile ] || cp /etc/xdg/fcitx5/profile %h/.config/fcitx5/profile; [ -f %h/.config/fcitx5/config ] || cp /etc/xdg/fcitx5/config %h/.config/fcitx5/config'
ExecStart=/usr/bin/fcitx5
Restart=on-failure
[Install]
WantedBy=graphical-session.target
EOF
mkdir -p "$RF/etc/systemd/user/graphical-session.target.wants"
ln -sf /usr/lib/systemd/user/fcitx5-korean.service "$RF/etc/systemd/user/graphical-session.target.wants/fcitx5-korean.service"

PROV='sh -c "mkdir -p $HOME/.config/fcitx5; [ -f $HOME/.config/fcitx5/profile ] || cp /etc/xdg/fcitx5/profile $HOME/.config/fcitx5/profile; [ -f $HOME/.config/fcitx5/config ] || cp /etc/xdg/fcitx5/config $HOME/.config/fcitx5/config; sleep 4; fcitx5 -d --replace"'
mkdir -p "$RF/etc/skel/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=Fcitx5 Korean\nExec=%s\nX-GNOME-Autostart-enabled=true\n' "$PROV" > "$RF/etc/skel/.config/autostart/fcitx5-korean.desktop"
printf '[Desktop Entry]\nType=Application\nName=Fcitx5 Korean\nExec=%s\nX-GNOME-Autostart-enabled=true\nNoDisplay=true\n' "$PROV" > "$RF/etc/xdg/autostart/zz-fcitx5.desktop"

echo "config:"; cat "$RF/etc/xdg/fcitx5/config" | grep -A6 TriggerKeys

# re-squash + repackage
COMP=$(unsquashfs -s "$ORIGSQ" 2>/dev/null|awk -F': *' '/Compression/{print $2}'|tr -d ' ');[ -n "$COMP" ]||COMP=zstd
mksquashfs "$RF" "$NEWSQ" -comp "$COMP" -noappend -no-progress 2>&1|tail -2
CASPERDIR=$(xorriso -indev "$ORIG" -lsl / 2>/dev/null|grep '^d'|grep -o "casper_pop-os[^']*"|head -1)
du -sb --apparent-size "$RF" 2>/dev/null|cut -f1 > "$BUILD/fs-final.size"
rm -f "$NEWISO"
xorriso -indev "$ORIG" -outdev "$NEWISO" -boot_image any replay -overwrite on \
  -map "$NEWSQ" "/$CASPERDIR/filesystem.squashfs" -map "$BUILD/fs-final.size" "/$CASPERDIR/filesystem.size" 2>&1|tail -3
ls -lh "$NEWISO" && echo BUILD_OK

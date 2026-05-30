#!/bin/bash
# fcitx5 5.1.7 -> plucky 5.1.12+ 업그레이드 (COSMIC Wayland input-method 요구버전)
set -x
echo cosmic1234 | sudo -S bash -c '
echo "deb http://archive.ubuntu.com/ubuntu plucky main universe" > /etc/apt/sources.list.d/plucky.list
printf "Package: *\nPin: release n=plucky\nPin-Priority: 100\n" > /etc/apt/preferences.d/plucky
apt-get update -y 2>&1 | tail -2
apt-get install -y -t plucky fcitx5 fcitx5-modules fcitx5-config-qt fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-hangul 2>&1 | tail -6
rm -f /etc/apt/sources.list.d/plucky.list /etc/apt/preferences.d/plucky
apt-get update -y 2>&1 | tail -1
'
echo "=== fcitx5 version after ==="
fcitx5 --version 2>&1 | head -1
dpkg -l fcitx5 fcitx5-hangul 2>/dev/null | grep ^ii | awk '{print $2,$3}'
echo UPGRADE_DONE

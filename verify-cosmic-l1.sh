#!/usr/bin/env bash
# L1 verify — 실제 Pop!_OS 24.04 COSMIC rootfs(ISO squashfs)에 korean-fix.sh 적용 테스트
# root 로 실행. extract → unsquash → chroot run → assert.
set -u
BUILD="${BUILD:-/home/nmsglobal/korean-popos-build}"
ISO="$BUILD/pop-os_24.04_amd64_intel_20.iso"
ROOTFS="$BUILD/rootfs"
SQ="$BUILD/filesystem.squashfs"
LOG="$BUILD/l1-korean-fix.log"

[ "$(id -u)" = 0 ] || { echo "run as root (sudo)"; exit 1; }
[ -f "$ISO" ] || { echo "ISO missing: $ISO"; exit 1; }

echo "=== tools ==="
for t in xorriso unsquashfs mksquashfs chroot; do
  printf "%-10s " "$t"; command -v "$t" >/dev/null && echo OK || { echo MISSING; exit 1; }
done

echo "=== extract squashfs from ISO ==="
# Pop 24.04: /casper 는 symlink. 실제 dir = casper_pop-os_* (build 번호 가변) → 자동탐지
CASPERDIR=$(xorriso -indev "$ISO" -lsl / 2>/dev/null | grep '^d' | grep -o "casper_pop-os[^']*" | head -1)
[ -n "$CASPERDIR" ] || CASPERDIR=casper
SQPATH="/$CASPERDIR/filesystem.squashfs"
echo "casper dir: $CASPERDIR  | squashfs: $SQPATH"
rm -f "$SQ"
if ! xorriso -osirrox on -indev "$ISO" -extract "$SQPATH" "$SQ" 2>/tmp/xorr.err; then
  echo "extract $SQPATH FAILED. ISO /casper layout:"
  xorriso -indev "$ISO" -lsl /casper 2>/dev/null | head -40
  echo "--- root listing ---"
  xorriso -indev "$ISO" -lsl / 2>/dev/null | head -40
  cat /tmp/xorr.err | tail -5
  exit 1
fi
ls -lh "$SQ"

echo "=== unsquashfs (몇 분) ==="
rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
unsquashfs -f -d "$ROOTFS" "$SQ" >/dev/null 2>&1
echo "top entries: $(ls "$ROOTFS" | tr '\n' ' ')"
echo "--- os-release ---"; head -4 "$ROOTFS/etc/os-release" 2>/dev/null
echo "--- ibus BEFORE: $(chroot "$ROOTFS" ibus version 2>/dev/null || echo 'not installed') ---"
echo "--- pop-im-ibus.sh present BEFORE: $([ -f "$ROOTFS/etc/profile.d/pop-im-ibus.sh" ] && echo YES || echo no) ---"

echo "=== chroot prep ==="
cp -f /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
mount --bind /proc "$ROOTFS/proc"
mount --bind /sys  "$ROOTFS/sys"
mount --bind /dev  "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
trap 'umount "$ROOTFS/dev/pts" "$ROOTFS/dev" "$ROOTFS/sys" "$ROOTFS/proc" 2>/dev/null || true' EXIT

cp "$BUILD/korean-fix.sh" "$ROOTFS/tmp/korean-fix.sh"
echo "=== RUN korean-fix.sh in REAL COSMIC chroot ==="
chroot "$ROOTFS" /bin/bash /tmp/korean-fix.sh >"$LOG" 2>&1
RC=$?
echo "korean-fix.sh exit code: $RC"
echo "--- last 30 log lines ---"; tail -30 "$LOG"

echo ""
echo "============ L1 ASSERTIONS ============"
pass=0; fail=0
chk(){ if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

chk "korean-fix exit 0"                 "[ $RC -eq 0 ]"
chk "ibus >= 1.5.32"                    'v=$(chroot "$ROOTFS" ibus version 2>/dev/null|awk "{print \$NF}"); [ -n "$v" ] && [ "$(printf "%s\n1.5.32\n" "$v"|sort -V|head -1)" = "1.5.32" ]'
chk "ibus-hangul installed"             'chroot "$ROOTFS" dpkg -l ibus-hangul 2>/dev/null | grep -q "^ii"'
chk "fonts-noto-cjk installed"          'chroot "$ROOTFS" dpkg -l fonts-noto-cjk 2>/dev/null | grep -q "^ii"'
chk "language-pack-ko installed"        'chroot "$ROOTFS" dpkg -l language-pack-ko 2>/dev/null | grep -q "^ii"'
chk "pop-im-ibus.sh removed"            '[ ! -f "$ROOTFS/etc/profile.d/pop-im-ibus.sh" ]'
chk "env GTK_IM_MODULE=ibus"            'grep -q "^GTK_IM_MODULE=ibus" "$ROOTFS/etc/environment"'
chk "env XMODIFIERS=@im=ibus"           'grep -q "^XMODIFIERS=@im=ibus" "$ROOTFS/etc/environment"'
chk "environment.d 90-korean-ime"       '[ -f "$ROOTFS/etc/environment.d/90-korean-ime.conf" ]'
chk "dconf 00-korean hangul source"     'grep -q "hangul" "$ROOTFS/etc/dconf/db/local.d/00-korean"'
chk "skel gtk-3.0 im=ibus"              'grep -q "gtk-im-module=ibus" "$ROOTFS/etc/skel/.config/gtk-3.0/settings.ini"'
chk "ibus autostart skel"               '[ -f "$ROOTFS/etc/skel/.config/autostart/ibus-daemon.desktop" ]'
chk "MOZ_ENABLE_WAYLAND=0 (XWayland)"   'grep -q "^MOZ_ENABLE_WAYLAND=0" "$ROOTFS/etc/environment"'
chk "JetBrains vmoptions snippet"       '[ -f "$ROOTFS/etc/skel/.config/JetBrains/korean.vmoptions.snippet" ]'

echo "======================================="
echo "L1 RESULT: pass=$pass fail=$fail  (rc=$RC)"
[ $fail -eq 0 ] && echo "L1 ALL PASS" || echo "L1 HAS FAILURES — fix before public claim"

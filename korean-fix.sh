#!/usr/bin/env bash
# korean-fix.sh — Pop!_OS 24.04 COSMIC (Wayland) 한글 입력/출력 완전 수정
#
# 두 용도 동시:
#   1) 기존 Pop!_OS 24.04 COSMIC 설치본에 바로 실행 (sudo bash korean-fix.sh)
#   2) ISO remaster 의 chroot 안에서 그대로 source (build-popos-cosmic.sh 가 호출)
#
# 근거 (조사 출처):
#   - Wayland preedit reset .......... GNOME/mutter#152 (COSMIC 은 자체 compositor 라 영향 작으나 동일류 위험)
#   - Threads/X/FB 첫글자 먹힘 ........ ibus/ibus#2226 (브라우저+사이트 draft.js 버그 → XWayland 로 최소화)
#   - COSMIC IME OOTB 깨짐 ........... pop-os/cosmic-session#185, cosmic-epoch#2262/#1246, pop#3826
#                                       (ibus 1.5.29 < 1.5.32 필요, /etc/profile.d/pop-im-ibus.sh 하드코드)
#   version: 0.1.0
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "sudo 로 실행: sudo bash korean-fix.sh"; exit 1; }
log(){ printf '\033[1;36m[korean-fix]\033[0m %s\n' "$*"; }

. /etc/os-release 2>/dev/null || true
log "base: ${PRETTY_NAME:-unknown}  (목표: Pop!_OS 24.04 COSMIC / Wayland)"

# ── 1. pop 의 IME 하드코드 스크립트 제거 (ibus 고정 + 입력기 전환 차단의 직접 원인) ──
for f in /etc/profile.d/pop-im-ibus.sh /etc/profile.d/pop-im-fcitx.sh; do
  if [ -f "$f" ]; then
    mv -f "$f" "${f}.disabled-by-korean-fix"
    log "비활성화: $f"
  fi
done

# ── 2. IME 스택 + CJK 폰트 + 한국어 로케일 설치 ──
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y --no-install-recommends \
  ibus ibus-hangul ibus-gtk ibus-gtk3 ibus-gtk4 \
  fonts-noto-cjk fonts-noto-cjk-extra \
  language-pack-ko language-pack-gnome-ko gnome-terminal \
  || log "일부 패키지 실패 — 계속 진행"

# ── 3. COSMIC 은 ibus >= 1.5.32 요구 (zwp_input_method_v2). 부족하면 plucky(25.04) 에서만 끌어옴 ──
need="1.5.32"
cur="$(ibus version 2>/dev/null | awk '{print $NF}' || echo 0)"
ver_ge(){ [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]; }
if ! ver_ge "$cur" "$need"; then
  log "ibus $cur < $need → plucky 에서 ibus 패키지만 업그레이드 (pin-priority 100, 안전)"
  echo 'deb http://archive.ubuntu.com/ubuntu plucky main universe' >/etc/apt/sources.list.d/plucky-ime.list
  printf 'Package: *\nPin: release n=plucky\nPin-Priority: 100\n' >/etc/apt/preferences.d/plucky-ime
  apt-get update -y || true
  apt-get install -y --no-install-recommends -t plucky \
    ibus ibus-gtk3 ibus-gtk4 ibus-hangul || log "plucky 실패 — VM 테스트 시 수동 .deb 검토"
  rm -f /etc/apt/sources.list.d/plucky-ime.list /etc/apt/preferences.d/plucky-ime
  apt-get update -y || true
  log "ibus 재확인: $(ibus version 2>/dev/null | awk '{print $NF}' || echo '?')"
fi

# ── 4. 시스템 전역 IME env (XWayland/Java/Qt/터미널 결정적; COSMIC systemd user 세션도 읽음) ──
mkdir -p /etc/environment.d
cat >/etc/environment.d/90-korean-ime.conf <<'EOF'
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
QT4_IM_MODULE=ibus
XMODIFIERS=@im=ibus
GLFW_IM_MODULE=ibus
SDL_IM_MODULE=ibus
EOF
# /etc/environment (PAM, 로그인 전역) — KEY=VALUE only, export 금지
for kv in GTK_IM_MODULE=ibus QT_IM_MODULE=ibus QT4_IM_MODULE=ibus \
          XMODIFIERS=@im=ibus GLFW_IM_MODULE=ibus SDL_IM_MODULE=ibus; do
  grep -q "^${kv%%=*}=" /etc/environment 2>/dev/null || echo "$kv" >>/etc/environment
done

# ── 5. 브라우저/Electron = XWayland 강제 (Wayland 네이티브 첫글자 버그 회피; 한글이 X11처럼 동작) ──
grep -q '^MOZ_ENABLE_WAYLAND=' /etc/environment || echo 'MOZ_ENABLE_WAYLAND=0' >>/etc/environment
echo 'export ELECTRON_OZONE_PLATFORM_HINT=x11' >/etc/profile.d/zz-electron-x11.sh
chmod 644 /etc/profile.d/zz-electron-x11.sh

# ── 6. GTK skel 기본값 (신규 유저 전부 ibus) ──
mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
printf '[Settings]\ngtk-im-module=ibus\n' >/etc/skel/.config/gtk-3.0/settings.ini
cp /etc/skel/.config/gtk-3.0/settings.ini /etc/skel/.config/gtk-4.0/settings.ini
printf 'gtk-im-module="ibus"\n' >/etc/skel/.gtkrc-2.0

# ── 7. 입력소스 + 한/영 토글 기본값 (GNOME dconf — pop 의 gnome 앱 + 호환 레이어 적용) ──
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
[ -f /etc/dconf/profile/user ] || printf 'user-db:user\nsystem-db:local\n' >/etc/dconf/profile/user
cat >/etc/dconf/db/local.d/00-korean <<'EOF'
[org/gnome/desktop/input-sources]
sources=[('xkb','us'),('ibus','hangul')]
xkb-options=['grp:alt_shift_toggle']

[desktop/ibus/general/hotkey]
triggers=['<Shift>space','Hangul','Caps_Lock']
EOF
dconf update || true

# ── 8. ibus-daemon 자동 시작 (COSMIC 세션) ──
mkdir -p /etc/skel/.config/autostart
cat >/etc/skel/.config/autostart/ibus-daemon.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=IBus
Exec=ibus-daemon -drxR
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# ── 9. IntelliJ/JetBrains 한글 fix (전 설치방법 공통: X11 강제 + XIM 재생성) ──
JB_SNIPPET='-Dawt.toolkit.name=XToolkit
-Drecreate.x11.input.method=true'
mkdir -p /etc/skel/.config/JetBrains
printf '%s\n' "$JB_SNIPPET" >/etc/skel/.config/JetBrains/korean.vmoptions.snippet
if command -v flatpak >/dev/null 2>&1; then
  for app in com.jetbrains.IntelliJ-IDEA-Ultimate com.jetbrains.IntelliJ-IDEA-Community \
             com.jetbrains.PyCharm-Professional com.jetbrains.PyCharm-Community; do
    flatpak override --env=GTK_IM_MODULE=ibus --env=QT_IM_MODULE=ibus --env=XMODIFIERS=@im=ibus \
      --socket=wayland --socket=fallback-x11 \
      --talk-name=org.freedesktop.portal.IBus "$app" 2>/dev/null || true
  done
  flatpak override --env=GTK_IM_MODULE=ibus --env=QT_IM_MODULE=ibus --env=XMODIFIERS=@im=ibus \
    --talk-name=org.freedesktop.portal.IBus 2>/dev/null || true
fi

# ── 10. snap IDE 경고 (snap 샌드박스 = IME 소켓 차단 = 한글 불가) ──
if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -qiE 'intellij|pycharm|code|webstorm'; then
  log "경고: snap IDE 감지 → snap 은 IME 소켓 차단으로 한글 안 됨. tarball/Toolbox 재설치 권장."
fi

log "완료. 재로그인 또는 재부팅 후 Shift+Space / 한/영 / CapsLock 로 한↔영 토글."
log "IntelliJ 는 Help > Edit Custom VM Options 에 아래 2줄 추가 (또는 korean.vmoptions.snippet 참고):"
printf '    %s\n' "$JB_SNIPPET"

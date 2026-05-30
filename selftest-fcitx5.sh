#!/usr/bin/env bash
# fcitx5 한글 자가검증 — autostart. 결과 → serial.
LOG=/tmp/kst.log
exec >"$LOG" 2>&1
ser(){ sudo cp "$LOG" /dev/ttyS0 2>/dev/null || true; }
echo "===== FCITX5 SELFTEST $(date) ====="
sleep 30
echo "## env:"; printenv | grep -E 'IM_MODULE|XMODIFIERS' | tr '\n' ' '; echo
# fcitx5 profile = hangul 기본
mkdir -p ~/.config/fcitx5
cat > ~/.config/fcitx5/profile <<'EOF'
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
pkill fcitx5 2>/dev/null; sleep 1
(fcitx5 -d --replace &) 2>/dev/null; sleep 6
fcitx5-remote -s hangul 2>/dev/null; sleep 1
echo "## fcitx5 procs = $(pgrep -c fcitx5)  current IM = $(fcitx5-remote -n 2>&1)"
echo "## libhangul:"; python3 /usr/local/bin/libhangul-test.py 2>&1 | grep -E 'composed|RESULT'
ser

echo "## ---- GTK Entry WAYLAND (wtype) ----"
fcitx5-remote -s hangul 2>/dev/null
python3 /usr/local/bin/gtk-ime-test.py wl & GP=$!
sleep 6
fcitx5-remote -s hangul 2>/dev/null
command -v wtype >/dev/null && wtype "dkssud" 2>/dev/null
wait $GP 2>/dev/null
echo "  WL: $(cat /tmp/imetest-wl.out 2>/dev/null || echo none)"
ser

echo "## ---- DEMO: 에디터에 한글 자동입력 후 화면에 남김 (host 캡처용) ----"
pkill -f gtk-ime-test 2>/dev/null; sleep 1
fcitx5-remote -s hangul 2>/dev/null
(env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx gnome-text-editor &) 2>/dev/null
sleep 9
fcitx5-remote -s hangul 2>/dev/null; sleep 1
wtype -d 230 "dkssudgktpdy " 2>/dev/null   # 안녕하세요
sleep 1
wtype -d 230 "zhtmalr " 2>/dev/null        # 코스믹
sleep 1
wtype -d 230 "gksrmf dlqfur tjdrhd" 2>/dev/null  # 한글 입력 성공
echo "===== SELFTEST END (editor left open, 한글 on screen) ====="; ser
sleep 1200

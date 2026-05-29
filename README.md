# popos-cosmic-korean

**Pop!_OS 24.04 LTS (COSMIC / Wayland) 에서 한글 입력이 안 되는 문제를 `sudo` 한 방으로 해결합니다.**

```bash
sudo bash korean-fix.sh   # 실행 후 재부팅(또는 재로그인)
```

이후 `Shift+Space` · `한/영` · `Caps Lock` 셋 중 아무거나로 한↔영 토글.

---

## 무슨 문제인가

Pop!_OS 24.04 의 새 데스크탑 **COSMIC** 은 Wayland 기반이라, 설치 직후(OOTB) 한글 입력이 깨져 있습니다. 거기에 Linux 한글의 고질병이 겹칩니다:

- 브라우저(Threads/X/Facebook)에서 **첫 글자가 사라짐**
- 터미널마다 **마지막 글자가 증발**하거나 한 키씩 밀림
- IntelliJ 등 IDE 에서 한글 안 됨 — **설치 방법(snap/flatpak/tarball/Toolbox)마다 증상이 다름**
- 같은 앱이라도 창/패널마다 됐다 안 됐다
- 입력기(ibus/fcitx5/kime)를 바꿔봐도 쉽게 안 됨

흔히 "리눅스 한글은 개발자도 다루기 어렵다"고 합니다. 맞는 말이지만, **원인을 정확히 알면 한 방에 잡힙니다.**

## 왜 어려운가 — 증상 9개, 근본 원인은 3개

1. **한글 preedit-commit 모델** — 한글은 한 번의 키 입력이 *음절을 완성(commit)하면서 동시에 다음 음절의 조합(preedit)을 시작*합니다. 일본어/중국어엔 없는 특성. Wayland 컴포지터와 웹 에디터(draft.js — Threads/X/Facebook)가 commit 직후 조합 상태를 리셋해버려 글자가 먹힙니다. ([GNOME/mutter#152](https://gitlab.gnome.org/GNOME/mutter/-/issues/152), [ibus/ibus#2226](https://github.com/ibus/ibus/issues/2226))
2. **입력기 환경변수 매트릭스** — `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS` … 가 툴킷·디스플레이서버마다 다르게 읽힙니다. 하나라도 어긋나면 그 앱만 조용히 한글이 안 됩니다.
3. **샌드박스 + JBR** — snap/flatpak 은 입력기 소켓을 막고, JetBrains 런타임(JBR)은 X11 입력 처리가 까다롭습니다. IntelliJ 가 설치 방법마다 다른 이유. **snap 으로 깐 IDE 는 한글이 원천적으로 안 됩니다.**

COSMIC 특유의 문제까지: 동봉된 ibus 가 너무 구버전(1.5.29 < 필요 1.5.32)이고, `/etc/profile.d/pop-im-ibus.sh` 가 입력기를 고정해 전환을 막습니다. ([pop-os/cosmic-session#185](https://github.com/pop-os/cosmic-session/issues/185), [cosmic-epoch#1246](https://github.com/pop-os/cosmic-epoch/issues/1246))

## `korean-fix.sh` 가 하는 일

| # | 조치 | 해결하는 증상 |
|---|---|---|
| 1 | `pop-im-ibus.sh` 입력기 하드코드 제거 | 입력기 전환/한글 OOTB 깨짐 |
| 2 | `ibus-hangul` + Noto CJK + 한국어 로케일 설치 | 한글 입력·표시 기본기 |
| 3 | ibus < 1.5.32 면 plucky(25.04)에서 ibus만 안전 업그레이드 | COSMIC Wayland 입력기 연결 |
| 4 | 전역 IME env (`/etc/environment` + `environment.d`) | 앱별 들쭉날쭉 |
| 5 | 브라우저/Electron 을 XWayland 강제 | Threads 첫글자 먹힘 최소화 |
| 6–8 | GTK skel · dconf 입력소스 · ibus 자동시작 기본값 | 신규 유저 OOTB 동작 |
| 9 | IntelliJ/JetBrains X11 강제(`XToolkit`) + flatpak override | IDE 한글 |
| 10 | snap IDE 경고 | snap 한글 불가 안내 |

## 사용법

```bash
git clone https://github.com/Hostingglobal-Tech/popos-cosmic-korean.git
cd popos-cosmic-korean
sudo bash korean-fix.sh
# 재부팅(또는 재로그인)
```

**IntelliJ** 는 추가로 `Help ▸ Edit Custom VM Options…` 에 두 줄:

```
-Dawt.toolkit.name=XToolkit
-Drecreate.x11.input.method=true
```

그리고 IDE 는 **snap 말고 tarball / JetBrains Toolbox / flatpak** 으로 설치하세요. (snap = 한글 불가)

## 정직한 한계

- **Threads/X/Facebook 첫 글자 먹힘**은 브라우저(Chromium) + 해당 사이트의 에디터(draft.js) 버그입니다([ibus#2226](https://github.com/ibus/ibus/issues/2226)). OS 가 100% 박멸할 수 없습니다. 이 스크립트는 브라우저를 XWayland 로 돌려 **크게 줄입니다.** 그래도 남으면 Firefox(XWayland) 사용 또는 영문/스페이스 한 칸 먼저 입력.
- COSMIC 은 빠르게 바뀌는 신생 데스크탑입니다. 환경에 따라 추가 조정이 필요할 수 있어 **이슈 리포트를 환영합니다.**

## 근거 (출처)

- [GNOME/mutter#152](https://gitlab.gnome.org/GNOME/mutter/-/issues/152) · [ibus/ibus#2226](https://github.com/ibus/ibus/issues/2226)
- [pop-os/cosmic-session#185](https://github.com/pop-os/cosmic-session/issues/185) · [cosmic-epoch#2262](https://github.com/pop-os/cosmic-epoch/issues/2262) · [#1246](https://github.com/pop-os/cosmic-epoch/issues/1246)
- [ArchWiki Localization/Korean](https://wiki.archlinux.org/title/Localization/Korean) · [Fcitx5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)

## License

[Apache-2.0](LICENSE)

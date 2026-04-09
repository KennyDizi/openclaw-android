# UX 스토리보드: 설정 (Settings)

> 시나리오: 사용자가 설정 탭에서 앱을 관리한다.
> 진입점: 탭 바 → ⚙ Settings
> 전체 화면: WebView

---

## 흐름 요약

```
S5.1 설정 메인 ─→ 플랫폼 관리 (→ 03-platform-management.md)
               ├→ 업데이트 (→ 04-update.md)
               ├→ S5.2 추가 도구 설치
               ├→ S5.3 Keep Alive (PPK 가이드)
               ├→ S5.4 스토리지
               └→ S5.5 앱 정보
```

---

## S5.1 설정 메인 [WebView]

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│  Settings                            │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  📱 Platforms              →   │  │
│  │  Manage installed platforms    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  🔄 Updates            •   →   │  │
│  │  1 update available            │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  🧰 Additional Tools      →   │  │
│  │  Install extra CLI tools       │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  ⚡ Keep Alive             →   │  │
│  │  Prevent background killing    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  💾 Storage                →   │  │
│  │  Manage disk usage             │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  ℹ About                  →   │  │
│  │  App info & licenses           │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 배지 | Updates에 업데이트 가능 시 빨간 점 |
| 각 행 탭 | 해당 상세 화면으로 이동 |
| 렌더링 | WebView `#/settings` 라우트 |

---

## S5.2 추가 도구 설치 [WebView + JsBridge]

CLI 도구를 개별적으로 설치/제거한다.

```
┌──────────────────────────────────────┐
│  ← Additional Tools                  │
├──────────────────────────────────────┤
│                                      │
│  Terminal Tools                      │
│  ┌────────────────────────────────┐  │
│  │  tmux              Installed ✓ │  │
│  │  Terminal multiplexer          │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  code-server        [Install]  │  │
│  │  VS Code in browser            │  │
│  └────────────────────────────────┘  │
│                                      │
│  AI CLI Tools                        │
│  ┌────────────────────────────────┐  │
│  │  Claude Code        [Install]  │  │
│  │  Anthropic AI CLI              │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Gemini CLI         [Install]  │  │
│  │  Google AI CLI                 │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Codex CLI          [Install]  │  │
│  │  OpenAI AI CLI                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  Network & Remote Access               │
│  ┌────────────────────────────────┐  │
│  │  openssh-server      [Install] │  │
│  │  SSH remote access              │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  ttyd                [Install] │  │
│  │  Web terminal access           │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  dufs                [Install] │  │
│  │  File server (WebDAV)          │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### 도구 설치 진행

```
┌──────────────────────────────────────┐
│  ← Installing Claude Code            │
├──────────────────────────────────────┤
│                                      │
│     Installing Claude Code...        │
│                                      │
│     ━━━━━━━━━━━━━━░░░░░░  65%       │
│                                      │
│     📦 npm install -g @anthropic/    │
│        claude-code                   │
│                                      │
│           [Cancel]                   │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 데이터 소스 | 하드코딩된 도구 목록 (CLI 프로젝트의 install 프롬프트 기반 + openssh-server 추가) |
| 설치 방법 | JsBridge → 셸 명령 (`pkg install`, `npm install -g`, 직접 다운로드) |
| 설치 상태 | JsBridge `OpenClaw.runCommand("which tmux")` 등으로 확인 |
| Installed 항목 탭 | [Uninstall] 옵션 표시 |

---

## S5.3 Keep Alive (PPK 가이드) [WebView]

Android의 Phantom Process Killer 비활성화를 안내한다.

```
┌──────────────────────────────────────┐
│  ← Keep Alive                        │
├──────────────────────────────────────┤
│                                      │
│  ⚡ Prevent Background Killing       │
│                                      │
│  Android may kill background         │
│  processes after a while. Follow     │
│  these steps to prevent it:          │
│                                      │
│  ──────────────────────────────────  │
│                                      │
│  1. Battery Optimization             │
│     ┌────────────────────────────┐   │
│     │ Status: ✓ Excluded         │   │
│     └────────────────────────────┘   │
│                                      │
│  2. Developer Options                │
│     • Enable Developer Options       │
│     • Enable "Stay Awake"            │
│     [Open Developer Options]         │
│                                      │
│  3. Phantom Process Killer           │
│     (Android 12+)                    │
│     • Connect USB + enable ADB       │
│     • Run this command on PC:        │
│     ┌────────────────────────────┐   │
│     │ adb shell device_config    │   │
│     │ set_sync_disabled_for_     │   │
│     │ tests activity_manager/    │   │
│     │ max_phantom_processes 2147 │   │
│     │ 483647            [Copy]   │   │
│     └────────────────────────────┘   │
│                                      │
│  4. Charge Limit (Optional)          │
│     Set to 80% for always-on use     │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| Battery Optimization | JsBridge로 현재 상태 확인. 미제외 시 [Request Exclusion] 버튼 |
| Developer Options | [Open Developer Options] → 시스템 설정으로 이동 (Intent) |
| ADB 명령 | [Copy] 버튼으로 클립보드 복사 |
| 자동 감지 | Battery Optimization 상태는 실시간 확인 가능. PPK는 감지 불가 (Android 제한) |

---

## S5.4 스토리지 [WebView + JsBridge]

디스크 사용량을 확인하고 정리한다.

```
┌──────────────────────────────────────┐
│  ← Storage                           │
├──────────────────────────────────────┤
│                                      │
│  Total used: 450 MB                  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  Bootstrap (usr/)     180 MB   │  │
│  │  ━━━━━━━━━━━━━━░░░░░░         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Runtime (node, git)  120 MB   │  │
│  │  ━━━━━━━━━━░░░░░░░░░░         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Platforms             80 MB   │  │
│  │  ━━━━━━━░░░░░░░░░░░░░         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Cache (apt, npm)      50 MB   │  │
│  │  ━━━━░░░░░░░░░░░░░░░░         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Web UI (www/)          2 MB   │  │
│  │  ━░░░░░░░░░░░░░░░░░░░         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  Other                 18 MB   │  │
│  │  ━░░░░░░░░░░░░░░░░░░░         │  │
│  └────────────────────────────────┘  │
│                                      │
│  [Clear Cache]   (50 MB)             │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 용량 계산 | JsBridge → `du -sh` 명령으로 각 디렉토리 크기 조회 |
| [Clear Cache] | apt 캐시 (`var/cache/apt/`) + npm 캐시 삭제 |
| 프로그레스 바 | 전체 대비 비율 시각화 |

---

## S5.5 앱 정보 [WebView]

```
┌──────────────────────────────────────┐
│  ← About                             │
├──────────────────────────────────────┤
│                                      │
│     🧠 OpenClaw on Android           │
│                                      │
│     Version                          │
│     APK: 1.0.0                       │
│     Web UI: 1.0.0                    │
│     Bootstrap: 2026.02.12-r1         │
│                                      │
│     Runtime                          │
│     Node.js: v22.14.0               │
│     git: 2.47.2                      │
│                                      │
│     ──────────────────────────────   │
│                                      │
│     License: GPL v3                  │
│     Source: github.com/AidanPark/    │
│             openclaw-android-app     │
│                                      │
│     [View on GitHub]                 │
│     [Open Source Licenses]           │
│                                      │
│     ──────────────────────────────   │
│                                      │
│     Made with ❤ for Android          │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 버전 정보 | APK 버전은 BuildConfig, WebUI/Bootstrap은 SharedPreferences |
| 런타임 정보 | JsBridge → `node -v`, `git --version` 실행 결과 |
| [View on GitHub] | 외부 브라우저로 레포 URL 열기 (Intent) |
| [Open Source Licenses] | 사용된 오픈소스 라이선스 목록 (Apache 2.0, GPL v3 등) |

---

## 기술 노트

### 설정 라우팅

```
#/settings                    ← 설정 메인 (S5.1)
#/settings/platforms          ← 플랫폼 관리 (→ 03-platform-management.md)
#/settings/updates            ← 업데이트 (→ 04-update.md)
#/settings/tools              ← 추가 도구 (S5.2)
#/settings/keep-alive         ← PPK 가이드 (S5.3)
#/settings/storage            ← 스토리지 (S5.4)
#/settings/about              ← 앱 정보 (S5.5)
```

### 설정 데이터 저장

```
SharedPreferences (Kotlin):
  active_platform = "openclaw"
  www_version = "1.0.0"
  bootstrap_version = "..."
  last_update_check = timestamp
  setup_completed = true

localStorage (WebView):
  settings_last_tab = "#/settings/tools"
  dismissed_update_badge = false
```

Kotlin SharedPreferences ↔ WebView localStorage는 독립. 
JsBridge를 통해 Kotlin 쪽 설정을 WebView에서 읽고 쓴다.

# UX 스토리보드: 플랫폼 관리 (Platform Management)

> 시나리오: 사용자가 에이전트 런타임을 추가, 전환, 또는 삭제한다.
> 진입점: 설정 탭 → Platforms 또는 대시보드 → 플랫폼 전환
> 전체 화면: WebView

---

## 흐름 요약

```
S3.1 플랫폼 목록 ─→ S3.2 플랫폼 추가 ─→ S3.3 설치 진행
                 ├→ S3.4 플랫폼 전환
                 └→ S3.5 플랫폼 삭제
```

---

## S3.1 플랫폼 목록 [WebView]

설정 탭에서 "Platforms" 섹션을 탭하면 설치된 플랫폼 목록을 표시한다.

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│  ← Platforms                         │
│                                      │
│  Installed                           │
│  ┌────────────────────────────────┐  │
│  │  🧠 OpenClaw          Active ✓ │  │
│  │  v1.0.4                        │  │
│  └────────────────────────────────┘  │
│                                      │
│  Available                           │
│  ┌────────────────────────────────┐  │
│  │  ⚡ Moltis             [Install]│  │
│  │  Fast AI assistant             │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  🔷 ZeroClaw           [Install]│  │
│  │  Multi-provider platform       │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 데이터 소스 | `OpenClaw.getInstalledPlatforms()` + `config.json`의 platforms 배열 |
| Installed | 설치된 플랫폼. Active 표시. 탭하면 상세/전환/삭제 옵션 |
| Available | 미설치 플랫폼. [Install] 버튼 |
| ← 뒤로 | 설정 메인으로 돌아감 |

---

## S3.2 플랫폼 추가 [WebView + JsBridge]

Available 섹션에서 [Install] 버튼을 탭한다.

```
┌──────────────────────────────────────┐
│  ← Install Moltis                    │
├──────────────────────────────────────┤
│                                      │
│     ⚡ Moltis                         │
│     Fast AI assistant                │
│                                      │
│     Moltis is a lightweight AI       │
│     agent platform optimized for     │
│     mobile devices.                  │
│                                      │
│     Size: ~50MB                      │
│     Requires: Node.js 22+           │
│                                      │
│     ┌────────────────────────────┐   │
│     │      [Install Moltis]      │   │
│     └────────────────────────────┘   │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 플랫폼 정보 | config.json에서 로드 — 설명, 크기 추정, 요구사항 |
| [Install Moltis] | → S3.3 (설치 진행) |
| JsBridge | `OpenClaw.installPlatform("moltis")` |

---

## S3.3 설치 진행 [WebView + JsBridge]

```
┌──────────────────────────────────────┐
│  ← Installing Moltis                 │
├──────────────────────────────────────┤
│                                      │
│     ⚡ Moltis                         │
│                                      │
│     ━━━━━━━━━━━━━░░░░░░░  55%       │
│                                      │
│     📦 Installing packages...        │
│                                      │
│     ┌────────────────────────────┐   │
│     │  > npm install -g moltis   │   │
│     │  > Resolving dependencies  │   │
│     │  > added 142 packages      │   │
│     └────────────────────────────┘   │
│                                      │
│           [Cancel]                   │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 진행률 | JsBridge 콜백으로 실시간 업데이트 |
| 로그 영역 | npm 출력 요약 표시 |
| [Cancel] | 설치 중단. 부분 설치 정리 |
| 완료 시 | "✓ Moltis installed!" + [Activate] + [Stay with OpenClaw] 선택 |

### 설치 완료

```
┌──────────────────────────────────────┐
│  ← Moltis Installed                  │
├──────────────────────────────────────┤
│                                      │
│     ✓ Moltis installed!              │
│                                      │
│     Would you like to switch to      │
│     Moltis now?                      │
│                                      │
│     [Activate Moltis]                │
│                                      │
│     [Stay with OpenClaw]             │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Activate Moltis] | 활성 플랫폼 전환 → 대시보드가 Moltis로 변경 |
| [Stay with OpenClaw] | 현재 플랫폼 유지. 나중에 전환 가능 |

---

## S3.4 플랫폼 전환 [WebView + JsBridge]

설치된 플랫폼 카드를 탭하면 상세 화면이 표시된다.

```
┌──────────────────────────────────────┐
│  ← OpenClaw                          │
├──────────────────────────────────────┤
│                                      │
│     🧠 OpenClaw                      │
│     v1.0.4                           │
│     Status: Active ✓                 │
│                                      │
│     ──────────────────────────────   │
│                                      │
│     [Open Terminal]                  │
│        Run openclaw commands         │
│                                      │
│     [Deactivate]                     │
│        Switch to another platform    │
│                                      │
│     [Uninstall]                      │
│        Remove OpenClaw               │
│                                      │
└──────────────────────────────────────┘
```

### 비활성 플랫폼의 상세 화면

```
┌──────────────────────────────────────┐
│  ← Moltis                            │
├──────────────────────────────────────┤
│                                      │
│     ⚡ Moltis                         │
│     v2.1.0                           │
│     Status: Installed                │
│                                      │
│     ──────────────────────────────   │
│                                      │
│     [Activate]                       │
│        Set as active platform        │
│                                      │
│     [Uninstall]                      │
│        Remove Moltis                 │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Activate] | JsBridge `OpenClaw.runCommand("openclaw platform switch moltis")` |
| 전환 효과 | 대시보드 내용 변경, 터미널 프롬프트는 유지 |
| 전환 시간 | 즉각 (설정 파일 변경만 필요) |

---

## S3.5 플랫폼 삭제 [WebView + JsBridge]

[Uninstall] 탭 시 확인 다이얼로그 표시.

```
┌──────────────────────────────────────┐
│                                      │
│  ┌────────────────────────────────┐  │
│  │                                │  │
│  │  Uninstall Moltis?             │  │
│  │                                │  │
│  │  This will remove Moltis and   │  │
│  │  all its data. This cannot be  │  │
│  │  undone.                       │  │
│  │                                │  │
│  │  [Cancel]      [Uninstall]     │  │
│  │                                │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Cancel] | 다이얼로그 닫기 |
| [Uninstall] | JsBridge → `npm uninstall -g moltis` + 데이터 삭제 |
| 활성 플랫폼 삭제 시 | "You need to switch to another platform first." 경고 |
| 마지막 플랫폼 삭제 시 | 삭제 허용. 대시보드는 "No platform installed" 상태 |

### 삭제 완료

```
┌──────────────────────────────────────┐
│  ← Platforms                         │
├──────────────────────────────────────┤
│                                      │
│  ✓ Moltis has been uninstalled.      │
│                                      │
│  Installed                           │
│  ┌────────────────────────────────┐  │
│  │  🧠 OpenClaw          Active ✓ │  │
│  └────────────────────────────────┘  │
│                                      │
│  Available                           │
│  ┌────────────────────────────────┐  │
│  │  ⚡ Moltis             [Install]│  │
│  └────────────────────────────────┘  │
│  ...                                 │
│                                      │
└──────────────────────────────────────┘
```

---

## 기술 노트

### 플랫폼 상태 관리

```
SharedPreferences:
  active_platform = "openclaw"
  installed_platforms = ["openclaw", "moltis"]

files/home/.openclaw-android/.platform = "openclaw"   ← CLI 호환
```

### 플랫폼 전환 시 동작

1. SharedPreferences `active_platform` 업데이트
2. `.platform` 마커 파일 업데이트
3. 대시보드 WebView 리로드 (새 플랫폼 정보 반영)
4. 터미널 세션은 유지 (사용자가 직접 새 플랫폼 명령 실행)

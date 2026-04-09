# UX 스토리보드: 업데이트 (Update)

> 시나리오: 앱이 업데이트를 감지하고 OTA로 적용한다.
> 진입점: 자동 확인 (앱 시작 시) 또는 수동 확인 (설정 → Updates)
> 전체 화면: WebView (설정 탭 내)

---

## 흐름 요약

```
S4.1 자동 확인 (백그라운드) ─→ S4.2 배지 알림
                                    │
S4.3 수동 확인 (설정) ──────────────┤
                                    ▼
                              S4.4 업데이트 상세
                                    │
                    ┌───────────────┼────────────────┐
                    ▼               ▼                ▼
              S4.5 WebUI      S4.6 Bootstrap    S4.7 런타임
              업데이트         업데이트           업데이트
```

---

## S4.1 자동 업데이트 확인 [System]

앱 시작 시 백그라운드에서 업데이트를 확인한다. UI를 차단하지 않는다.

```
(사용자에게 보이지 않음)

시스템 동작:
  1. config.json URL에서 최신 설정 다운로드
  2. 현재 www 버전 vs 원격 www 버전 비교
  3. 현재 bootstrap 버전 vs 원격 bootstrap 버전 비교
  4. 업데이트 사용 가능 시 → 설정 탭 배지 표시
```

| 항목 | 설명 |
|------|------|
| 주기 | 앱 시작 시 1회. 앱이 포그라운드에 있는 동안 24시간마다 재확인 |
| 네트워크 | Wi-Fi일 때만 확인 (모바일 데이터 절약) |
| 실패 시 | 무시. 다음 앱 시작 시 재시도 |
| 강제 확인 | 설정 → Updates → [Check now] |

---

## S4.2 업데이트 알림 (배지) [WebView]

업데이트가 사용 가능하면 설정 탭에 배지를 표시한다.

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard] [⚙ •] │  ← 빨간 점
├──────────────────────────────────────┤
│  ...                                 │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 배지 | 설정 탭 아이콘 옆 빨간 점 |
| 비침습적 | 토스트, 팝업, 풀스크린 알림 없음. 사용자가 설정 탭을 열 때 확인 |
| 배지 소멸 | 업데이트 적용 또는 설정 → Updates에서 "나중에" 선택 시 |

---

## S4.3 업데이트 화면 (설정 내) [WebView]

설정 탭 → Updates 섹션.

### 업데이트 없음

```
┌──────────────────────────────────────┐
│  ← Updates                           │
├──────────────────────────────────────┤
│                                      │
│     ✓ Everything is up to date       │
│                                      │
│     Last checked: 5 minutes ago      │
│                                      │
│     [Check now]                      │
│                                      │
│     ──────────────────────────────   │
│                                      │
│     Current versions:                │
│     • Web UI: 1.0.0                  │
│     • Bootstrap: 2026.02.12-r1       │
│     • Node.js: 22.14.0              │
│     • openclaw: 1.0.4               │
│                                      │
└──────────────────────────────────────┘
```

### 업데이트 있음

```
┌──────────────────────────────────────┐
│  ← Updates                           │
├──────────────────────────────────────┤
│                                      │
│     Updates available                │
│                                      │
│     ┌────────────────────────────┐   │
│     │  🎨 Web UI                  │   │
│     │  1.0.0 → 1.1.0             │   │
│     │  • Improved dashboard      │   │
│     │  • New settings page       │   │
│     │  Size: ~1MB                │   │
│     │             [Update]       │   │
│     └────────────────────────────┘   │
│                                      │
│     ┌────────────────────────────┐   │
│     │  📦 Runtime packages        │   │
│     │  openclaw: 1.0.4 → 1.0.5  │   │
│     │  • Bug fixes               │   │
│     │             [Update]       │   │
│     └────────────────────────────┘   │
│                                      │
│     [Update All]                     │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 개별 업데이트 | 각 컴포넌트별 [Update] 버튼 |
| [Update All] | 모든 업데이트 순차 적용 |
| 변경 내용 | config.json의 changelog 필드에서 로드 |
| [Check now] | 수동 업데이트 확인 |

---

## S4.4 WebUI 업데이트 적용 [WebView + JsBridge]

www.zip을 다운로드하고 교체한다. **앱 재시작 불필요.**

```
┌──────────────────────────────────────┐
│  ← Updating Web UI                   │
├──────────────────────────────────────┤
│                                      │
│     🎨 Updating Web UI...            │
│                                      │
│     ━━━━━━━━━━━━━━━░░░░░  70%       │
│                                      │
│     📥 Downloading... (0.7/1.0 MB)   │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 단계 | 동작 |
|------|------|
| 1. 다운로드 | www.zip 다운로드 (~1MB) |
| 2. 검증 | SHA256 해시 검증 |
| 3. 추출 | www-staging/ 에 추출 |
| 4. 교체 | www/ → www-backup/, www-staging/ → www/ |
| 5. 리로드 | `webView.reload()` — 무중단 |
| 6. 정리 | www-backup/ 삭제 |

### 완료

```
┌──────────────────────────────────────┐
│  ← Updates                           │
├──────────────────────────────────────┤
│                                      │
│     ✓ Web UI updated to 1.1.0        │
│                                      │
│     Changes applied immediately.     │
│     No restart needed.               │
│                                      │
│     [Done]                           │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 무중단 | WebView reload로 즉시 반영. 터미널 세션 유지 |
| 실패 시 | www-backup/에서 자동 롤백. "Update failed. Rolled back." 표시 |

---

## S4.5 Bootstrap 업데이트 적용 [WebView + JsBridge]

새 bootstrap ZIP을 다운로드하고 재추출한다. **앱 재시작 필요.**

```
┌──────────────────────────────────────┐
│  ← Updating Bootstrap                │
├──────────────────────────────────────┤
│                                      │
│     📦 Updating Bootstrap...         │
│                                      │
│     ━━━━━━━━━━━━░░░░░░░░  50%       │
│                                      │
│     📥 Downloading... (12/25 MB)     │
│                                      │
│     ⚠ App will restart after         │
│       this update.                   │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

### 완료 → 재시작 안내

```
┌──────────────────────────────────────┐
│  ← Bootstrap Updated                 │
├──────────────────────────────────────┤
│                                      │
│     ✓ Bootstrap updated!             │
│                                      │
│     The app needs to restart to      │
│     apply the new bootstrap.         │
│                                      │
│     Running processes will be        │
│     stopped.                         │
│                                      │
│     [Restart Now]    [Later]         │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Restart Now] | 앱 프로세스 종료 + 재시작. 터미널 세션 종료됨 |
| [Later] | 다음 앱 시작 시 자동 적용 |
| 재시작 후 | 새 bootstrap으로 자동 재설정. 런타임 패키지 재확인 |

---

## S4.6 런타임 업데이트 적용 [WebView + JsBridge]

Node.js, git, 플랫폼 패키지를 업데이트한다.

```
┌──────────────────────────────────────┐
│  ← Updating Runtime                  │
├──────────────────────────────────────┤
│                                      │
│     📦 Updating packages...          │
│                                      │
│     ━━━━━━━━━━━━━━━━░░░░  75%       │
│                                      │
│     Updating openclaw...             │
│     1.0.4 → 1.0.5                    │
│                                      │
│     ┌────────────────────────────┐   │
│     │  > npm update -g openclaw  │   │
│     │  > updated 1 package       │   │
│     └────────────────────────────┘   │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 시스템 동작 | JsBridge → 셸 명령 실행 (`npm update`, `apt upgrade` 등) |
| 재시작 | 불필요. 다음 명령 실행 시 새 버전 사용 |
| 게이트웨이 | 실행 중이면 재시작 권고 메시지 표시 |

---

## 에러 케이스 종합

| 에러 | 발생 시점 | 복구 |
|------|----------|------|
| 다운로드 실패 | S4.4, S4.5 | [Retry]. 원래 버전 유지 |
| SHA256 불일치 | S4.4, S4.5 | "File corrupted. Please try again." → [Retry] |
| 디스크 부족 | S4.4, S4.5 | "Not enough space." → 필요 용량 표시 |
| WebView 리로드 실패 | S4.4 | www-backup에서 자동 롤백 |
| npm update 실패 | S4.6 | 에러 로그 표시 + [Retry] |

---

## 기술 노트

### 업데이트 확인 로직

```kotlin
class UpdateChecker(private val context: Context) {
    suspend fun check(): List<UpdateInfo> {
        val remote = downloadConfig("https://...config.json")
        val updates = mutableListOf<UpdateInfo>()

        if (remote.www.version > local.wwwVersion)
            updates.add(UpdateInfo("www", remote.www))
        if (remote.bootstrap.version > local.bootstrapVersion)
            updates.add(UpdateInfo("bootstrap", remote.bootstrap))

        return updates
    }
}
```

### 버전 추적

```
SharedPreferences:
  www_version = "1.0.0"
  bootstrap_version = "bootstrap-2026.02.12-r1+apt.android-7"
  last_update_check = 1709654400000  (timestamp)
```

# UX 스토리보드: 일상 사용 (Daily Use)

> 시나리오: 첫 실행을 완료한 사용자가 앱을 일상적으로 사용한다.
> 전제 조건: 첫 실행 완료, 플랫폼 설치됨, 온보딩 완료

---

## 흐름 요약

```
S2.1 앱 실행 (마지막 탭 복원) → S2.2 터미널 / S2.3 대시보드
                                   ↑↓ S2.4 탭 전환 (자유)
S2.5 백그라운드 전환 → S2.6 알림 및 배지 → S2.7 PC 대시보드 접근
```

---

## S2.1 앱 실행 [Native + WebView]

사용자가 앱 아이콘을 탭하여 앱을 실행한다.

```
┌──────────────────────────────────────┐
│                                      │
│            🧠 OpenClaw               │
│              ⟳                       │
│                                      │
└──────────────────────────────────────┘
         │  (~0.5초)
         ▼
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│  $ _                                 │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 시스템 동작 | ① SharedPreferences에서 마지막 활성 탭 읽기 ② FGS 시작 ③ 해당 탭 표시 |
| 복원 | 터미널 세션이 이미 살아 있으면 기존 세션 복원. 죽었으면 새 셸 시작 |
| 전환 | → 마지막 활성 탭 (기본: Terminal) |
| 백그라운드 체크 | 업데이트 자동 확인 (비동기, UI 차단 없음) |

---

## S2.2 터미널 탭 [Native TerminalView]

풀 PTY 터미널. 사용자가 명령을 실행하고 AI 에이전트와 상호작용한다.

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│  [1: sh ✕] [2: gateway ✕]     [＋]  │  ← 세션 탭 (Native)
├──────────────────────────────────────┤
│  $ openclaw gateway                  │
│                                      │
│  🧠 OpenClaw Gateway v1.0.4         │
│  Dashboard: http://localhost:3000    │
│                                      │
│  Listening for connections...        │
│  ✓ Agent ready                       │
│                                      │
│                                      │
│                                      │
├──────────────────────────────────────┤
│  ⌨ 키보드                            │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 렌더링 | **Native** — TerminalView (terminal-view 모듈, libtermux.so PTY) |
| 기능 | 풀 PTY 셸 — git, node, npm, openclaw, claude, gemini 등 모든 CLI 도구 |
| 키보드 | Android 소프트 키보드 + 특수키 바 (Ctrl, Alt, Tab, Esc 등) |
| 복사/붙여넣기 | 길게 누르기 → 텍스트 선택 → 시스템 복사 |
| 스크롤 | 위로 스와이프 → 터미널 히스토리 스크롤 |
| 탭 전환 | 상단 탭 바 탭 → Dashboard 또는 Settings로 전환 |
| 멀티 세션 | 세션 탭 바로 여러 터미널 세션 생성·전환·종료. `TerminalView.attachSession()` API |

### 특수키 바

```
┌──────────────────────────────────────┐
│ ESC │ TAB │ CTRL│ ALT │ ← │ → │ ↑ │ ↓ │
└──────────────────────────────────────┘
     (터미널 활성 시 키보드 위에 표시)
```

| 항목 | 설명 |
|------|------|
| 구현 | Native View (WebView 아님 — 터미널 탭 전용) |
| 표시 조건 | 소프트 키보드가 올라와 있을 때만 표시 |
| Ctrl+C | 현재 프로세스 인터럽트 |

### 멀티 세션 관리

하나의 `TerminalView`에 여러 `TerminalSession`을 연결하여 멀티 세션을 지원한다.
Termux의 검증된 패턴(`TerminalView.attachSession()`)을 그대로 사용한다.

#### 세션 탭 바

```
┌──────────────────────────────────────┐
│  [1: sh ✕] [2: gateway ✕]     [＋]  │
└──────────────────────────────────────┘
     현재 세션 하이라이트 (밑줄 또는 배경색)
```

| 항목 | 설명 |
|------|------|
| 위치 | 메인 탭 바 아래, 터미널 영역 위 (Native View) |
| 표시 조건 | Terminal 탭 활성 시에만 표시. Dashboard/Settings에서는 숨김 |
| 세션 이름 | 번호 + 실행 중인 명령어 (sh, gateway, node 등). 자동 감지 |
| 현재 세션 | 밑줄 또는 배경색 하이라이트 |
| 최대 세션 | 제한 없음 (실제로는 메모리 제약, 5-10개 권장) |
| 오버플로우 | 탭이 화면을 넘으면 수평 스크롤 |

#### 세션 생성 [＋]

```
사용자: [＋] 버튼 탭
  → TerminalSessionManager.createSession()
  → 새 TerminalSession 생성 (sh 셸)
  → sessions 리스트에 추가
  → attachSession(newSession) → 새 세션으로 전환
  → 세션 탭 바 업데이트 (새 탭 추가 + 하이라이트)
```

#### 세션 전환

```
사용자: 세션 탭 [1: sh] 탭
  → TerminalSessionManager.switchSession(index=0)
  → terminalView.attachSession(sessions[0])
  → TerminalView가 해당 세션의 emulator 상태를 렌더링
  → 이전 세션의 프로세스는 계속 실행 (PTY 유지)
  → 전환 시간: 즉각 (~10ms, 화면 다시 그리기만)
```

| 항목 | 설명 |
|------|------|
| 세션 유지 | 비활성 세션의 프로세스는 백그라운드에서 계속 실행 |
| 출력 버퍼 | 비활성 세션의 출력도 `TerminalEmulator` 버퍼에 계속 쌓임 |
| 전환 시 복원 | 전환하면 해당 세션의 전체 화면 상태 (스크롤 위치, 커서) 복원 |

#### 세션 닫기 [✕]

```
사용자: 세션 탭의 [✕] 탭
  → session.finishIfRunning() → SIGKILL
  → sessions 리스트에서 제거
  → 인접 세션으로 자동 전환 (왼쪽 우선)
  → 마지막 세션 닫기 시: 새 세션 자동 생성
```

| 항목 | 설명 |
|------|------|
| 실행 중 프로세스 | 닫기 전 확인 없음 (Termux 동일 동작). 프로세스 즉시 종료 |
| 마지막 세션 | 모든 세션이 닫히면 새 sh 세션 자동 생성 (빈 터미널 방지) |
| 앱 시작 시 | 세션 없으면 sh 세션 1개 자동 생성 |

#### 일반적 사용 패턴

```
세션 1: $ openclaw gateway          ← 게이트웨이 실행 (장기 실행)
세션 2: $ git status                ← 일반 작업
세션 3: $ claude                    ← AI CLI 도구
```

기존 CLI(Termux)에서 사용자는 **☰ → NEW SESSION**으로 여러 탭을 열었다.
이 패턴을 세션 탭 바로 동일하게 지원한다.
---

## S2.3 대시보드 탭 [WebView]

플랫폼의 상태와 제어 패널. 게이트웨이 URL, 연결 상태 등을 표시한다.

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│                                      │
│     🧠 OpenClaw                      │
│     Status: ✓ Running                │
│                                      │
│     ┌────────────────────────────┐   │
│     │  Gateway                   │   │
│     │  http://localhost:3000     │   │
│     │                    [Copy]  │   │
│     └────────────────────────────┘   │
│                                      │
│     ┌────────────────────────────┐   │
│     │  Quick Actions             │   │
│     │                            │   │
│     │  [▶ Start Gateway]         │   │
│     │  [⏹ Stop Gateway]          │   │
│     │  [🔄 Restart]              │   │
│     └────────────────────────────┘   │
│                                      │
│     Runtime                          │
│     Node.js: v22.14.0               │
│     git: 2.47.2                      │
│     openclaw: 1.0.4                  │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 렌더링 | **WebView** — `www/dashboard/index.html` |
| 데이터 소스 | JsBridge `OpenClaw.getBootstrapStatus()`, `OpenClaw.getInstalledPlatforms()` |
| [Copy] | Gateway URL을 클립보드에 복사 (JsBridge → `clipboardManager`) |
| Quick Actions | JsBridge `OpenClaw.runCommand()` 호출 |
| 상태 폴링 | 5초 간격으로 `OpenClaw.getBootstrapStatus()` 호출하여 상태 갱신 |

### 게이트웨이 미실행 상태

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│                                      │
│     🧠 OpenClaw                      │
│     Status: ⏸ Not running            │
│                                      │
│     Gateway is not running.          │
│     Start it from Terminal:          │
│                                      │
│     ┌────────────────────────────┐   │
│     │  $ openclaw gateway        │   │
│     └────────────────────────────┘   │
│                                      │
│     [Open Terminal]                  │
│                                      │
└──────────────────────────────────────┘
```

---

## S2.4 탭 전환

### Terminal → Dashboard

```
사용자: [📊 Dashboard] 탭 탭
  → WebView JS가 JsBridge 호출 (또는 탭 바 이벤트 직접 처리)
  → Kotlin: terminalView.visibility = GONE
  → Kotlin: webView.visibility = VISIBLE
  → WebView: #/dashboard 경로 로드
  → 전환 시간: 즉각 (~50ms)
```

### Dashboard → Terminal

```
사용자: [🖥 Terminal] 탭 탭
  → JsBridge: OpenClaw.showTerminal()
  → Kotlin: webView.visibility = GONE
  → Kotlin: terminalView.visibility = VISIBLE
  → 터미널 세션 그대로 유지 (PTY 프로세스 살아 있음)
  → 전환 시간: 즉각 (~50ms)
```

| 항목 | 설명 |
|------|------|
| 세션 유지 | 터미널 세션은 탭 전환 시 유지. 프로세스 계속 실행 |
| WebView 유지 | WebView도 GONE 상태에서 유지. 돌아오면 상태 그대로 |
| 키보드 | Terminal→다른 탭: 키보드 자동 숨김. 다른 탭→Terminal: 키보드 자동 표시 안함 (사용자가 터미널 탭) |

---

## S2.5 백그라운드 전환 및 복귀

### 앱 → 백그라운드 (Home 버튼)

```
사용자: Home 버튼 누름
  → [System] Activity onPause → onStop
  → [System] FGS 계속 실행 (알림 표시)
  → 터미널 프로세스 계속 실행 (PTY 유지)
```

### 백그라운드 → 앱 복귀

```
사용자: 앱 아이콘 또는 알림 탭
  → Activity onRestart → onStart → onResume
  → 마지막 탭 상태 복원
  → 터미널 출력 버퍼 표시 (백그라운드 동안 쌓인 출력)
```

### FGS 알림

```
┌──────────────────────────────────────┐
│  🧠 OpenClaw                         │
│  Running — tap to return             │
└──────────────────────────────────────┘
       (알림 바에 상시 표시)
```

| 항목 | 설명 |
|------|------|
| 알림 내용 | "Running — tap to return" (탭하면 앱으로 복귀) |
| Phantom Process Killer | Android 12+에서 백그라운드 프로세스 종료 가능. PPK 비활성화 안내 → 설정 시나리오 참고 |

### 프로세스 강제 종료 후 복귀

```
사용자: 앱 복귀 (프로세스가 죽은 상태)
  → Activity 재생성
  → setup_completed = true → 메인 화면 표시
  → 터미널 세션 없음 → 새 셸 시작 ("$ _")
  → 게이트웨이 등 이전 프로세스는 재시작 필요
```

---

## S2.6 알림 및 배지

### 업데이트 사용 가능

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard] [⚙ •] │  ← 빨간 점 배지
├──────────────────────────────────────┤
│  ...                                 │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 배지 표시 | 백그라운드 업데이트 확인에서 새 버전 발견 시 |
| 배지 소멸 | 설정 탭 열면 배지 제거 |
| 비침습적 | 현재 작업 중단 없음. 사용자가 원할 때 업데이트 |

---

## S2.7 PC에서 대시보드 접근

OpenClaw 대시보드 (`http://localhost:3000`)는 폰에서 로컬로 실행된다.
PC에서 접근하려면 네트워크 연결이 필요하다.

### 방법 1: SSH 터널 (권장)

폰에 SSH 서버가 설치되어 있으면, PC에서 SSH 터널로 대시보드에 접근한다.

```
# PC에서 실행
ssh -L 3000:localhost:3000 -p 8022 <폰 IP>

# 브라우저에서 접근
http://localhost:3000
```

| 항목 | 설명 |
|------|------|
| 전제 조건 | 폰에 openssh 설치 필요 (설정 → 추가 도구에서 openssh-server 설치 또는 터미널에서 `pkg install openssh`) + `sshd` 실행 |
| 보안 | SSH 암호화 터널 — 안전 |
| 안내 위치 | 설정 → Keep Alive 또는 대시보드 → 도움말 |

### 방법 2: 같은 Wi-Fi 네트워크 직접 접근

게이트웨이를 `0.0.0.0`으로 바인딩하면 같은 네트워크의 PC에서 직접 접근 가능.

```
# 폰에서 (게이트웨이 시작 시 옵션 또는 플랫폼 설정으로 바인딩 주소 변경)
# PC 브라우저에서
http://<폰 IP>:3000
```

| 항목 | 설명 |
|------|------|
| 전제 조건 | 같은 Wi-Fi 네트워크, 방화벽 허용 |
| 보안 | 비암호화 — 신뢰 네트워크에서만 사용 |

### 방법 3: ttyd (웹 터미널)

ttyd가 설치되어 있으면 PC 브라우저에서 터미널 자체에 접근 가능.

```
# 폰 터미널에서
ttyd -p 7681 bash

# PC 브라우저에서
http://<폰 IP>:7681
```

### Dashboard Connect 도구

여러 디바이스를 관리하는 경우, [Dashboard Connect](https://myopenclawhub.com) 웹 도구를 사용한다.

| 항목 | 설명 |
|------|------|
| 기능 | 디바이스별 연결 설정 (IP, 토큰, 포트) 저장, SSH 터널 명령 자동 생성 |
| 데이터 | 브라우저 localStorage에만 저장, 서버 전송 없음 |
| 기존 CLI | 현재 CLI 프로젝트 README에서 이미 안내 중. APK에서도 동일하게 활용 |
---

## 기술 노트

### 터미널 세션 관리

```kotlin
class TerminalSessionManager(
    private val terminalView: TerminalView,
    private val sessionClient: TerminalSessionClient
) {
    private val sessions = mutableListOf<TerminalSession>()
    private var currentIndex = -1

    fun createSession(name: String? = null): TerminalSession {
        val shell = "${prefix}/bin/sh"
        val env = buildEnvironment()  // §2.2.5 환경변수
        val session = TerminalSession(shell, cwd, args, env, sessionClient)
        sessions.add(session)
        switchSession(sessions.size - 1)
        return session
    }

    fun switchSession(index: Int) {
        if (index < 0 || index >= sessions.size) return
        currentIndex = index
        terminalView.attachSession(sessions[index])  // 핵심 API
    }

    fun removeSession(index: Int) {
        if (index < 0 || index >= sessions.size) return
        sessions[index].finishIfRunning()
        sessions.removeAt(index)
        when {
            sessions.isEmpty() -> createSession()  // 마지막 세션 → 새 세션 자동 생성
            currentIndex >= sessions.size -> switchSession(sessions.size - 1)
            else -> switchSession(currentIndex.coerceAtMost(sessions.size - 1))
        }
    }

    fun getSessions(): List<TerminalSession> = sessions
    fun getCurrentIndex(): Int = currentIndex
}
```

### WebView 라우팅

```
www/index.html          ← SPA 엔트리포인트
  #/dashboard           ← 대시보드 탭
  #/settings            ← 설정 탭
  #/platforms           ← 플랫폼 선택기
  #/setup/*             ← 첫 실행 셋업 (재진입 시)
```

Hash-based 라우팅 사용 — `file:///` 프로토콜에서 History API 호환 이슈 방지.

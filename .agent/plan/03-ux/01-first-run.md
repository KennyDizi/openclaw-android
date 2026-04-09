# UX 스토리보드: 첫 실행 (First Run)

> 시나리오: 사용자가 APK를 설치하고 처음으로 앱을 실행한다.
> 소요 시간: 5-10분 (네트워크 속도 의존)
> 전제 조건: 인터넷 연결 필수, 약 200MB 여유 스토리지

---

## 흐름 요약

```
S1.1 스플래시 → S1.2 네트워크 확인 → S1.3 환경 셋업 (마일스톤 UI)
→ S1.4 플랫폼 선택 → S1.5 플랫폼 설치 (마일스톤 UI)
→ S1.6 온보딩 안내 → S1.7 터미널 Ready
```

**렌더링 전환점**: S1.1~S1.3은 **Native**, S1.4부터 **WebView** (www.zip 다운로드 완료 후)

---

## 마일스톤 UI 설계 원칙

### 문제 정의

초기 세팅에 5-10분이 소요된다. 단순 프로그레스 바만 보여주면:
- 사용자가 "얼마나 더 걸리는지" 모름 → 불안감
- 무엇이 진행 중인지 모름 → "멈춘 건가?" 의심
- 긴 대기 시간에 지루함 → 이탈

### 핵심 전략

| 전략 | 적용 방법 |
|------|----------|
| **Stepper (마일스톤 트래커)** | 화면 상단에 전체 단계를 시각화. 완료 ✓, 진행 중 ●, 대기 ○ |
| **예상 시간 표시** | 각 단계에 예상 소요 시간, 화면 하단에 전체 남은 시간 |
| **세부 상태 텍스트** | "Downloading bootstrap..." → "Extracting files..." 등 실시간 변경 |
| **도달감 (Momentum)** | 빠른 단계를 먼저 배치하여 초반에 체크마크가 빠르게 쌓이도록 |
| **컨텍스트 제공** | 각 단계가 왜 필요한지 한 줄 설명 |
| **인터럽트 안전** | 앱 종료/재시작 시 마지막 완료 단계부터 재개 |

### Stepper 컴포넌트

```
  ✓ Download       ● Extract       ○ Runtime       ○ UI
  ━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━○━━━━━━━━━━━━━━━○
```

상태별 시각 표현:
- `✓` 완료 (체크마크, 초록색)
- `●` 진행 중 (채워진 원, 파란색, 펄스 애니메이션)
- `○` 대기 (빈 원, 회색)
- `━` 연결선 (완료: 초록, 진행 중: 파란 그라데이션, 대기: 회색)

---

## S1.1 스플래시 [Native]

사용자가 앱 아이콘을 탭하여 앱을 처음 실행한다.

```
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│              ⟳                       │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 지속 시간 | 1-2초 (초기화 완료까지) |
| 시스템 동작 | `files/usr/` 존재 여부 확인. 없으면 → S1.2. 있으면 → 메인 화면 (재실행) |
| 전환 | → S1.2 (첫 실행), → 메인 화면 (재실행) |

---

## S1.2 네트워크 확인 [Native]

Bootstrap 다운로드를 위해 네트워크 상태를 확인한다.

### 정상 (네트워크 있음) → 자동으로 S1.3 진행

사용자에게 별도 화면을 보여주지 않고 S1.3으로 즉시 전환.

### 에러 (네트워크 없음)

```
┌──────────────────────────────────────┐
│                                      │
│            🧠 OpenClaw               │
│                                      │
│     ⚠ No internet connection         │
│                                      │
│     OpenClaw needs to download       │
│     additional files (~50MB) for     │
│     initial setup.                   │
│                                      │
│     Please connect to Wi-Fi or       │
│     enable mobile data.              │
│                                      │
│          [Retry]                     │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 사용자 액션 | [Retry] 탭 → 네트워크 재확인 |
| 자동 감지 | 네트워크 연결되면 자동으로 S1.3 진행 (ConnectivityManager 콜백) |
| 전환 | 네트워크 연결 시 → S1.3 |

---

## S1.3 환경 셋업 [Native — 마일스톤 UI]

네트워크 셋업 후 환경을 구성하는 **통합 셋업 화면**. 4개 마일스톤을 하나의 화면에서 순차 진행한다.

### 마일스톤 정의

| # | 마일스톤 | 내용 | 예상 크기 | 예상 시간 |
|---|---------|------|----------|----------|
| 1 | Download | bootstrap-aarch64.zip 다운로드 | ~25MB | 30초-3분 |
| 2 | Extract | ZIP 추출 + 경로 패치 + apt 설정 | — | ~30초 |
| 3 | Runtime | Node.js + git apt 다운로드 + 설치 | ~35MB | 1-3분 |
| 4 | UI | www.zip 다운로드 + 추출 | ~1MB | 5-15초 |

**총 예상 시간**: 3-7분 (네트워크 속도 의존)

### 화면: 마일스톤 1 — Download (진행 중)

```
┌──────────────────────────────────────┐
│                                      │
│  ● Download  ○ Extract  ○ Runtime  ○ UI│
│  ━━━●━━━━━━━○━━━━━━━━━━○━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  Setting up your environment         │
│                                      │
│  ━━━━━━━━━━━━━━━░░░░░░░  62%        │
│                                      │
│  📥 Downloading core files           │
│     12.3 MB / 25.0 MB                │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💡 OpenClaw runs a full Linux  │  │
│  │ terminal on your phone — no    │  │
│  │ root needed.                   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ⏱ About 4 min remaining            │
│                                      │
└──────────────────────────────────────┘
```

### 화면: 마일스톤 2 — Extract (진행 중)

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Download  ● Extract  ○ Runtime  ○ UI│
│  ━━━━━━━━━━━━●━━━━━━━━━━○━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  Setting up your environment         │
│                                      │
│  ━━━━━━━━━━━━━━━━━━░░░░░  72%       │
│                                      │
│  📦 Unpacking files                  │
│     Setting up paths...              │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💡 All processing happens      │  │
│  │ locally on your device.        │  │
│  │ Your data never leaves your    │  │
│  │ phone.                         │  │
│  └────────────────────────────────┘  │
│                                      │
│  ⏱ About 3 min remaining            │
│                                      │
└──────────────────────────────────────┘
```

### 화면: 마일스톤 3 — Runtime (진행 중)

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Download  ✓ Extract  ● Runtime  ○ UI│
│  ━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  Installing runtime                  │
│                                      │
│  ━━━━━━━━━━━━━━━━━━━━━░░░  85%      │
│                                      │
│  📥 Downloading Node.js v22          │
│     18.2 MB / 30.0 MB                │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 💡 Once setup is complete,     │  │
│  │ your AI assistant runs at      │  │
│  │ full speed — just like on      │  │
│  │ a computer.                    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ⏱ About 2 min remaining            │
│                                      │
└──────────────────────────────────────┘
```

### 화면: 마일스톤 4 — UI (빠르게 완료)

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Download  ✓ Extract  ✓ Runtime  ● UI│
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  Almost ready!                       │
│                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━░  97%   │
│                                      │
│  📥 Downloading UI                   │
│     Finishing up...                  │
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
│  ⏱ Less than a minute               │
│                                      │
└──────────────────────────────────────┘
```

### 디자인 상세

| 항목 | 설명 |
|------|------|
| Stepper | 화면 상단 고정. 4개 마일스톤을 수평 배치. 줄이 넘치면 아이콘만 표시 |
| 프로그레스 바 | 전체 진행률. 마일스톤 가중치: Download 30%, Extract 10%, Runtime 50%, UI 10% |
| 상태 텍스트 | 현재 작업 설명 (실시간 업데이트) |
| 바이트 카운터 | 다운로드 단계에서만 표시 (MB 단위) |
| 💡 Tip 카드 | 대기 중 사용자에게 유용한 정보 제공. 5초마다 전환 |
| 남은 시간 | 화면 하단. 다운로드 속도 기반 동적 계산 |

### 💡 Tip 카드 풀 (순환 표시)

| Tip | 표시 시점 |
|-----|----------|
| "OpenClaw runs a full Linux terminal on your phone — no root needed." | Download |
| "All processing happens locally on your device. Your data never leaves your phone." | Extract |
| "Once setup is complete, your AI assistant runs at full speed — just like on a computer." | Runtime |
| "You can install multiple AI platforms and switch between them anytime." | Runtime |
| "Wi-Fi recommended for faster setup." | Download (느린 속도 감지 시) |
| "Setup is a one-time process. Future launches are instant." | 모든 단계 |

### 예상 시간 계산 로직

```kotlin
class TimeEstimator {
    private var downloadStartTime: Long = 0
    private var downloadedBytes: Long = 0

    fun estimateRemaining(currentStep: Int, progress: Float): String {
        // 다운로드 단계: 실제 다운로드 속도 기반
        // 추출 단계: 고정 ~30초
        // 설치 단계: 다운로드 속도 외삽 + 설치 고정 시간
        // 마지막 단계: "Less than a minute"
        val remaining = when (currentStep) {
            1 -> estimateFromSpeed(downloadedBytes, totalSize) + 210  // +나머지 단계
            2 -> 30 + estimateFromSpeed(0, runtimeSize) + 15
            3 -> estimateFromSpeed(downloadedBytes, runtimeSize) + 15
            4 -> 15
            else -> 0
        }
        return formatDuration(remaining)
    }

    private fun formatDuration(seconds: Int): String = when {
        seconds > 300 -> "About ${seconds / 60} min remaining"
        seconds > 60 -> "About ${seconds / 60 + 1} min remaining"
        else -> "Less than a minute"
    }
}
```

### 프로그레스 바 가중치

전체 진행률을 4개 마일스톤에 가중 분배한다. 시간이 오래 걸리는 단계에 더 많은 비중을 부여하되, 초반에 빠르게 진행되는 느낌을 주기 위해 약간 앞쪽으로 편향시킨다.

| 마일스톤 | 실제 시간 비중 | 프로그레스 가중치 | 프로그레스 범위 |
|---------|-------------|-----------------|--------------|
| Download | ~45% | 35% | 0% → 35% |
| Extract | ~8% | 15% | 35% → 50% |
| Runtime | ~42% | 40% | 50% → 90% |
| UI | ~5% | 10% | 90% → 100% |

Extract(추출)에 실제보다 높은 가중치를 부여하여, 다운로드 완료 직후 프로그레스가 빠르게 50%까지 올라가도록 한다 → 사용자에게 "절반 완료" 도달감 제공.

---

### 에러: 다운로드 실패 (마일스톤 1, 3)

```
┌──────────────────────────────────────┐
│                                      │
│  ● Download  ○ Extract  ○ Runtime  ○ UI│
│  ━━━●━━━━━━━○━━━━━━━━━━○━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  ⚠ Download failed                  │
│                                      │
│  Could not download core files.      │
│  Please check your connection        │
│  and try again.                      │
│                                      │
│  Error: Connection timed out         │
│                                      │
│     [Retry]        [Cancel]          │
│                                      │
│                                      │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| Stepper 유지 | 에러 시에도 stepper는 표시. 어디서 실패했는지 시각적으로 확인 가능 |
| [Retry] | 마일스톤 1: 이어받기(Resume) 시도. 마일스톤 3: apt 미러 폴백 후 재시도 |
| [Cancel] | 앱 종료 |
| CDN 폴백 | config.json에 대체 URL 설정. 자동 시도 후 실패 시 에러 표시 |

### 에러: 디스크 부족 (마일스톤 2)

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Download  ● Extract  ○ Runtime  ○ UI│
│  ━━━━━━━━━━━━●━━━━━━━━━━○━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  ⚠ Not enough storage               │
│                                      │
│  OpenClaw needs at least 200MB       │
│  of free space.                      │
│                                      │
│  Available: 85MB                     │
│  Required:  200MB                    │
│                                      │
│  Free up space and try again.        │
│                                      │
│          [Retry]                     │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

### 에러: 런타임 설치 실패 (마일스톤 3)

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Download  ✓ Extract  ● Runtime  ○ UI│
│  ━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━○━━ │
│                                      │
│            🧠 OpenClaw               │
│                                      │
│  ⚠ Runtime installation failed      │
│                                      │
│  Could not download Node.js.         │
│  This might be a temporary           │
│  network issue.                      │
│                                      │
│  [Retry]          [Skip for now]     │
│                                      │
│  Skipping allows basic terminal      │
│  access. You can retry in Settings.  │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Skip for now] | 런타임 없이 마일스톤 4(UI)로 진행. 터미널은 사용 가능하지만 플랫폼 설치 불가. 설정에서 나중에 재시도 가능 |
| stepper 표시 | 스킵된 마일스톤은 `⚠` (경고 아이콘, 주황색)으로 표시 |

---

## ── 이하 WebView UI ──

S1.4부터는 www.zip이 추출된 상태이므로 WebView로 렌더링한다.

---

## S1.4 플랫폼 선택 [WebView]

사용자가 설치할 에이전트 런타임을 선택한다.

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Environment    ● Platform         │
│  ━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━ │
│                                      │
│  Choose your platform                │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  🧠 OpenClaw                   │  │
│  │  AI agent platform             │  │
│  │  Full-featured · Most popular  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  ⚡ Moltis                     │  │
│  │  Fast AI assistant             │  │
│  │  Lightweight · Quick setup     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  🔷 ZeroClaw                   │  │
│  │  Multi-provider platform       │  │
│  │  Flexible · Advanced           │  │
│  └────────────────────────────────┘  │
│                                      │
│  More platforms in Settings.         │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| Stepper | 2단계 stepper: "Environment ✓" → "Platform ●". 환경 셋업이 완료되었음을 강조 |
| 데이터 소스 | `config.json`의 `platforms` 배열 (원격 설정으로 동적 관리) |
| 사용자 액션 | 플랫폼 카드 탭 → S1.5 |
| JsBridge | `OpenClaw.getAvailablePlatforms()` → JSON |
| 전환 | 플랫폼 선택 → S1.5 |

---

## S1.5 플랫폼 설치 [WebView + JsBridge — 마일스톤 UI]

선택한 플랫폼을 설치한다. 이 단계도 마일스톤 UI를 적용하여 진행 상황을 상세하게 보여준다.

### 마일스톤 정의

| # | 마일스톤 | 내용 | 예상 시간 |
|---|---------|------|----------|
| 1 | Download | npm 패키지 다운로드 | 1-2분 |
| 2 | Install | 의존성 설치 + 패치 적용 | 30초-1분 |
| 3 | Verify | 설치 검증 (버전 확인, 기본 실행) | ~10초 |

### 화면: 플랫폼 설치 진행 중

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Environment    ● Platform         │
│  ━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━ │
│                                      │
│  Installing OpenClaw                 │
│                                      │
│  ✓ Download    ● Install    ○ Verify │
│  ━━━━━━━━━━━━━━●━━━━━━━━━━━○━━━━━━━ │
│                                      │
│  ━━━━━━━━━━━━━━━━━━━░░░░░  75%      │
│                                      │
│  📦 Setting up dependencies          │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  > Resolving openclaw@latest   │  │
│  │  > Installing dependencies...  │  │
│  │  > Building native modules...  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ⏱ About 1 min remaining            │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 이중 Stepper | 상단: 전체 흐름 (Environment ✓ → Platform ●). 중단: 플랫폼 설치 세부 단계 |
| 로그 영역 | npm 출력을 간략화하여 실시간 표시. 최근 3줄만 표시 |
| 시스템 동작 | `JsBridge.installPlatform("openclaw")` → 내부적으로 npm install 실행 |
| 소요 시간 | 2-5분 |
| 전환 | 설치 완료 → S1.6 |

### 에러: 플랫폼 설치 실패

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Environment    ● Platform         │
│  ━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━ │
│                                      │
│  ⚠ Installation failed              │
│                                      │
│  OpenClaw could not be installed.    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  npm ERR! network timeout      │  │
│  └────────────────────────────────┘  │
│                                      │
│  [Retry]                             │
│  [Try another platform]              │
│  [Skip — go to Terminal]             │
│                                      │
│  You can always install platforms    │
│  later from Settings.               │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| [Retry] | 재시도 |
| [Try another platform] | → S1.4 (플랫폼 선택으로 돌아감) |
| [Skip — go to Terminal] | 플랫폼 없이 터미널만 사용. 나중에 설정에서 설치 가능 |

---

## S1.6 온보딩 안내 [WebView]

플랫폼 설치 완료 후, 터미널에서 온보딩을 실행하도록 안내한다.

```
┌──────────────────────────────────────┐
│                                      │
│  ✓ Environment    ✓ Platform         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                      │
│  ✓ You're all set!                   │
│                                      │
│  One last step — run the onboarding  │
│  command in Terminal to configure    │
│  your API keys:                      │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  $ openclaw onboard            │  │
│  └────────────────────────────────┘  │
│                                      │
│  This will guide you through:        │
│  • AI provider selection             │
│  • API key configuration             │
│  • Basic preferences                 │
│                                      │
│         [Open Terminal]              │
│                                      │
│  Setup took 4m 32s                   │
│                                      │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| Stepper | 모든 단계 ✓ 완료. 전체 연결선 초록색 |
| 소요 시간 표시 | 실제 셋업에 걸린 시간 표시. 달성감 제공 |
| 사용자 액션 | [Open Terminal] 탭 |
| JsBridge | `OpenClaw.showTerminal()` 호출 + 터미널에 `openclaw onboard` 자동 입력 (선택적) |
| 전환 | → S1.7 (터미널 화면) |

---

## S1.7 터미널 Ready [Native TerminalView + WebView 탭]

첫 실행 설정이 완료되고, 메인 화면이 표시된다.

```
┌──────────────────────────────────────┐
│  [🖥 Terminal]  [📊 Dashboard]  [⚙]  │
├──────────────────────────────────────┤
│  $ openclaw onboard                  │
│                                      │
│  Welcome to OpenClaw! 🧠             │
│  Let's set up your environment.      │
│                                      │
│  ? Select your AI provider:          │
│    > OpenAI                          │
│      Anthropic                       │
│      Google                          │
│      Local LLM                       │
│                                      │
├──────────────────────────────────────┤
│  ⌨ 키보드                            │
└──────────────────────────────────────┘
```

| 항목 | 설명 |
|------|------|
| 화면 구성 | 탭 바 (WebView, 상단) + TerminalView (Native, 중앙) + 키보드 |
| 초기 상태 | Terminal 탭 활성, `openclaw onboard` 실행 중 |
| FGS | `OpenClawService` 시작 — 백그라운드에서 프로세스 유지 |
| 이후 흐름 | 사용자가 온보딩 완료 → `openclaw gateway` 실행 → 일상 사용 시나리오 |

---

## 에러 케이스 종합

| 에러 | 발생 시점 | 사용자 영향 | 복구 방법 |
|------|----------|-----------|----------|
| 네트워크 없음 | S1.2 | 진행 불가 | 네트워크 연결 후 자동 재개 |
| Bootstrap 다운로드 실패 | S1.3 마일스톤 1 | 진행 불가 | [Retry] + CDN 폴백. stepper에서 실패 위치 확인 가능 |
| 디스크 부족 | S1.3 마일스톤 2 | 추출 실패 | 스토리지 확보 후 [Retry] |
| 런타임 설치 실패 | S1.3 마일스톤 3 | 런타임 미설치 | [Retry] 또는 [Skip for now]. 설정에서 나중에 재시도 |
| WebUI 다운로드 실패 | S1.3 마일스톤 4 | WebView UI 불가 | [Retry]. 최악의 경우 네이티브 UI로 터미널만 제공 |
| 플랫폼 설치 실패 | S1.5 | 플랫폼 미설치 | [Retry], 다른 플랫폼, 또는 터미널로 직접 설치 |

---

## 기술 노트

### Native → WebView 전환 시점

```
S1.1 [Native] ──→ S1.3 [Native]: www.zip 미존재 (마일스톤 4 완료 전)
                        │
                        ▼  S1.3 마일스톤 4 완료 (www.zip 추출)
S1.4 [WebView] ──→ S1.7 [WebView + Native 혼합]
```

- S1.1~S1.3: `setContentView(R.layout.activity_setup)` — Stepper + ProgressBar + TextView + TipCard
- S1.4~: `setContentView(R.layout.activity_main)` — WebView + TerminalView 혼합 레이아웃
- 전환 시 Activity 재생성 없이 `setContentView()` 교체

### Native 셋업 레이아웃 (activity_setup.xml)

```xml
<ConstraintLayout>
    <!-- 상단: Stepper (수평 LinearLayout) -->
    <LinearLayout id="stepper"
        orientation="horizontal"
        constraintTop_toTopOf="parent">
        <!-- 동적으로 StepView 생성 -->
    </LinearLayout>

    <!-- 중앙: 로고 + 상태 -->
    <ImageView id="logo" />
    <TextView id="statusTitle" />       <!-- "Setting up your environment" -->
    <ProgressBar id="progressBar" />    <!-- Material LinearProgressIndicator -->
    <TextView id="statusDetail" />      <!-- "📥 Downloading core files" -->
    <TextView id="sizeInfo" />          <!-- "12.3 MB / 25.0 MB" -->

    <!-- 하단: Tip 카드 + 남은 시간 -->
    <CardView id="tipCard">
        <TextView id="tipText" />
    </CardView>
    <TextView id="timeRemaining" />     <!-- "⏱ About 4 min remaining" -->
</ConstraintLayout>
```

### FGS 시작 시점

Foreground Service는 **S1.7 터미널 Ready** 시점에 시작.
셋업 중에는 불필요 (셋업은 Activity 포그라운드에서 진행).

### 첫 실행 상태 저장

각 마일스톤 완료 시 SharedPreferences에 상태 저장:
```
setup_milestone_download = true
setup_milestone_extract = true
setup_milestone_runtime = true      // false if skipped
setup_milestone_runtime_skipped = false
setup_milestone_webui = true
setup_platform_installed = "openclaw"
setup_completed = true
setup_total_duration_ms = 272000    // 4m 32s
```

앱이 셋업 중 강제 종료되면, 재실행 시 마지막 완료 마일스톤부터 재개.
런타임을 Skip한 경우, 설정 화면에서 재시도 시 `setup_milestone_runtime`만 다시 진행.

### 화면 번호 변경 이력

기존(v1) → 현재(v2) 매핑:

| v1 | v2 | 변경 |
|----|----|----|
| S1.1 스플래시 | S1.1 스플래시 | 변경 없음 |
| S1.2 네트워크 확인 | S1.2 네트워크 확인 | 변경 없음 |
| S1.3 Bootstrap 다운로드 | S1.3 환경 셋업 (마일스톤 1) | **통합: S1.3~S1.6 → S1.3** |
| S1.4 Bootstrap 추출 | S1.3 환경 셋업 (마일스톤 2) | 통합 |
| S1.5 런타임 설치 | S1.3 환경 셋업 (마일스톤 3) | 통합 |
| S1.6 WebUI 다운로드 | S1.3 환경 셋업 (마일스톤 4) | 통합 |
| S1.7 플랫폼 선택 | S1.4 플랫폼 선택 | 번호 변경 |
| S1.8 플랫폼 설치 | S1.5 플랫폼 설치 | 번호 변경, 마일스톤 UI 추가 |
| S1.9 온보딩 안내 | S1.6 온보딩 안내 | 번호 변경 |
| S1.10 터미널 Ready | S1.7 터미널 Ready | 번호 변경 |

# Analytics 통합 계획

> 작성일: 2026-03-06
> 상태: Draft
> 상위 문서: `01-core/02-standalone-apk-option-d.md`
> 요약: Firebase Analytics는 GPL v3 + F-Droid 배포와 양립 불가. WebView JS 기반 analytics + opt-in 크래시 리포팅 권장.

---

## 0. 목적

앱 출시 후 사용자 행동을 파악하여 제품 개선에 활용한다.

**추적 대상:**

| 카테고리 | 이벤트 예시 | 우선순위 |
|----------|-----------|---------|
| 설치 퍼널 | 각 셋업 단계 완료율, 이탈 지점 | 높음 |
| 플랫폼 사용 | 어떤 플랫폼이 선택되는지, 설치 성공률 | 높음 |
| 앱 안정성 | 크래시 빈도, ANR, 에러 유형 | 높음 |
| 기능 사용 | 터미널/대시보드/설정 탭 사용 빈도 | 중간 |
| 업데이트 | OTA 업데이트 성공률, 버전 분포 | 중간 |
| 리텐션 | DAU/WAU, 세션 시간 | 낮음 (초기) |

---

## 1. Firebase Analytics 평가

### 결론: ❌ NO-GO

| 항목 | 판정 | 근거 |
|------|------|------|
| targetSdk 28 호환 | ✅ | minSdk 21. 기술적 문제 없음 |
| WebView 이벤트 | ⚠️ | `@JavascriptInterface` 브리지 직접 구현 필요 |
| APK 크기 | ❌ | +1.5~3MB (ProGuard 후). 5MB 예산 초과 위험 |
| GMS 의존 | ⚠️ | 기본 이벤트는 GMS 없이 동작하나, 인구통계 등 불가 |
| **GPL v3 라이선스** | ❌ | **독점 SDK. GPL v3 앱에 링크 시 라이선스 위반** |
| **F-Droid 배포** | ❌ | **F-Droid Inclusion Policy가 Firebase를 명시적으로 금지** |
| GDPR | ⚠️ | 자동 데이터 수집 (하드웨어 ID, 위치 등). 동의 배너 필수 |

**치명적 차단 요소 2개:**
1. Firebase SDK는 독점 소프트웨어 → GPL v3 앱에 포함 시 라이선스 위반
2. F-Droid Inclusion Policy 직접 인용: *"The implementation of proprietary tracking or advertising libraries and analytics tools such as Google Play Services and Firebase and Crashlytics and proprietary ad/tracking SDKs are strictly forbidden in all applications."*

---

## 2. F-Droid 제약 조건

### Anti-Feature 라벨 체계

| 라벨 | 조건 | 결과 |
|------|------|------|
| `Tracking` | 사용자 동의 없이 또는 기본 활성화 상태로 데이터 전송 | 앱이 F-Droid 검색에서 **기본 숨김** |
| `NonFreeNet` | 독점 네트워크 서비스에 의존 | 앱 설명에 경고 표시 |
| (거부) | 독점 analytics SDK 포함 | **메인 리포지토리 등재 불가** |

### Opt-in vs Opt-out — 결정적 차이

| 방식 | Anti-Feature 라벨 | F-Droid 노출 |
|------|-------------------|-------------|
| **Opt-in** (기본 OFF, 사용자가 명시적 동의) | ❌ 없음 | 정상 표시 |
| Opt-out (기본 ON, 설정에서 끌 수 있음) | ✅ `Tracking` | 기본 숨김 |
| 동의 없이 자동 전송 | ✅ `Tracking` | 기본 숨김 |
| 독점 SDK 사용 | — | **등재 거부** |

> F-Droid 포럼 maintainer 답변: *"기본 비활성화이고 사용자에게 활성화 여부를 묻는다면? → No, it's an informed choice"* (Anti-Feature 아님)

### 핵심 요건

1. **FLOSS 라이선스** — SDK와 백엔드 모두
2. **Opt-in** — 기본 OFF, 첫 실행 시 명시적 동의 요청
3. **개인정보처리방침** — GDPR 수준의 설명 제공
4. **PII 최소화** — 개인 식별 데이터 수집 회피

---

## 3. 대안 솔루션 비교

### 3.1 비교표

| 솔루션 | 라이선스 | GMS | APK 크기 | WebView 지원 | Self-hosted | F-Droid |
|--------|---------|-----|---------|-------------|-------------|---------|
| **Plausible JS** | AGPL/MIT | ❌ | **0KB** | ✅ 최적 | ✅ | ⭐⭐⭐⭐⭐ |
| **Umami JS** | MIT | ❌ | **0KB** | ✅ 최적 | ✅ | ⭐⭐⭐⭐⭐ |
| **Matomo SDK** | BSD-3 | ❌ | ~150KB | ⚠️ 간접 | ✅ | ⭐⭐⭐⭐⭐ |
| Countly SDK | MIT | ❌ | ~350KB | ✅ | ✅ (AGPL) | ⭐⭐⭐⭐ |
| PostHog SDK | MIT | ❌ | ~500KB | ⚠️ | ✅ | ⭐⭐⭐⭐ |
| Aptabase | MIT | ❌ | ~25KB | ❌ | ✅ | ⭐⭐⭐⭐ |
| TelemetryDeck | MIT | ❌ | ~250KB | ❌ | ❌ 클라우드만 | ⭐⭐ |
| ~~Firebase~~ | ~~독점~~ | ~~✅~~ | ~~2MB~~ | — | — | ❌ |

### 3.2 WebView JS 방식 (Plausible / Umami)

UI가 100% WebView이므로 웹 analytics JS 스크립트를 HTML에 직접 삽입하는 것이 가장 자연스러운 접근.

```html
<!-- www/index.html에 삽입 -->
<script defer data-domain="app.openclaw.android"
        src="https://analytics.openclaw.example/js/script.js"></script>
```

**장점:**
- APK 크기 영향 0
- 앱 소스에 analytics 라이브러리 없음 → F-Droid 완전 호환
- GPL v3 충돌 없음
- www.zip OTA로 analytics 코드 업데이트 가능

**단점:**
- 오프라인 시 이벤트 유실 (큐잉 불가)
- 네이티브 이벤트 추적 불가 (앱 시작/종료, 크래시, 백그라운드 전환)
- `file:///` 프로토콜에서 외부 스크립트 로드 시 CSP 설정 필요

**오프라인 문제 완화:**
```javascript
// www/js/analytics.js
function trackEvent(name, props) {
    if (navigator.onLine) {
        // 즉시 전송
        plausible(name, { props });
    } else {
        // localStorage에 큐잉
        const queue = JSON.parse(localStorage.getItem('analytics_queue') || '[]');
        queue.push({ name, props, timestamp: Date.now() });
        localStorage.setItem('analytics_queue', JSON.stringify(queue));
    }
}

// 네트워크 복구 시 큐 플러시
window.addEventListener('online', flushQueue);
```

### 3.3 Matomo Android SDK

F-Droid가 명시적으로 권장하는 유일한 analytics 솔루션.

**장점:**
- F-Droid 공식 문서가 Google Analytics 대체제로 "Piwik(Matomo)"을 권장
- 네이티브 이벤트 추적 가능 (앱 수명주기, 크래시)
- 오프라인 큐잉 내장
- BSD-3-Clause → GPL v3 호환

**단점:**
- 서버 운영 필요 (PHP + MySQL)
- WebView 이벤트는 JS bridge로 포워딩 필요 (추가 구현)
- 서버 운영 비용 발생

### 3.4 크래시 리포팅: ACRA

ACRA (Application Crash Reports for Android) — Apache 2.0, F-Droid 호환.

| 전송 방식 | Anti-Feature |
|----------|-------------|
| 이메일 초안 (사용자가 직접 전송) | ❌ 없음 |
| HTTP 전송 (opt-in) | ❌ 없음 |
| HTTP 전송 (opt-out) | ✅ `Tracking` |

F-Droid 클라이언트 자체가 ACRA를 사용하고 있음 (이메일 초안 방식).

---

## 4. 권장 아키텍처

### Tier 1: WebView Analytics (Umami self-hosted)

**선택 근거:** MIT 라이선스, Node.js 기반 (프로젝트 기술 스택과 일치), 경량, 쿠키 없음, GDPR 친화적.

```
┌─────────────────────────────────────────────────────────┐
│ WebView UI (www/)                                       │
│  ├── index.html ← Umami JS 스크립트 삽입                │
│  ├── setup/     ← 셋업 퍼널 추적                        │
│  ├── platforms/ ← 플랫폼 선택 추적                       │
│  └── settings/  ← 기능 사용 추적                         │
│                    │                                     │
│                    ▼ (HTTP POST, 온라인 시만)              │
│           ┌────────────────────┐                         │
│           │ Umami Server       │ ← Self-hosted           │
│           │ (analytics.openclaw│    Node.js + PostgreSQL  │
│           │  .example)         │                         │
│           └────────────────────┘                         │
└─────────────────────────────────────────────────────────┘
```

**추적 가능 이벤트:**
- 페이지뷰: 셋업 각 단계, 플랫폼 선택, 설정, 대시보드
- 커스텀 이벤트: 버튼 클릭, 에러 발생, 플랫폼 설치 완료
- 퍼널: 셋업 S1.4 → S1.5 → S1.6 → S1.7 전환율

**추적 불가 이벤트 (WebView 밖):**
- 앱 시작/종료, 백그라운드 전환
- 네이티브 셋업 단계 (S1.1~S1.6, WebView 로드 전)
- 크래시/ANR

### Tier 2: 네이티브 보완 (JsBridge 확장)

네이티브 셋업 단계(S1.1~S1.6)는 WebView가 아직 없으므로, Kotlin에서 직접 이벤트를 큐잉하고 WebView 로드 후 전송.

```kotlin
// BootstrapManager.kt — 네이티브 셋업 이벤트 큐잉
object SetupAnalytics {
    private val queue = mutableListOf<AnalyticsEvent>()

    fun track(event: String, props: Map<String, String> = emptyMap()) {
        queue.add(AnalyticsEvent(event, props, System.currentTimeMillis()))
    }

    // WebView 로드 후 호출 — 큐잉된 이벤트를 JS로 전달
    fun flushToWebView(webView: WebView) {
        val events = JSONArray(queue.map { it.toJSON() })
        webView.evaluateJavascript(
            "window.__nativeEvents = $events; window.dispatchEvent(new Event('native-events-ready'));",
            null
        )
        queue.clear()
    }
}

// 사용: 셋업 각 단계에서
SetupAnalytics.track("setup_bootstrap_download_start", mapOf("size_mb" to "25"))
SetupAnalytics.track("setup_bootstrap_download_complete", mapOf("duration_sec" to "45"))
```

```javascript
// www/js/analytics.js — 네이티브 이벤트 수신
window.addEventListener('native-events-ready', () => {
    const events = window.__nativeEvents || [];
    events.forEach(e => trackEvent(e.name, e.props));
});
```

### Tier 3: 크래시 리포팅 (ACRA, opt-in)

```kotlin
// ACRA 설정 — opt-in 방식
@AcraCore(reportFormat = StringFormat.JSON)
@AcraMailSender(mailTo = "crashes@openclaw.example")  // 이메일 초안 방식
class OpenClawApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // SharedPreferences에서 opt-in 확인
        if (prefs.getBoolean("crash_reporting_enabled", false)) {
            ACRA.init(this)
        }
    }
}
```

---

## 5. Opt-in 구현

### 첫 실행 시 동의 요청 (S1.7 직후, WebView에서)

```
┌──────────────────────────────────────┐
│                                      │
│     Help improve OpenClaw            │
│                                      │
│     Share anonymous usage data       │
│     to help us improve the app.      │
│                                      │
│     What we collect:                 │
│     • Which features you use         │
│     • Setup completion rates         │
│     • Crash reports (if enabled)     │
│                                      │
│     What we DON'T collect:           │
│     • Personal information           │
│     • Terminal commands/output        │
│     • API keys or credentials        │
│                                      │
│     You can change this anytime      │
│     in Settings.                     │
│                                      │
│  [Yes, share data]   [No thanks]     │
│                                      │
└──────────────────────────────────────┘
```

- 기본값: **OFF** (No thanks)
- 설정 → 앱 정보에서 언제든 변경 가능
- 개인정보처리방침 링크 포함

### 설정 화면

```
┌──────────────────────────────────────┐
│  Privacy                             │
│  ─────────────────────────────────── │
│  Share usage data          [  OFF ]  │
│  Help improve OpenClaw by sharing    │
│  anonymous usage statistics.         │
│                                      │
│  Share crash reports       [  OFF ]  │
│  Automatically send crash reports    │
│  when the app encounters errors.     │
│                                      │
│  Privacy Policy →                    │
└──────────────────────────────────────┘
```

---

## 6. 서버 운영

### Umami Self-hosted

| 항목 | 내용 |
|------|------|
| 기술 스택 | Node.js + PostgreSQL |
| 호스팅 | VPS (DigitalOcean $6/mo, Hetzner €4/mo) 또는 Vercel (무료 티어) |
| 도메인 | `analytics.openclaw.example` |
| 데이터 보존 | 12개월 (GDPR 최소화 원칙) |
| 백업 | PostgreSQL daily dump |

### 비용 추정

| 항목 | 월 비용 |
|------|--------|
| VPS (1GB RAM) | $4-6 |
| 도메인 | ~$1 (연간 $12) |
| **총** | **$5-7/월** |

사용자 규모가 작은 초기에는 Vercel 무료 티어 또는 기존 서버에 Docker로 추가 가능.

---

## 7. 로드맵

| Phase | 시점 | 내용 |
|-------|------|------|
| Phase 0 | APK 개발 중 | Analytics 코드 없음. 개발에 집중 |
| Phase 1 | APK 첫 릴리즈 | Umami JS 삽입 + opt-in UI + ACRA (이메일 초안) |
| Phase 2 | 사용자 확보 후 | 네이티브 이벤트 큐잉 (SetupAnalytics) 추가 |
| Phase 3 | 스케일 시 | Matomo로 전환 검토 (더 풍부한 분석 기능) |

---

## 8. 의사결정 요약

| 결정 | 근거 |
|------|------|
| Firebase ❌ 사용 불가 | GPL v3 위반 + F-Droid 즉시 거부 |
| Umami JS ✅ 선택 | MIT, 0KB APK 영향, WebView 최적, self-hosted |
| ACRA ✅ 크래시 리포팅 | Apache 2.0, F-Droid 호환, opt-in 이메일 방식 |
| Opt-in 필수 | F-Droid `Tracking` Anti-Feature 회피 |
| Self-hosted 필수 | F-Droid `NonFreeNet` Anti-Feature 회피 |

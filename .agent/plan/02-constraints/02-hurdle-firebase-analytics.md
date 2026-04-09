# 허들 분석: Firebase Analytics 도입

> 작성일: 2026-03-06
> 상태: Final
> 상위 문서: `01-core/02-standalone-apk-option-d.md`, `03-analytics.md`
> 현재 상태: Firebase Analytics 불가 판정. Umami JS + ACRA 권장 (03-analytics.md 참조)
> 요약: Firebase Analytics 도입의 차단 요소는 GPL v3 라이선스 충돌과 F-Droid 정책. 기술적으로는 가능하나 법적·배포적으로 불가.

---

## 0. 이 문서의 목적

Firebase Analytics는 모바일 analytics의 사실상 표준이다. 우리 앱에서 사용하지 못하는 이유, 사용하려면 무엇이 필요한지, 그리고 그 대가가 무엇인지를 정리한다.

---

## 1. 차단 요소 1: GPL v3 라이선스 충돌

### 1.1 문제 구조

```
OpenClaw APK
├── Kotlin 앱 코드 (우리 코드)
├── terminal-view (Apache 2.0) ✅ GPL 호환
├── Termux bootstrap (GPL v3) ← 핵심 의존성
│   ├── bash (GPL v3)
│   ├── coreutils (GPL v3)
│   ├── apt (GPL v2+)
│   └── 기타 GNU 도구
└── Firebase SDK (독점) ← ❌ GPL v3와 양립 불가
```

### 1.2 왜 충돌하는가

**GPL v3 §5(c)**: GPL v3 코드를 포함하는 "combined work"를 배포할 때, 전체 작업물에 GPL v3 호환 라이선스를 적용해야 한다.

**FSF의 해석** (FAQ 직접 인용):
- *"If you distribute a program linked against a GPL-covered library, you must make the source code available under the GPL."*
- FSF는 정적/동적 링킹을 구분하지 않음. 같은 프로세스 공간에서 실행되면 "combined work".
- **핵심**: Firebase SDK는 독점 라이선스 → GPL v3와 combined work를 형성하면 라이선스 위반.

### 1.3 "우리 앱이 Termux bootstrap과 combined work인가?"

이것이 법적 핵심 쟁점이다.

**Combined work 방향 근거 (GPL 전염 O):**
- APK가 bootstrap을 다운로드·추출·실행하는 것은 앱의 핵심 기능
- 앱 없이 bootstrap이 무의미하고, bootstrap 없이 앱이 무의미
- 기능적 의존성이 있으면 FSF는 combined work로 본다

**Aggregate 방향 근거 (GPL 전염 X):**
- Bootstrap은 APK에 포함되지 않음 (런타임 다운로드)
- 통신 방식이 PTY/pipe (프로세스 간 통신)이지 라이브러리 링킹이 아님
- Termux 앱 자체가 Apache 2.0 + GPL v3 bootstrap 조합으로 배포 중

**현실적 판단:**

| 요소 | Combined | Aggregate |
|------|----------|-----------|
| Bootstrap이 APK에 포함? | ❌ 런타임 다운로드 | ✅ 분리됨 |
| 같은 프로세스 공간? | ❌ 별도 프로세스 | ✅ 분리됨 |
| 통신 방식 | PTY/pipe | ✅ IPC |
| 기능적 의존성 | ✅ 앱이 bootstrap 없이 동작 불가 | — |
| 배포 단위 | ✅ 앱이 bootstrap을 설치 | — |

**회색 지대이나, 보수적으로 combined work로 간주하는 것이 안전.** 법적 분쟁 시 "기능적 의존성" 기준으로 판단될 가능성이 높다.

### 1.4 GPL v3와 Firebase SDK의 구체적 충돌

Firebase SDK 라이선스: Google 독점 (비공개 소스, 재배포 제한)

| GPL v3 요구사항 | Firebase SDK 현실 | 충돌 |
|----------------|------------------|------|
| 전체 소스 공개 | 독점, 비공개 | ❌ |
| GPL v3 호환 라이선스 | 독점 라이선스 | ❌ |
| 사용자의 수정·재배포 자유 | 재배포 제한 | ❌ |

---

## 2. 차단 요소 2: F-Droid 정책

### 2.1 F-Droid Inclusion Policy 직접 인용

> *"The implementation of proprietary tracking or advertising libraries and analytics tools such as Google Play Services and Firebase and Crashlytics and proprietary ad/tracking SDKs are strictly forbidden in all applications."*

Firebase SDK를 포함하면 F-Droid **메인 리포지토리에 등재 불가**. 예외 없음.

### 2.2 별도 F-Droid 리포지토리 운영?

F-Droid는 자체 리포지토리를 만들 수 있으나:
- 사용자가 별도 리포지토리 URL을 수동 추가해야 함
- F-Droid 메인 검색에 노출되지 않음
- 사실상 GitHub Releases와 다를 바 없음
- Termux 사용자 기반(F-Droid에서 유입)을 잃음

---

## 3. Firebase Analytics를 사용하기 위한 경로 분석

### 3.1 경로 A: GPL v3 코드 제거

GPL v3 의존성을 모두 제거하면 Firebase 포함 가능.

| GPL v3 구성요소 | 대체제 | 실현 가능성 |
|----------------|--------|-----------|
| bash | mksh (BSD), Toybox sh | ⚠️ 호환성 문제 |
| coreutils | Toybox (BSD) | ⚠️ 일부 명령 누락 |
| apt | — | ❌ 대체 불가 |
| grep, sed, awk | Toybox 내장 | ⚠️ 기능 제한 |
| git | — | git은 GPL v2 |

**결론**: ❌ `apt`를 대체할 수 없으므로 불가. Termux의 패키지 관리 전체가 apt 기반.

### 3.2 경로 B: 앱 분리 (2-APK 구조)

```
APK 1: OpenClaw Launcher (독점 가능, Firebase 포함)
  - 플랫폼 선택기 UI
  - Analytics 수집
  - Firebase SDK

APK 2: OpenClaw Terminal (GPL v3)
  - terminal-view + Termux bootstrap
  - 실제 실행 환경
```

| 장점 | 단점 |
|------|------|
| Firebase 사용 가능 | 2개 앱 설치 → 원래의 UX 문제로 회귀 |
| GPL v3 격리 | 앱 간 통신 복잡성 |
| Play Store 배포 가능 (APK 1) | 사용자 혼란 |

**결론**: ⚠️ 기술적으로 가능하나, "2개 앱 설치 문제"가 이 프로젝트의 출발점이었으므로 본질적 모순.

### 3.3 경로 C: GPL 호환 Analytics로 대체

Firebase를 포기하고 GPL 호환 Analytics를 사용.

→ **이것이 현재 채택된 경로.** `03-analytics.md` 참조. Umami JS + ACRA 조합.

### 3.4 경로 D: 런타임 분리 (회색 지대)

Firebase SDK를 APK에 포함하되, GPL v3 코드는 런타임에 다운로드하여 별도 프로세스로 실행.

**논리**: "APK 자체에는 GPL 코드가 없으므로, APK는 독점 라이선스 가능"

**위험성:**
- FSF는 "함께 동작하도록 설계된" 프로그램을 combined work로 볼 수 있음
- 법적 판례가 부족하여 불확실성 높음
- GPL v3 커뮤니티의 반발 가능성
- 오픈소스 프로젝트로서 평판 리스크

**결론**: ❌ 법적 회색 지대에서 운영하는 것은 오픈소스 프로젝트에 부적절.

### 3.5 경로 E: 듀얼 라이선싱

GPL v3 구성요소의 저작권자에게 상업 라이선스를 구매하여 예외 확보.

**현실:**
- bash, coreutils 등은 FSF/GNU 프로젝트 → 듀얼 라이선싱 불가 (FSF 정책)
- apt는 Debian 프로젝트 → 다수 기여자, 라이선스 변경 사실상 불가
- 제3자 GPL 코드에 대한 듀얼 라이선싱은 **저작권자 전원의 동의** 필요

**결론**: ❌ 실현 불가능.

---

## 4. 경로 종합 비교

| 경로 | Firebase 사용 | F-Droid 배포 | UX | 법적 리스크 | 실현 가능성 |
|------|-------------|-------------|-----|-----------|-----------|
| A. GPL 제거 | ✅ | ❌ (독점 SDK) | ✅ | 없음 | ❌ apt 대체 불가 |
| B. 앱 분리 | ✅ | 부분적 | ❌ 2앱 | 없음 | ⚠️ UX 후퇴 |
| C. GPL 호환 대체 | ❌ | ✅ | ✅ | 없음 | ✅ **채택됨** |
| D. 런타임 분리 | ✅ | ❌ | ✅ | 🔴 높음 | ⚠️ 회색 지대 |
| E. 듀얼 라이선싱 | ✅ | ❌ | ✅ | 없음 | ❌ 저작권자 동의 불가 |

---

## 5. Firebase에 가장 근접한 대안

Firebase Analytics를 사용할 수 없으므로, 기능적으로 가장 가까운 대안:

### 5.1 PostHog

| 항목 | PostHog | Firebase Analytics |
|------|---------|-------------------|
| 라이선스 | MIT | 독점 |
| 셀프호스팅 | ✅ | ❌ |
| 클라우드 | ✅ (무료 1M 이벤트/월) | ✅ (무료) |
| 이벤트 추적 | ✅ | ✅ |
| 퍼널 분석 | ✅ | ✅ |
| 리텐션 | ✅ | ✅ |
| 세션 리플레이 | ✅ | ❌ |
| F-Droid 호환 | ✅ (opt-in 시) | ❌ |
| 모바일 SDK | ✅ (Android) | ✅ |

**그러나**: PostHog Android SDK를 사용하면 앱 크기가 증가하고, 네트워크 의존성이 생김.

### 5.2 현재 채택: Umami JS (WebView 삽입)

WebView UI 아키텍처의 장점을 활용:
- JavaScript analytics를 www.zip에 포함
- APK 크기 영향 0KB (JS 파일)
- OTA로 업데이트 가능
- 서버 셀프호스팅 또는 Umami Cloud

상세는 `03-analytics.md` §4 참조.

---

## 6. 의사결정 요약

### 현재 결정: Firebase Analytics 불가, GPL 호환 대안 사용

**근거:**
1. GPL v3 라이선스 충돌 — combined work 해석 시 독점 SDK 포함 불가
2. F-Droid가 Firebase를 명시적으로 금지
3. 모든 우회 경로가 실현 불가능하거나 본질적 모순을 내포
4. GPL 호환 대안(Umami JS + ACRA)이 핵심 요구사항을 충족

### Firebase Analytics 도입이 합리적이 되는 조건

다음이 **모두** 충족될 때 재검토:

1. **targetSdk 35+ 달성** (`01-hurdle-targetsdk-35.md` 참조)
2. **GPL v3 의존성 제거** 또는 **aggregate work로의 법적 확정 판례**
3. **F-Droid 배포 포기** 또는 **F-Droid 정책 변경**
4. **Google Play 배포가 비즈니스적으로 필수**

현실적으로 조건 2가 가장 어려우며, Termux bootstrap이 apt 기반인 한 GPL v3 의존성 제거는 불가능.

### 모니터링 대상

| 대상 | 확인 주기 | 소스 |
|------|----------|------|
| Termux 라이선스 변경 | 연간 | github.com/termux/termux-app/LICENSE.md |
| F-Droid analytics 정책 | 연간 | f-droid.org/docs/Inclusion_Policy |
| GPL v3 + 독점 SDK 판례 | 연간 | FSF, EFF, SFLC |
| Umami / PostHog 기능 업데이트 | 분기별 | 각 프로젝트 GitHub |

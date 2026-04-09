# 계획 문서 맵

> 작성일: 2026-03-07 (rev.2 — 06-research 추가)
> 목적: `.agent/plan/` 내 모든 문서의 관계와 권장 읽기 순서를 정리한다.

---

## 디렉토리 구조

```
.agent/plan/
├── DOCUMENT-MAP.md              ← 본 문서
├── 01-core/                     ← 앱 전환의 뼈대
│   └── 02-standalone-apk-option-d.md ★
├── 02-constraints/              ← 아키텍처 제약과 결정 근거
│   ├── 01-hurdle-targetsdk-35.md
│   ├── 02-hurdle-firebase-analytics.md
│   └── 03-analytics.md
├── 03-ux/                       ← UX 스토리보드
│   ├── 00-overview.md
│   ├── 01-first-run.md
│   ├── 02-daily-use.md
│   ├── 03-platform-management.md
│   ├── 04-update.md
│   └── 05-settings.md
├── 04-platforms/                ← 멀티 플랫폼 전략
│   ├── 01-platform-support-roadmap.md
│   └── 02-moltis-support.md
├── 05-cli-maintenance/          ← 기존 CLI 유지보수 (앱 전환과 독립)
    ├── 01-fix-gemini-cli-native-modules.md
    ├── 02-fix-opencode-version-glob.md
    └── 03-filebrowser-migration-plan.md
└── 06-research/                  ← 조사/분석 결과 (의사결정 참고 자료)
    ├── 01-competitive-analysis-openclaw-termux.md
    └── 03-adb-on-android.md
```

---

## 문서 의존 관계

```
01-core/02-standalone-apk-option-d.md ★ (최종 실행 계획)
  ├─▶ 02-constraints/01-hurdle-targetsdk-35.md
  ├─▶ 02-constraints/02-hurdle-firebase-analytics.md
  │     └─▶ 02-constraints/03-analytics.md
  ├─▶ 03-ux/00-overview.md
  │     ├── 03-ux/01-first-run.md
  │     ├── 03-ux/02-daily-use.md
  │     ├── 03-ux/03-platform-management.md
  │     ├── 03-ux/04-update.md
  │     └── 03-ux/05-settings.md
  └─▶ 04-platforms/01-platform-support-roadmap.md
        └── 04-platforms/02-moltis-support.md

[독립] 05-cli-maintenance/ (앱 전환과 무관)
[독립] 06-research/ (조사/분석 — 의사결정 참고 자료)
```

---

## 권장 읽기 순서

### 1단계: 핵심 — 앱 전환의 뼈대

| # | 문서 | 상태 | 설명 |
|---|------|------|------|
| 1 | `01-core/02-standalone-apk-option-d.md` | ✅ 확정 | 모든 문서의 상위 문서. Thin APK + WebView UI + OTA 아키텍처, Phase 로드맵, 기술 결정 |

### 2단계: 아키텍처 제약 — 왜 이렇게 결정했나

| # | 문서 | 상태 | 설명 |
|---|------|------|------|
| 3 | `02-constraints/01-hurdle-targetsdk-35.md` | ✅ Final | targetSdk 28 유지 근거. W^X SELinux 정책, 우회 경로 5개 분석 |
| 4 | `02-constraints/02-hurdle-firebase-analytics.md` | ✅ Final | Firebase Analytics 불가 근거. GPL v3 충돌, F-Droid 정책 |
| 5 | `02-constraints/03-analytics.md` | ✅ 확정 | Firebase 대안 결정. Umami JS (WebView) + ACRA (크래시 리포트) |

### 3단계: UX — 사용자가 보는 것

| # | 문서 | 설명 |
|---|------|------|
| 6 | `03-ux/00-overview.md` | 전체 화면 맵, 렌더링 레이어 구분 (Native vs WebView), 디자인 원칙 |
| 7 | `03-ux/01-first-run.md` | 가장 복잡한 플로우. 스플래시 → 환경 셋업 (마일스톤 UI) → 플랫폼 선택 → 설치 → 온보딩 |
| 8 | `03-ux/02-daily-use.md` | 탭 전환, 터미널 세션 관리, 백그라운드 전환, FGS |
| 9 | `03-ux/03-platform-management.md` | 플랫폼 추가·전환·삭제 |
| 10 | `03-ux/04-update.md` | OTA 업데이트 (WebUI, Bootstrap, 런타임) |
| 11 | `03-ux/05-settings.md` | 추가 도구 설치, PPK 가이드, 스토리지, 앱 정보 |

### 4단계: 런타임 전략 — 앱 이후 확장

| # | 문서 | 상태 | 설명 |
|---|------|------|------|
| 12 | `04-platforms/01-platform-support-roadmap.md` | ✅ 확정 | 6개 런타임 평가 (사용자 수 40% + 이식성 10% + 실익 50%) |
| 13 | `04-platforms/02-moltis-support.md` | ✅ 확정 | 유일한 추가 지원 런타임. Rust 단일 바이너리 + glibc-runner |

### 5단계: 기존 CLI 유지보수 — 앱 전환과 별개

| # | 문서 | 설명 |
|---|------|------|
| 16 | `05-cli-maintenance/01-fix-gemini-cli-native-modules.md` | Gemini CLI 네이티브 모듈 이슈 수정 |
| 17 | `05-cli-maintenance/02-fix-opencode-version-glob.md` | OpenCode 버전 glob 이슈 수정 |
| 18 | `05-cli-maintenance/03-filebrowser-migration-plan.md` | FileBrowser 마이그레이션 계획 |

### 6단계: 조사/분석 — 의사결정 참고 자료

| # | 문서 | 상태 | 설명 |
|---|------|------|------|
| 19 | `06-research/01-competitive-analysis-openclaw-termux.md` | ✅ Final | openclaw-termux(mithun50) 기술 분석, 디바이스 연동 아키텍처, 우리 계획과의 차별성 비교 |
| 20 | `06-research/03-adb-on-android.md` | ✅ Final | Termux에서 adb 사용 조건, Wi-Fi 의존성, 루트/비루트 차이, AI 연동 시나리오 |

---

## 목적별 빠른 참조

| 목적 | 읽을 문서 |
|------|----------|
| 앱 전체 구조 파악 | #1 → #6 → #7 |
| "왜 targetSdk 28인가" 이해 | #3 |
| "왜 Firebase 안 쓰나" 이해 | #4 → #5 |
| UX 플로우 전체 파악 | #6 → #7 → #8 → #9 → #10 → #11 |
| 새 플랫폼 추가 방법 | #12 → #13 |
| 기존 CLI 이슈 처리 | #16 → #17 → #18 |
| 경쟁사 분석 | #19 |
| adb/디바이스 제어 | #20 |

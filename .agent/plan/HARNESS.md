# 하네스 엔지니어링 로드맵

> AI 에이전트를 억누르는 장치가 아니라, 올바른 방향으로 유도하면서 최대한 활용하는 제어 구조.
> 작성일: 2026-03-27

---

## 철학

**하네스(Harness)**는 원래 말(馬)의 힘을 제어하는 마구에서 유래한 개념이다. AI 분야에서는 **"AI 에이전트가 안전하고 예측 가능한 방식으로 작동하도록 설계된 제어 구조 전체"**를 의미한다. 강력한 AI를 억누르는 것이 아니라, 올바른 방향으로 유도하면서 최대한 활용하는 구조다.

---

## 배경

이 프로젝트(OpenClaw on Android)는 오픈소스 프로젝트로, Shell Script 기반 인프라 + Android 앱 + WebView/React UI로 구성되어 있다. 두 종류의 AI 에이전트가 개발에 참여한다:

1. **Aidan** — 개발자, 관리자 (사람)
2. **Simons** — 개발자, 관리자 (Aidan의 개인 에이전트)

이 로드맵은 [Chappies 프로젝트의 하네스 로드맵](https://github.com/AidanPark/src-chappies)을 기반으로, 이 프로젝트의 기술 스택과 규모에 맞게 재설계한 것이다.

---

## 5대 구성 요소

| 구성 요소 | 역할 | 이 프로젝트에서의 예 |
|-----------|------|---------------------|
| **Context Files** | 에이전트에게 프로젝트 규칙·구조를 알려주는 지시 파일 | CLAUDE.md (T1/T2/T3 계층 로딩) |
| **Skills** | 반복 작업의 절차서. 매번 같은 품질로 실행되게 보장 | `.agent/skills/` (repo-management, update-test, verify, create-skill) |
| **Hooks & 린터** | 규칙 위반을 기계적으로 차단. 에이전트가 잊어도 훅이 잡음 | `.githooks/pre-commit`, Claude Code hooks, shellcheck |
| **SSOT (진행 상태 추적)** | 세션 간 컨텍스트 연속성. "어디까지 했고 다음은 뭔지" 추적 | MEMORY.md (장기), progress.md (단기) |
| **피드백 루프** | 에이전트 실수 → 규칙 추가 → 같은 실수 반복 방지 | hooks 확장, T3 트리거 추가 |

---

## 공통 원칙: 제어-감시-개선 프레임워크

| 원칙 | 정의 | 수단 |
|------|------|------|
| **제어(Control)** | 허용 범위를 사전 정의하고 벗어나면 차단 | Context Files, 가드레일, 린터 |
| **감시(Monitoring)** | 동작·결과를 실시간 추적·기록 | 로그, SSOT, 세션 히스토리 |
| **개선(Feedback)** | 오류를 감지하고 다음 동작에 반영 | 피드백 루프, 자동 수정, 규칙 보강 |

**하네스 변경 시 검증 원칙:** 셸 스크립트는 shellcheck + 수동 검증, hooks는 동작 테스트. 별도의 메타 하네스 레이어는 두지 않는다.

### Phase 태그 규칙

| Phase | 의미 |
|-------|------|
| `[Done]` | 이미 완료됨 |
| `[Ready]` | 즉시 착수 가능 |
| `[P1]` | 1차 강화 |
| `[P2]` | 고도화 |

### 레이어 구조

```
하네스 엔지니어링
├── Layer 1: 개발 도구 하네스 — Claude Code가 안정적으로 동작하는 환경
├── Layer 2: 문서 하네스 — 문서 품질·일관성·현행화를 제어하는 환경
└── Layer 3: 코드 하네스 — Shell Script + Android + WebView 품질을 기계적으로 강제하는 환경
```

---

## Layer 1: 개발 도구 하네스

Claude Code가 프로젝트에서 안정적·예측 가능하게 동작하도록 하는 환경 설계.

### 1-1. Context Files

| 액션 | 설명 | Phase |
|------|------|-------|
| CLAUDE.md T1/T2/T3 계층 로딩 체계 | 세션 시작 시 T1 자동 로딩, 작업 감지 시 T3 온디맨드 로딩 | `[Done]` |
| MEMORY.md 장기 컨텍스트 관리 | 프로젝트 상태, 이슈 현황, 기술 참고 | `[Done]` |
| `progress.md` SSOT 도입 | 세션 간 "지금 뭐 하고 있고 다음에 뭐 할지" 단기 추적 전용. 세션 시작/종료 시 자동 읽기/쓰기. CLAUDE.md T1에 등록 | `[Done]` |

### 1-2. Skills

| 액션 | 설명 | Phase |
|------|------|-------|
| 기본 스킬 4종 | repo-management, update-test, verify, create-skill | `[Done]` |
| `skills/release/SKILL.md` | APK 빌드 → public 배포 → GitHub Release → 미러 검증 | `[Done]` |
| `skills/review/SKILL.md` | 2-pass 코드 리뷰 (Critical + Informational) + Fix-First | `[Done]` |
| `skills/bug-fix/SKILL.md` | 이슈 재현 → 원인분석 → 수정 → 검증 절차서 | `[P1]` |

### 1-3. Hooks & 기계적 강제화

| 액션 | 설명 | Phase |
|------|------|-------|
| Claude Code hook — push 차단 | 사용자 지시 없이 `git push` 차단 | `[Done]` |
| Claude Code hook — 스크립트 동기화 경고 | `.sh` 파일 Write/Edit 시 대응 파일(루트↔앱 assets) 동기화 여부 경고 | `[Done]` |
| Claude Code hook — shellcheck 자동 실행 | `.sh` 파일 Write/Edit 후 shellcheck 자동 수행 | `[Done]` |

### 1-4. SSOT & 모니터링

| 액션 | 설명 | Phase |
|------|------|-------|
| MEMORY.md 장기 컨텍스트 | 프로젝트 상태, 기술 참고, 이슈 현황 | `[Done]` |
| progress.md 세션 추적 | 세션 시작 시 읽고, 종료 시 업데이트 | `[Done]` |

---

## Layer 2: 문서 하네스

오픈소스 프로젝트로서 문서(README, `/docs`, CHANGELOG)의 품질·일관성·현행화를 제어하는 환경.

### 2-1. 문서 포맷 린팅

| 액션 | 설명 | Phase |
|------|------|-------|
| markdownlint 설정 | `.markdownlint-cli2.yaml` 존재 | `[Done]` |
| pre-commit에 markdownlint 추가 | `.md` 파일 변경 시 markdownlint 실행, 실패 시 커밋 차단 | `[Done]` |
| CI에 markdownlint job 추가 | PR/push 시 마크다운 포맷 검증 | `[Done]` |

### 2-2. CHANGELOG 관리

| 액션 | 설명 | Phase |
|------|------|-------|
| CHANGELOG.md 유지 | Keep a Changelog 포맷 | `[Done]` |
| release 스킬에 CHANGELOG 갱신 포함 | 릴리스 체크리스트에 CHANGELOG 항목 확인 | `[Done]` |

### 2-3. 코드-문서 동기화

코드가 수정되면 관련 문서(README, `/docs`)도 함께 현행화되어야 한다. Hook으로 에이전트에게 즉시 알리고, CI에서 누락을 감지하는 이중 안전망.

| 액션 | 설명 | Phase |
|------|------|-------|
| 코드↔문서 매핑 테이블 | 어떤 코드가 어떤 문서와 연관되는지 매핑 정의. CLAUDE.md T3 트리거로 등록 | `[Done]` |
| Claude Code hook — 문서 현행화 리마인더 | 코드 수정 시 매핑 테이블 기반으로 관련 문서 업데이트 필요 여부를 에이전트에게 알림. 에이전트가 직접 문서 수정 | `[Done]` |
| CI 문서 신선도 체크 | 코드 파일과 관련 문서의 마지막 수정일 비교, 코드만 바뀌고 문서가 안 바뀌면 CI 경고 | `[Done]` |

### 2-4. 스크립트 동기화 문서화

| 액션 | 설명 | Phase |
|------|------|-------|
| 동기화 규칙 MEMORY.md 기록 | `post-setup.sh` 루트↔앱 assets 동기화 규칙 | `[Done]` |
| 동기화 규칙 기계적 강제 | → L3 hooks에서 담당 | → L3 |

---

## Layer 3: 코드 하네스

Shell Script + Android(Kotlin) + WebView(React/TypeScript) 품질·안정성을 기계적으로 강제하는 환경. 3가지 기술 스택 각각에 린터·훅·CI 게이트를 적용한다.

### 철학: 3중 하네스로 멱등성 확보

| 단계 | 수단 | 제어 강도 | Shell Script | Android (Kotlin) | WebView (React/TS) |
|------|------|----------|-------------|-----------------|-------------------|
| 1. 규칙 정의 | 문서 | 참조 (부탁) | CLAUDE.md, lib.sh 컨벤션 | CONTRIBUTING.md, detekt.yml | ESLint config |
| 2. 컨텍스트 주입 | CLAUDE.md T2 | 인지 (부탁+) | 스크립트 작성 직전 규칙 읽기 | Kotlin 작성 직전 규칙 읽기 | — |
| 3. 기계적 강제 | 린터 + hooks + CI | 차단 (강제) | shellcheck | ktlint + detekt | ESLint + tsc |

### 3-1. Shell Script 린팅

| 액션 | 설명 | Phase |
|------|------|-------|
| shellcheck 도입 | Shell Script 정적 분석 표준 도구 | `[Done]` |
| `.shellcheckrc` 설정 | Termux 환경 고려한 프로젝트 설정 | `[Done]` |
| pre-commit에 shellcheck 체인 추가 | staged `.sh` 파일 대상 shellcheck 실행, 실패 시 커밋 차단 | `[Done]` |
| CI에 shellcheck job 추가 | PR/push 시 전체 `.sh` 파일 검증 | `[Done]` |

### 3-2. 스크립트 동기화 강제

| 액션 | 설명 | Phase |
|------|------|-------|
| pre-commit 동기화 검증 | `post-setup.sh` 루트↔`android/app/src/main/assets/post-setup.sh` 내용 일치 여부 검사. 불일치 시 커밋 차단 | `[Done]` |
| CI 동기화 검증 | 동일 검사를 CI에서도 실행 | `[Done]` |
| Claude Code hook 동기화 경고 | Write/Edit 시 한쪽만 수정하면 에이전트에게 경고 | `[Done]` |

### 3-3. Android 코드 린팅

| 액션 | 설명 | Phase |
|------|------|-------|
| pre-commit: ktlint + detekt | `.kt` 파일 변경 시 실행 — 기존 hook | `[Done]` |
| detekt.yml ForbiddenMethodCall 추가 | `android.util.Log.*` 금지 — 로깅 추상화 강제 | `[Done]` |
| detekt.yml 코루틴 규칙 강화 | `GlobalScope.*`, `Dispatchers.*` 직접 사용 금지 | `[Done]` |
| CI에 ktlint + detekt job 분리 | 빌드와 별도로 lint job 실행 → 빠른 피드백 | `[Done]` |

### 3-4. Android 테스트 인프라

| 액션 | 설명 | Phase |
|------|------|-------|
| 앱 모듈 테스트 의존성 추가 | JUnit5 + MockK (코루틴 테스트) | `[Done]` |
| 핵심 클래스 유닛 테스트 | CommandRunner, EnvironmentBuilder, AppLogger | `[Done]` |
| CI에 테스트 job 추가 | `./gradlew test` CI 실행 | `[Done]` |
| 테스트 커버리지 게이트 | JaCoCo 도입, 신규 코드 최소 커버리지 설정 | `[P2]` |

### 3-5. Android 아키텍처 강제

| 액션 | 설명 | Phase |
|------|------|-------|
| 로깅 추상화 도입 | `android.util.Log` → AppLogger 래퍼, detekt ForbiddenMethodCall로 강제 | `[P1]` |
| 패키지 구조 분리 | 단일 패키지 → 기능별 서브패키지 (규모 성장 시) | `[P2]` |
| ArchUnit 의존 방향 테스트 | 패키지 분리 후 의존 방향 기계적 검증 | `[P2]` |

### 3-6. WebView/React 코드 린팅

| 액션 | 설명 | Phase |
|------|------|-------|
| ESLint + TypeScript 빌드 | www/ 디렉토리 — tsc 에러 시 빌드 실패 | `[Done]` |
| pre-commit에 www 린트 추가 | `.ts`/`.tsx` 파일 변경 시 `npm run lint` 실행 | `[Done]` |

### 3-7. 프로젝트 규칙 강제

| 액션 | 설명 | Phase |
|------|------|-------|
| `oa` 서브커맨드 금지 규칙 검증 | 개별 도구 실행 명령을 `oa` 서브커맨드로 만들지 않는 규칙 — `oa --*` 패턴 추가 감지 | `[P2]` |
| lib.sh 컨벤션 준수 검증 | `scripts/lib.sh` 공유 라이브러리 사용 패턴 확인 | `[P2]` |

---

## Phase 매핑 타임라인

### [Done] — 이미 완료됨

| 레이어 | 액션 |
|--------|------|
| L1 | CLAUDE.md T1/T2/T3 계층 로딩 체계 |
| L1 | 기본 스킬 4종 (repo-management, update-test, verify, create-skill) |
| L1 | MEMORY.md 장기 컨텍스트 관리 |
| L2 | markdownlint 설정 |
| L2 | CHANGELOG.md 유지 |
| L2 | 동기화 규칙 문서화 |
| L3 | pre-commit: ktlint + detekt |
| L3 | CI: android-build.yml + dependabot |
| L3 | ESLint + TypeScript 빌드 (www/) |
| L1 | progress.md SSOT 도입 + CLAUDE.md T1 등록 |
| L1 | Claude Code hook — push 차단 |
| L2 | 코드↔문서 매핑 테이블 정의 |
| L2 | Claude Code hook — 문서 현행화 리마인더 |
| L3 | shellcheck 도입 + `.shellcheckrc` 설정 |
| L3 | pre-commit에 shellcheck + 동기화 검증 추가 |
| L3 | `.githooks` 활성화 안내 (CONTRIBUTING.md 업데이트) |
| L1 | Claude Code hook — 스크립트 동기화 경고 |
| L1 | Claude Code hook — shellcheck 자동 실행 |
| L2 | pre-commit에 markdownlint 추가 |
| L2 | CI에 markdownlint job 추가 |
| L2 | CI 문서 신선도 체크 |
| L3 | CI에 shellcheck job 추가 |
| L3 | CI 동기화 검증 |
| L3 | detekt.yml ForbiddenMethodCall (Log.* 금지) |
| L3 | detekt.yml 코루틴 규칙 강화 (GlobalScope 금지) |
| L3 | CI에 ktlint + detekt job 분리 |
| L3 | pre-commit에 www 린트 추가 |
| L1 | release 스킬 (APK 빌드 → public 배포 → GitHub Release → 미러 검증) |
| L1 | review 스킬 (2-pass 코드 리뷰 + Fix-First) |
| L2 | release 스킬에 CHANGELOG 갱신 포함 |
| L3 | 앱 모듈 테스트 의존성 + 핵심 클래스 유닛 테스트 (JUnit5 + MockK, 22 tests) |
| L3 | CI에 테스트 job 추가 |

### [P1] — 미완료 잔여

| # | 레이어 | 액션 |
|---|--------|------|
| 10 | L1 | bug-fix 스킬 |
| 24 | L3 | 로깅 추상화 도입 (AppLogger) |

### [P2] — 고도화

| # | 레이어 | 액션 |
|---|--------|------|
| 26 | L3 | 테스트 커버리지 게이트 (JaCoCo) |
| 27 | L3 | 패키지 구조 분리 |
| 28 | L3 | ArchUnit 의존 방향 테스트 |
| 29 | L3 | `oa` 서브커맨드 금지 규칙 검증 |
| 30 | L3 | lib.sh 컨벤션 준수 검증 |

### 전체 조감도

```
        Done            Ready           P1              P2
         │                │              │               │
L1 ──────●●●─────────────●●─────────────●●●●────────────┤
         │                │              │               │
L2 ──────●●●─────────────●●─────────────●●●●────────────┤
         │                │              │               │
L3 ──────●●●─────────────●●●●───────────●●●●●●●●●──────●●●●●
```

---

## 현황 평가 (2026-04-02)

### 5대 구성 요소별 성숙도

| 구성 요소 | 성숙도 | 근거 |
|-----------|:------:|------|
| Context Files | ★★★★★ | T1/T2/T3 계층 로딩 완성. MEMORY.md + progress.md 운용 |
| Skills | ★★★★☆ | 6종 완비 (repo-management, update-test, verify, create-skill, release, review). bug-fix만 미비 |
| Hooks & 린터 | ★★★★★ | pre-commit 6종(ktlint+detekt+shellcheck+동기화+markdownlint+www), Claude Code hooks 4종(push 차단+문서 리마인더+shellcheck+버전 동기화), CI 5 job |
| SSOT | ★★★★☆ | MEMORY.md 장기 + progress.md 단기 추적. 코드↔문서 매핑 운용 |
| 피드백 루프 | ★★★☆☆ | Claude Code hooks + CI 게이트로 자동 피드백 가동 |

### 레이어별 평가

| 레이어 | 달성률 | 상태 | 주요 갭 |
|--------|:------:|------|---------|
| L1 개발 도구 | 95% | Context Files + Hooks + Skills 6종 완성 | bug-fix 워크플로우 스킬 |
| L2 문서 | 95% | 코드-문서 동기화 Hook + CI + CHANGELOG 연동 완성 | — |
| L3 코드 | 85% | 린터+CI+테스트 인프라 완성, detekt 규칙 강화 완료 | 로깅 추상화, 패키지 분리 |

### 종합

| 관점 | 평가 |
|------|------|
| 가장 강한 영역 | Hooks & 린터 — pre-commit 6종 + Claude Code hooks 4종 + CI 5 job |
| 가장 취약한 영역 | L3 아키텍처 — 로깅 추상화(AppLogger 도입) 미완, 패키지 분리 미착수 |
| 다음 투자 시점 | P1 잔여(bug-fix 스킬 + AppLogger) 완료 시 전 레이어 95%+ 달성 |

---

## 관련 문서

- [CLAUDE.md](../../CLAUDE.md) — 프로젝트 컨텍스트 (T1 Context File)
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — 기여 가이드라인
- [MEMORY.md](../memory/MEMORY.md) — 프로젝트 장기 컨텍스트
- [DOCUMENT-MAP.md](DOCUMENT-MAP.md) — 계획 문서 인덱스

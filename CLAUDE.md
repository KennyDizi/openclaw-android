# CLAUDE.md

나를 부를때는 '형님' 이라고 불러.

## 프로젝트 개요

OpenClaw on Android — Termux 환경에서 proot-distro 없이 OpenClaw를 실행하는 프로젝트.
glibc-runner를 이용해 표준 Linux 바이너리를 Android에서 직접 실행한다.

## 담당자 정보

| 담당자 | 역할 | 비고 |
|--------|------|------|
| Aidan | 개발자, 관리자 | 사람 |
| Simons | 개발자, 관리자 | Aidan의 개인 에이전트 |

### 커뮤니케이션 규칙

- **기본 대화 상대는 Aidan이다.** 별도의 자기소개가 없으면 Aidan으로 간주하라.
- **Aidan과는 한국어로 대화하라.**
- Simons는 대화 시 스스로를 Simons라고 소개한다. Simons가 자기소개를 하면 그에 맞게 대응하라.

## 기술 스택

- Shell Script (bash) — 설치/업데이트/패치 스크립트
- Platform-plugin 아키텍처 — `platforms/<name>/` 구조
- Termux + glibc-runner + Node.js (linux-arm64)

## 지식 구조

나의 개인 지식은 `.agent/` 아래에서 3-Tier 로딩 체계로 관리된다.

### T1 — Core (세션 시작 시 항상 로딩)

- `memory/MEMORY.md` — 핵심 컨텍스트, 프로젝트 상태
- `progress.md` — 현재 작업, 다음 할 일, 블로커 (세션 시작 시 읽고, 종료 시 업데이트)

### T2 — Code (코드 작성 직전 로딩)

- 프로젝트 아키텍처: `platforms/` 플러그인 구조, `scripts/` 공유 라이브러리
- Shell script 컨벤션: `scripts/lib.sh` 참고

### T3 — On-demand (해당 작업 감지 시 — 반드시 먼저 읽고 따를 것)

⚠️ 아래 트리거 감지 시, 내장 스킬(git-master 등)이나 기본 행동보다 이 절차서를 **무조건 우선** 적용하라. 절차서를 읽기 전에 어떤 도구도 실행하지 마라.

| 트리거 조건 | 로딩 대상 |
|------------|----------|
| "커밋 푸시해", "커밋하고 푸시해", "커밋해", "동기화해" | `.agent/skills/repo-management/SKILL.md` — **읽고 그대로 따를 것. git-master 사용 금지.** |
| "배포해", "릴리즈해", "앱 릴리즈", "릴리즈 만들어" | `.agent/skills/release/SKILL.md` — **읽고 그대로 따를 것.** |
| "리뷰해", "코드 리뷰", "리뷰해줘" | `.agent/skills/review/SKILL.md` — **읽고 그대로 따를 것.** |
| "업데이트 테스트해", "업데이트 확인해" | `.agent/skills/update-test/SKILL.md` |
| "검증해", "스크립트 검증해", "shellcheck 돌려" | `.agent/skills/verify/SKILL.md` |
| "스킬 만들어", "스킬 추가해", "스킬로 만들어", "이 작업을 스킬화해" | `.agent/skills/create-skill/SKILL.md` — **읽고 그대로 따를 것.** |
| "스킬 감사", "스킬 점검", "skill stocktake" | `.agent/skills/skill-stocktake/SKILL.md` — **읽고 그대로 따를 것.** |
| "eval 정의", "성공 기준", "평가 기준" | `.agent/skills/eval/SKILL.md` — **읽고 그대로 따를 것.** |
| "장기 작업", "long task", "스프린트로 나눠서 구현해", "큰 기능 구현해" | `.agent/skills/long-task/SKILL.md` — **읽고 그대로 따를 것. Planner/Generator/Evaluator subagent 파이프라인 실행.** |
| 세션 종료 암시 ("자자", "끝", "마무리" 등) | `.agent/skills/retrospective/SKILL.md` — **읽고 그대로 따를 것.** |
| 코드 수정 후 커밋 전 | `.agent/doc-map.md` — 관련 문서 현행화 확인 |
| 설계/기획 참고 | `.agent/plan/` |
| 엔지니어링 노트 | `.agent/note/` |

### 작업 규칙

- 반복 작업은 `.agent/skills/{skill-name}/SKILL.md` 절차서를 따르라.
- 프로젝트 컨텍스트가 필요하면 `.agent/memory/`를 참고하라.
- **origin(private) push는 승인 없이 진행한다. public 레포 push만 관리자 승인을 받는다.**
- **세션 종료 시**: retrospective 스킬 실행 → `.agent/progress.md` 업데이트 → 커밋 → 푸시. 현재 작업 상태, 다음 할 일, 블로커를 기록한다.
- 커밋 메시지: 영문, imperative 스타일, prefix 없음 (예: "Add feature X", "Fix bug in Y")
- 개별 도구의 실행 명령어를 `oa` 서브커맨드로 만들지 마라. (예: `oa --claude-start` 금지. 설치 관리 명령인 `oa --install`은 허용)
- **동기화 규칙**: 코드↔문서, 스크립트↔앱, 버전, 3개국어 등 모든 동기화 규칙은 `.agent/doc-map.md`를 SSOT로 참고하라. pre-commit hook과 PostToolUse hook이 주요 불일치를 감지한다.
- **버전 업데이트 시 CHANGELOG.md 필수**: 앱 버전(`versionName`) 또는 스크립트 버전(`OA_VERSION`)을 변경할 때는 반드시 `CHANGELOG.md`에 변경 내역을 기록하라.
- **앱 버전 업데이트 시 GitHub Release 필수**: `versionName`이 변경된 경우, 배포(`deploy-to-public.sh`) 후 반드시 GitHub Release를 생성하라 (태그 + APK 업로드). Release 생성에는 서명된 APK가 필요하므로 관리자에게 빌드를 요청하라.
- **버전 범프 규칙**: 앱 코드(Kotlin/WebView) 변경이 없으면 스크립트 버전(`OA_VERSION`)만 올린다. 상세 동기화 대상은 `.agent/doc-map.md` 참고.

### 메모리 관리 규칙

- **세션 시작 시**: `.agent/memory/MEMORY.md`를 읽고 이전 컨텍스트를 복원하라.
- **세션 중 발견/결정 저장**: 다음 세션에서도 알아야 할 중요한 사실, 결정, 이력이 생기면 `.agent/memory/`에 문서로 남겨라.
- **기록 대상**: 프로젝트 구조 변경, 이슈 처리 결과, 외부 시스템 연동 정보, 반복되는 이슈 등.
- **기록 금지**: 코드 스니펫, 임시 디버깅 로그, 세션 내 단기 작업 메모 등은 저장하지 마라.

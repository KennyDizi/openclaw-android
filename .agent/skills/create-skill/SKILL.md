---
name: create-skill
description: 코딩 에이전트용 스킬을 생성하는 메타스킬. Trigger — "스킬 만들어", "스킬 추가해", "스킬로 만들어", "이 작업을 스킬화해".
license:
compatibility:
metadata:
  author: AidanPark
  version: "1.0"
allowed-tools:
---

# create-skill

대화 중 반복되는 작업이나 새로운 절차를 **코딩 에이전트 스킬**로 정리하여 `.agent/skills/`에 생성한다.

## 필수 규칙

- 이 문서의 형식을 **반드시** 따른다. 임의 형식 금지.
- 스킬 디렉토리명 = frontmatter `name` = 본문 제목 `# {name}` — 셋 다 일치.
- 네이밍: **kebab-case** (예: `my-new-skill`).
- 본문은 **한국어**로 작성. 코드 블록만 영어.
- 기존 `.agent/skills/` 내 스킬과 이름 충돌 금지.
- 스킬의 핵심은 **절차서**(SKILL.md)이다. 보조 스크립트가 필요하면 스킬 디렉토리 하위 `scripts/`에 배치한다.

## 사용법

### 1단계: 스킬 이름 결정

스킬의 핵심 동작을 표현하는 kebab-case 이름을 정한다.

- **동사+목적명사** 또는 **명사-명사** 형태
- 예: `repo-management`, `create-skill`, `update-test`
- 기존 스킬과 충돌 여부를 먼저 확인한다:

```bash
ls .agent/skills/
```

### 2단계: 디렉토리 생성

```bash
mkdir -p .agent/skills/{skill-name}
```

### 3단계: SKILL.md 작성

아래 템플릿을 기반으로 작성한다.

#### frontmatter 템플릿

```yaml
---
name: {kebab-case-이름}
description: 한국어 설명. Trigger — "트리거1", "트리거2".
license:
compatibility: 필요 조건 (해당 시)
metadata:
  author: AidanPark
  version: "1.0"
allowed-tools:
---
```

**frontmatter 필드 설명:**

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | 스킬 식별자 (kebab-case). 디렉토리명과 일치 |
| `description` | ✅ | 스킬 설명. **Trigger 문구 포함 필수** — 에이전트가 이 텍스트로 스킬을 매칭 |
| `license` | 선택 | 비워둬도 됨 |
| `compatibility` | 선택 | 실행 조건/의존성 |
| `metadata.author` | 권장 | 작성자 |
| `metadata.version` | 권장 | 버전 |
| `allowed-tools` | 선택 | 비워두면 제한 없음 |

#### 본문 섹션 (순서 고정, 해당 시에만 포함)

1. `# {name}` — frontmatter name과 일치
2. 소개 (1-2문장, 제목 없이)
3. `## 필수 규칙` — 에이전트가 지켜야 할 제약
4. `## 트리거` — 트리거 문구와 요약 테이블 (기존 스킬 패턴)
5. `## 범위` — 스킬이 하는 일과 하지 않는 일
6. `## 사용법` 또는 `## 절차` — 단계별 절차, 도구 사용 예시 포함
7. `## 보고서 형식` — 출력 형식 (해당 시)
8. `## 주의사항` 또는 `## 참고` — 추가 정보

### 4단계: description 트리거 작성

description에 **사용자가 실제로 말할 트리거 문구**를 포함한다.

```yaml
# 좋은 예 — Trigger 문구가 구체적
description: 리포지토리 관리 절차서. Trigger — "커밋 푸시해", "배포해".

# 나쁜 예 — 트리거 없음
description: 리포지토리를 관리하는 스킬
```

### 5단계: 검증

- [ ] SKILL.md frontmatter의 `name`과 디렉토리명이 일치하는가?
- [ ] description에 Trigger 문구가 포함되어 있는가?
- [ ] 기존 스킬과 이름 충돌이 없는가?
- [ ] 본문이 한국어로 작성되었는가?
- [ ] 절차가 명확하고 모호함이 없는가?

### 6단계: CLAUDE.md 트리거 등록

스킬 생성 후 **반드시** `CLAUDE.md`의 **T3 — On-demand** 테이블에 트리거 조건과 로딩 대상을 추가한다.

```markdown
| "트리거 문구1", "트리거 문구2" | `.agent/skills/{skill-name}/SKILL.md` |
```

- 트리거 문구는 description의 Trigger와 동일하게 작성한다.
- **등록하지 않으면 세션 시작 시 스킬이 자동 로딩되지 않는다.**

## 참고

- 기존 스킬 참고: `.agent/skills/repo-management/SKILL.md`, `.agent/skills/update-test/SKILL.md`
- CLAUDE.md에서 `.agent/skills/`의 스킬은 T3 테이블의 트리거 매칭으로 로딩됨

---
name: verify
description: "프로젝트 스크립트의 정적 분석(shellcheck), install/update 플로우 무결성, 변경 영향 분석을 검증한다. 6단계 구조화 리포트 + READY/NOT READY 판정. Trigger — '검증해', '스크립트 검증해', 'shellcheck 돌려'."
license:
compatibility: shellcheck 설치 필요
metadata:
  author: AidanPark
  version: "3.0"
allowed-tools:
---

## 트리거

| 트리거 | 요약 |
|--------|------|
| "검증해", "스크립트 검증해", "shellcheck 돌려" | shellcheck + install/update 플로우 무결성 + 변경 영향 분석 검증 |

## 범위

- 프로젝트 내 모든 .sh 파일에 대한 shellcheck 정적 분석
- install.sh / update-core.sh 플로우에서 참조하는 모든 스크립트·파일의 무결성 확인
- OA_VERSION 상수 일관성 확인
- 변경된 코드가 다른 기능/플로우에 부작용을 일으키는지 영향 분석
- **코드 수정은 이 스킬의 범위 밖** — 문제 발견 시 보고만 한다

---

## 절차

```
Step 1. shellcheck 설치 확인
   - command -v shellcheck
   └─ 없음 → "shellcheck 미설치. 설치 필요: apt install shellcheck 또는 pkg install shellcheck" 보고 → 종료
   └─ 있음 → 계속

Step 2. shellcheck 실행
   대상: 프로젝트 루트의 모든 .sh 파일
   - find . -name "*.sh" -not -path "./.agent/*" -not -path "./.git/*"
   옵션: shellcheck -s bash -S warning <파일>
     - -s bash: bash 문법
     - -S warning: warning 이상만 출력 (info/style 제외)
   
   각 파일별 결과를 심각도(error, warning)로 분류
   └─ error 0건 & warning 0건 → "shellcheck PASS"
   └─ error 또는 warning 1건 이상 → 문제 목록 정리

   [2-1] 알려진 허용 패턴 (보고서에 별도 분류)
   - SC1090 (Can't follow non-constant source) — 동적 source 경로, 프로젝트 구조상 불가피
   - SC1091 (Not following source) — 런타임에만 존재하는 파일 source
   이 두 코드는 "허용된 경고" 섹션에 분리 보고한다

Step 3. Install 플로우 무결성 검증

   [3-1] install.sh 직접 참조 파일 존재 확인
   install.sh 내의 source, bash 명령이 참조하는 모든 파일:
   - scripts/lib.sh                  (source)
   - scripts/check-env.sh            (bash)
   - scripts/install-infra-deps.sh   (bash)
   - scripts/setup-paths.sh          (bash)
   - scripts/install-glibc.sh        (bash, conditional)
   - scripts/install-nodejs.sh       (bash, conditional)
   - scripts/install-build-tools.sh  (bash, conditional)
   - scripts/setup-env.sh            (bash)
   - scripts/install-code-server.sh  (bash, optional)
   - scripts/install-opencode.sh     (bash, optional)
   - tests/verify-install.sh         (bash)
   └─ 각 파일 존재 확인. 누락 → ❌ 보고

   [3-2] 플랫폼 플러그인 필수 파일 존재 확인
   platforms/ 하위 각 플랫폼 디렉토리에 다음 파일이 모두 존재해야 한다:
   - config.env
   - install.sh
   - update.sh
   - uninstall.sh
   - env.sh
   - status.sh
   - verify.sh
   └─ 누락 → ❌ 보고 (어떤 플랫폼의 어떤 파일이 없는지 명시)

   [3-3] 플랫폼 config.env 플래그 검증
   각 플랫폼의 config.env에서 PLATFORM_NEEDS_* 플래그를 읽고,
   true인 플래그에 대응하는 설치 스크립트가 존재하는지 확인:
   - PLATFORM_NEEDS_GLIBC=true   → scripts/install-glibc.sh
   - PLATFORM_NEEDS_NODEJS=true  → scripts/install-nodejs.sh
   - PLATFORM_NEEDS_BUILD_TOOLS=true → scripts/install-build-tools.sh
   - PLATFORM_NEEDS_PROOT=true   → (pkg install, 스크립트 불요)
   └─ 플래그 true인데 스크립트 없음 → ❌ 보고

Step 4. Update 플로우 무결성 검증

   [4-1] update-core.sh 가 복사하는 소스 파일 존재 확인
   update-core.sh의 cp 명령에서 참조하는 원본 파일이 프로젝트에 존재하는지:
   (a) 스크립트/설정
   - scripts/lib.sh
   - scripts/setup-env.sh
   - oa.sh
   - update.sh
   - uninstall.sh
   (b) 패치 파일
   - patches/glibc-compat.js
   - patches/argon2-stub.js
   - patches/spawn.h
   - patches/systemctl
   └─ 누락 → ❌ 보고

   [4-2] update-core.sh REQUIRED_FILES 배열 검증
   update-core.sh 내 REQUIRED_FILES 배열의 항목이 프로젝트에 실제 존재하는지:
   - scripts/lib.sh
   - scripts/setup-env.sh
   - platforms/$PLATFORM/config.env
   - platforms/$PLATFORM/update.sh
   └─ 누락 → ❌ 보고

   [4-3] 선택적 도구 설치 스크립트 존재 확인
   update-core.sh에서 조건부로 호출하는 스크립트:
   - scripts/install-code-server.sh
   - scripts/install-opencode.sh
   - scripts/install-glibc.sh     (Bionic→glibc 마이그레이션)
   - scripts/install-nodejs.sh    (Bionic→glibc 마이그레이션)
   └─ 누락 → ❌ 보고

Step 5. 버전 일관성 검증
   OA_VERSION 값이 다음 4개 파일에서 동일한지 확인:
   - scripts/lib.sh       → grep 'OA_VERSION=' (정의부)
   - install-tools.sh     → grep 'OA_VERSION=' (정의부)
   - update-core.sh       → grep 'OA_VERSION=' (정의부)
   - oa.sh                → grep 'OA_VERSION=' (fallback 정의부)
   └─ 모두 동일 → ✅ PASS
   └─ 불일치 → ❌ 파일별 값 보고

Step 6. 검증 스크립트 정합성
   검증/상태 스크립트 내부의 경로 참조가 실제 설치 스크립트의 경로와 일치하는지 확인한다.

   [6-1] 검증 대상 파일
   - tests/verify-install.sh
   - platforms/*/status.sh
   - platforms/*/verify.sh

   [6-2] 경로 정합성 확인
   위 파일들이 참조하는 경로(wrapper, marker, glibc 등)가
   실제 설치 스크립트(scripts/install-*.sh, post-setup.sh)에서
   생성하는 경로와 일치하는지 교차 검증한다.
   - lib.sh의 공유 변수($PROJECT_DIR, $BIN_DIR 등)를 사용하는지 확인
   - 하드코딩된 경로가 있다면 실제 설치 경로와 일치하는지 확인
   └─ 모두 일치 → ✅ PASS
   └─ 불일치 → ❌ "검증 스크립트 <파일>:<라인>의 경로가 실제 설치 경로와 불일치"

Step 7. 변경 영향 분석
   커밋되지 않은 변경 또는 직전 커밋의 변경을 대상으로 분석한다.

   [7-1] 변경 파일 수집
   - git diff --name-only (unstaged + staged)
   - 변경 없으면 git diff --name-only HEAD~1 (직전 커밋)
   - .agent/ 하위 파일은 분석 대상에서 제외

   [7-2] 호출 관계 추적
   변경된 각 파일에 대해:
   - 이 파일을 source/bash/cp 하는 다른 스크립트 검색
     grep -rl "source.*<filename>\|bash.*<filename>\|cp.*<filename>" --include="*.sh"
   - 이 파일이 source/bash 하는 대상 파일이 존재하는지 확인

   [7-3] 변경 지점 안전성 검증
   변경된 라인(git diff)을 읽고 다음을 확인:

   (a) set -e 안전성
       - 호출하는 스크립트가 set -e/set -euo pipefail 을 사용하는 경우
       - 실패 가능한 명령에 || true 또는 적절한 에러 핸들링이 있는지
       - 없으면 ❌ "set -e 환경에서 <파일>:<라인> 이 실패하면 스크립트 중단됨"

   (b) 실행 시점 의존성
       - 추가된 명령(예: openclaw, node, npm)이 해당 실행 시점에 설치되어 있는지
       - post-setup.sh에서 Step N에 추가한 명령이 Step N 이전에 설치되는지 확인
       - update-core.sh에서 사용하는 명령이 PATH에 있는지 확인
       - 없으면 ❌ "<명령>이 <파일>:<라인>에서 호출되지만, 이 시점에 아직 설치되지 않았을 수 있음"

   (c) 변수/함수 영향
       - 변경된 변수나 함수가 다른 파일에서 참조되는지 검색
       - 이름 변경 또는 삭제된 경우, 참조하는 모든 곳이 함께 수정되었는지
       - 없으면 ❌ "<변수/함수>가 <파일>에서 참조되지만 수정되지 않음"

   (d) 동기화 대상 확인
       - post-setup.sh 변경 시: android/app/src/main/assets/post-setup.sh 도 동일하게 변경되었는지
       - docs/ 변경 시: 3개국어(영/한/중) 모두 수정되었는지
       - 없으면 ❌ "동기화 누락: <파일>"

   [7-4] Delivery Path Parity (경로 간 기능 동기화)
   `.agent/skills/verify/feature-map.md`의 "Delivery Path Parity" 섹션을 참조하여:

   (a) 변경 파일 → 기능 → 경로 매핑
       - 변경된 파일이 "기능 ↔ 경로 매핑" 표의 어느 기능에 해당하는지 확인
       - 해당 기능이 존재하는 다른 경로(App Install / Termux Install / Update) 확인

   (b) 다른 경로 동등 변경 확인
       - 해당 기능의 다른 경로 스크립트에도 동등한 변경이 있는지 확인
       - 1:1 파일 매칭이 아닌 기능 단위로 비교
       - 예: platforms/openclaw/update.sh에 mDNS fix 추가 시
         → post-setup.sh에도 있는지? (App Install 경로)
         → platforms/openclaw/install.sh에도 있는지? (Termux Install 경로)

   └─ 모든 경로에 동등 변경 있음 → ✅ PASS
   └─ 누락 경로 있음 → ❌ "기능 X가 경로 A에 추가되었지만, 경로 B에 누락"

   [7-5] Feature 상충 분석
   `.agent/skills/verify/feature-map.md`를 참조하여:

   (a) 변경 파일 → Feature 식별
       - 변경된 파일이 속한 Feature(F1~F8) 결정
       - "공유 자원 → Feature 매핑" 표에서 영향받는 다른 Feature 확인

   (b) 알려진 상충 관계 검증
       - feature-map.md의 "알려진 상충 관계" 섹션에서 해당 Feature 쌍 찾기
       - 해당 쌍의 "검증 방법"을 수행
       - 예: F2(Update) 변경 → F3(Patch) 상충 확인
         "npm install 후 반드시 openclaw-apply-patches.sh가 호출되는지"

   (c) 새로운 상충 발견 시
       - 기존 맵에 없는 Feature 간 의존/상충을 발견하면 보고서에 기재
       - 검증 완료 후 feature-map.md에 추가

   └─ 상충 없음 → ✅ PASS
   └─ 상충 발견 → ❌ 어떤 Feature 쌍에서 어떤 문제인지 보고

   [7-6] 영향받는 플로우 요약
   변경사항이 영향을 주는 플로우를 목록화:
   - 초기 설치 (post-setup.sh)
   - 업데이트 (oa --update → update-core.sh → platforms/*/update.sh)
   - 삭제 (uninstall.sh)
   - CLI (oa.sh)
   └─ 문제 없음 → ✅ PASS
   └─ 문제 있음 → ❌ 항목별 보고

Step 8. 보고서 작성
```

---

## 보고서 형식

```markdown
## 스크립트 검증 결과

### 실행 환경
- 날짜: [YYYY-MM-DD]
- shellcheck 버전: [X.X.X]

### 1. shellcheck 결과

| 심각도 | 건수 |
|--------|------|
| error | N |
| warning | N |

전체 결과: ✅ PASS / ❌ FAIL

#### 문제 상세 (있는 경우)

| 파일 | 라인 | 코드 | 심각도 | 내용 |
|------|------|------|--------|------|
| scripts/xxx.sh | 42 | SC2086 | warning | Double quote to prevent globbing |

#### 허용된 경고 (SC1090, SC1091)

| 파일 | 라인 | 코드 | 내용 |
|------|------|------|------|
| ... | ... | ... | ... |

### 2. Install 플로우 무결성

| 검증 항목 | 결과 |
|-----------|------|
| 참조 스크립트 존재 (N/N) | ✅ / ❌ |
| 플랫폼 필수 파일 (N/N) | ✅ / ❌ |
| config.env 플래그 일치 | ✅ / ❌ |

(실패 항목 상세)

### 3. Update 플로우 무결성

| 검증 항목 | 결과 |
|-----------|------|
| 복사 대상 파일 존재 (N/N) | ✅ / ❌ |
| REQUIRED_FILES 배열 일치 | ✅ / ❌ |
| 선택적 스크립트 존재 | ✅ / ❌ |

(실패 항목 상세)

### 4. 버전 일관성

| 파일 | OA_VERSION |
|------|------------|
| scripts/lib.sh | X.X.X |
| update-core.sh | X.X.X |
| oa.sh | X.X.X |

결과: ✅ 일치 / ❌ 불일치

### 5. 검증 스크립트 정합성

| 검증 파일 | 경로 참조 | 실제 설치 경로 | 결과 |
|-----------|----------|--------------|------|
| tests/verify-install.sh | $BIN_DIR/node | $BIN_DIR/node | ✅ / ❌ |

결과: ✅ PASS / ❌ FAIL

### 6. 변경 영향 분석

#### 변경 파일
| 파일 | 변경 유형 |
|------|----------|
| path/to/file.sh | modified / added / deleted |

#### 호출 관계
| 변경 파일 | 참조하는 스크립트 |
|----------|-----------------|
| platforms/openclaw/update.sh | update-core.sh (bash) |

#### 안전성 검증
| 검증 항목 | 결과 | 상세 |
|-----------|------|------|
| set -e 안전성 | ✅ / ❌ | (위험 지점 상세) |
| 실행 시점 의존성 | ✅ / ❌ | (미설치 가능성 상세) |
| 변수/함수 영향 | ✅ / ❌ | (미수정 참조 상세) |
| 동기화 대상 | ✅ / ❌ | (누락 파일 상세) |

#### Delivery Path Parity
| 기능 | App Install | Termux Install | Update | 상태 |
|------|------------|----------------|--------|------|
| mDNS 비활성화 | post-setup.sh:445 | platforms/openclaw/install.sh:74 | platforms/openclaw/update.sh:49 | ✅ / ❌ |

#### Feature 상충 분석
| 변경 Feature | 영향받는 Feature | 상충 여부 | 상세 |
|-------------|-----------------|----------|------|
| F2 (Update) | F3 (Patch) | ✅ / ❌ | (검증 내용) |

#### 영향받는 플로우
- [ ] 초기 설치 / [ ] 업데이트 / [ ] 삭제 / [ ] CLI

결과: ✅ PASS / ❌ FAIL

### 종합

| 항목 | 결과 |
|------|------|
| shellcheck | ✅ PASS / ❌ FAIL (error N건, warning N건) |
| Install 플로우 | ✅ PASS / ❌ FAIL |
| Update 플로우 | ✅ PASS / ❌ FAIL |
| 버전 일관성 | ✅ PASS / ❌ FAIL |
| 검증 스크립트 정합성 | ✅ PASS / ❌ FAIL |
| 변경 영향 분석 | ✅ PASS / ❌ FAIL |

전체: ✅ ALL PASS / ❌ N건 FAIL
```

---

## 리포트 형식 — 구조화된 VERIFICATION REPORT

모든 Step 완료 후, 아래 형식의 구조화된 리포트를 출력한다:

```
VERIFICATION REPORT
===================

Phase 1 — shellcheck:          [PASS/FAIL] (error N건, warning N건)
Phase 2 — Install 플로우:       [PASS/FAIL] (N/N 항목 통과)
Phase 3 — Update 플로우:        [PASS/FAIL] (N/N 항목 통과)
Phase 4 — 버전 일관성:          [PASS/FAIL]
Phase 5 — 검증 스크립트 정합성:  [PASS/FAIL]
Phase 6 — 변경 영향 분석:       [PASS/FAIL/SKIP] (이슈 N건)

Delivery Path Parity:
  - App Install (post-setup.sh):    [OK/ISSUE]
  - Termux Install (install.sh):    [OK/ISSUE]
  - Update (update-core.sh):        [OK/ISSUE]

종합: [READY / NOT READY]
```

## 판정 규칙

- Phase 1에서 error 1건 이상 → NOT READY
- Phase 2~5 중 하나라도 FAIL → NOT READY
- Phase 6 FAIL → NOT READY (단, 의도적 변경이면 사용자 확인 후 READY 가능)
- **Delivery Path Parity ISSUE** → NOT READY (양 버전 동기화 미확인)
- 모든 Phase PASS (또는 Phase 6 SKIP) → READY, 커밋 진행 가능

## 실패 시 대응

1. FAIL 항목을 수정한다
2. 수정 후 실패한 Phase부터 재실행한다 (전체 재실행 불필요)
3. 3회 연속 같은 Phase에서 실패하면 사용자에게 보고한다

---

## 주의사항

1. **코드 수정을 시도하지 않는다** — 보고만 한다
2. **반드시 별도 에이전트가 검증한다** — 코드를 작성한 에이전트가 직접 검증하면, 동일한 맹점이 코드와 검증 양쪽에 복제된다. 이 스킬을 트리거하는 에이전트는 Agent 도구로 별도 서브에이전트를 생성하여 검증을 위임해야 한다. 서브에이전트는 이 SKILL.md를 읽고 절차를 독립적으로 수행한다.
3. SC1090, SC1091은 프로젝트 구조상 불가피한 경고이므로 "허용된 경고"로 분리한다
4. .agent/ 하위 스크립트(merge-to-main.sh, sync-from-private.sh)는 검증 대상에서 제외한다 (배포되지 않는 관리용 스크립트)
5. 새로운 플랫폼 플러그인이 추가되면 [3-2] 항목이 자동으로 해당 플랫폼도 검증한다
6. 새로운 스크립트가 install.sh 또는 update-core.sh에 추가되면, 이 스킬의 [3-1], [4-1] 항목도 함께 업데이트해야 한다
7. 변경 영향 분석(Step 6)은 변경사항이 있을 때만 수행한다. 변경이 없으면 SKIP
8. 변경 영향 분석에서 ❌ 항목이 있어도 최종 판단은 사용자에게 맡긴다 — 의도적 변경일 수 있음
9. **Delivery Path Parity 필수**: 변경사항이 Termux 설치와 앱 설치 양쪽 경로 모두에서 동작하는지 확인한다. 한쪽 경로만 수정되었으면 반드시 보고한다.

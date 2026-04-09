---
name: repo-management
description: 리포지토리 관리 절차서. 커밋/푸시/동기화 작업을 수행한다. Trigger — "커밋 푸시해"(커밋 + origin push), "동기화해"(검증 후 public 레포에 동기화).
license:
compatibility: Requires git and access to origin + public remotes
metadata:
  author: AidanPark
  version: "4.0"
allowed-tools:
---

## 관리 의도

이 프로젝트는 **두 개의 GitHub 레포**를 사용한다:

| 레포 | 공개 | 역할 |
|------|------|------|
| `openclaw-android-private` | private | 작업 레포. 모든 파일 포함 |
| `openclaw-android` | public | 배포 레포. 숨김파일 제외 |

- 모든 작업은 **private 레포의 main 브랜치**에서 진행한다.
- 배포 시 **숨김파일을 제외**하고 public 레포에 반영한다.
- 브랜치는 `main` 하나만 사용한다. 별도 브랜치를 두지 않는다.

---

## Remote 구조

| Remote | 레포 | 브랜치 | 용도 |
|--------|------|--------|------|
| `origin` | AidanPark/openclaw-android-private | main | 일상 작업, 커밋/푸시 |
| `public` | AidanPark/openclaw-android | main | 배포 (숨김파일 제외) |

---

## 숨김파일 (배포 제외 대상)

public 레포에 포함되면 안 되는 파일:

- `.agent/` — 에이전트 지식, 스킬, 메모리
- `CLAUDE.md` — 에이전트 설정

이 파일들은 private 레포에서만 관리되며, 배포 스크립트(`deploy-to-public.sh`)가 자동 제외한다.

---

## 트리거

| 트리거 | 요약 |
|--------|------|
| "커밋 푸시해", "커밋하고 푸시해", "커밋해" | main에서 커밋 + origin(private) push |
| "동기화해" | 검증 + 숨김파일 제외하고 public 레포에 동기화 |

---

## "커밋 푸시해" 절차

```
Step 1. 브랜치 확인
   └─ main이 아님 → 사용자에게 확인:
      1) main으로 체크아웃 후 진행
      2) 취소
   └─ main → 계속

Step 2. git add -A
   └─ 변경사항 없음 (staged/unstaged/untracked 모두 없음) → "커밋할 변경사항이 없습니다" → 종료
   └─ 변경사항 있음 → 계속

Step 3. 커밋 메시지 작성
   - 변경사항 분석: 코드 변경과 숨김파일 변경 구분
   - 숨김파일: .agent/, .claude/, CLAUDE.md
   - 모든 변경사항을 기술한 메시지 작성 (숨김파일 변경도 포함)
   - 예: "Add version sync hook and update harness rules"

Step 4. git commit -m "작성된 메시지"

Step 5. git push origin main

   └─ 성공 → 완료 보고
   └─ rejected (non-fast-forward) → Step 5a로
   └─ 기타 실패 → 사용자에게 보고

Step 5a. 자동 복구 (remote가 앞서 있는 경우)
   git pull origin main --no-edit
   └─ 성공 (자동 머지) → git push origin main → 완료 보고
   └─ 충돌 → 사용자에게 보고, 수동 해결 필요
```

---

## "동기화해" 절차

public 레포에 코드를 동기화한다. 검증 + deploy-to-public.sh 실행.
전체 배포/릴리즈 절차는 `.agent/skills/release/SKILL.md`를 참고하라.

```
Step 1. 미커밋 변경사항 확인
   └─ 있음 → "커밋 푸시해" 절차 먼저 수행
   └─ 없음 → 계속

Step 2. deploy-to-public.sh 실행
   ./.agent/skills/repo-management/scripts/deploy-to-public.sh "커밋 메시지"

   커밋 메시지 규칙:
   - 코드 변경사항만 기술한다
   - 숨김파일(.agent/, .claude/, CLAUDE.md) 관련 내용은 포함하지 않는다

   └─ "배포할 변경사항 없음" → 종료
   └─ 성공 → 완료 보고
   └─ 실패 → 아래 "스크립트 중도 실패 시 대응" 수행
```

---

## 스크립트 참고

### deploy-to-public.sh

private 레포(main)의 코드를 public 레포(main)에 반영한다. 숨김파일은 자동 제외.

#### 실행

```bash
./.agent/skills/repo-management/scripts/deploy-to-public.sh "커밋 메시지"
```

#### 동작 순서

1. 사전 검증 (main 브랜치, clean 상태, public 리모트 존재)
2. `git fetch public main`
3. 임시 브랜치(`_deploy_tmp`) 생성 (public/main 기준)
4. 기존 파일 전부 제거 후 private main의 파일로 교체 (checkout 방식 — 충돌 없음)
5. 숨김파일 제거
6. 변경사항 커밋
7. `git push public HEAD:main`
8. 임시 브랜치 삭제, main으로 복귀

#### 스크립트 중도 실패 시 대응

```
1. 임의 수동 복구 시도 금지

2. 안전한 상태로 복귀
   - rm -f .git/index.lock  (lock 파일이 남아있는 경우)
   - git checkout main
   - git branch -D _deploy_tmp 2>/dev/null || true

3. 사용자에게 보고
   - 어떤 단계에서 실패했는지 (step 번호 + 에러 메시지)
   - 스크립트 재실행 또는 수동 진행 중 선택을 요청

4. 사용자 지시에 따라 진행
```

---

## 핵심 규칙

1. **작업은 항상 private 레포(origin)의 main에서 진행**
2. **public 레포에 숨김파일 포함 절대 금지** — 배포 스크립트가 자동 제외
3. 숨김파일 목록은 `deploy-to-public.sh`의 `PRIVATE_FILES` 배열로 관리
4. origin(private) push는 승인 없이 진행한다. public push만 관리자 승인을 받는다
5. 커밋 메시지: 영문, imperative 스타일, prefix 없음

---

## 일반적인 작업 흐름

```
1. private 레포(origin)의 main에서 코드 작업
2. "커밋 푸시해" → origin(private) push
3. 배포 준비 완료 시 "배포해" → release 스킬의 전체 절차 (검증 + 동기화 + 릴리즈)
4. public 동기화만 필요 시 "동기화해" → deploy-to-public.sh 실행
```

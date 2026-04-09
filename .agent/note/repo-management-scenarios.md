# 레포지토리 관리 시나리오

> ⚠️ **OUTDATED** — 이 문서는 private/main 이중 브랜치 구조 기준으로 작성되었다. 현재 프로젝트는 **단일 main 브랜치 + origin/public 이중 리모트** 구조를 사용한다. 최신 절차는 `.agent/skills/repo-management/SKILL.md`를 참고하라.

> SKILL: `.agent/skills/repo-management/SKILL.md` 기준

## 전제

| 항목 | 값 |
|------|-----|
| 작업자 | AidanPark (PC1, PC2), 시몬스 (자체 시스템) |
| 브랜치 | `private` (작업), `main` (배포) |
| Remote | `origin` (public), `private` (private) |
| private 파일 | `.agent/`, `CLAUDE.md` |

---

# A. "커밋 푸시해" 시나리오

## A-1. 정상 흐름 — private 브랜치, 로컬이 최신

**상황**: private 체크아웃, 코드 + private 파일 변경, private remote와 동기화된 상태

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 브랜치 확인 → private | 계속 |
| 2 | `git add -A` → 변경사항 있음 | 계속 |
| 3 | 코드 변경 + private 변경 → 코드만 기술한 메시지 작성 | 메시지 생성 |
| 4 | 사용자에게 메시지 제시 → 승인 | 계속 |
| 5 | `git commit -m "승인된 메시지"` | 커밋 |
| 6 | `git push private private` → 성공 | 완료 보고 |

---

## A-2. main 브랜치에서 발동

**상황**: main 체크아웃 상태에서 "커밋 푸시해" 발동

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 브랜치 확인 → main (private 아님) | 선택지 제시 |

- **1) private로 체크아웃 후 진행** → `git checkout private` → Step 2부터 계속
- **2) 취소** → 종료

---

## A-3. 변경사항 없음

**상황**: private 체크아웃, 모든 파일이 이미 커밋된 상태

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 브랜치 확인 → private | 계속 |
| 2 | `git add -A` → 변경사항 없음 | "커밋할 변경사항이 없습니다" → **종료** |

Step 3~6 진입하지 않음.

---

## A-4. private 파일만 변경

**상황**: private 체크아웃, `.agent/` 또는 `CLAUDE.md`만 수정, 코드 변경 없음

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 브랜치 확인 → private | 계속 |
| 2 | `git add -A` → 변경사항 있음 | 계속 |
| 3 | private 파일만 변경 → 빈 메시지 | 빈 메시지 |
| 4 | 사용자에게 "(private 파일만 변경)" 안내 → 승인 | 계속 |
| 5 | `git commit --allow-empty-message -m ""` | 커밋 |
| 6 | `git push private private` → 성공 | 완료 보고 |

---

## A-5. push 거부 — 다른 작업자/PC가 먼저 push (자동 복구)

**상황**: PC1에서 작업 중 시몬스(또는 PC2)가 먼저 private remote에 push. PC1이 뒤쳄진 상태에서 push 시도.

### 충돌 없는 경우 (자동 성공)

| Step | 행동 | 결과 |
|------|------|------|
| 1~5 | (A-1과 동일) 커밋까지 완료 | 계속 |
| 6 | `git push private private` → **rejected** | Step 6a로 |
| 6a | `git pull private private --no-edit` → 자동 머지 성공 | 계속 |
| 6a+ | `git push private private` → 성공 | 완료 보고 |

### 충돌 발생 시 (실패 + 보고)

| Step | 행동 | 결과 |
|------|------|------|
| 1~5 | (A-1과 동일) 커밋까지 완료 | 계속 |
| 6 | `git push private private` → **rejected** | Step 6a로 |
| 6a | `git pull private private --no-edit` → **충돌 발생** | 사용자에게 보고 |

사용자가 충돌 해결 후 `git add` + `git commit` + `git push private private`로 완료.
---

## A-6. PC 이동 — PC1에서 작업 후 PC2에서 이어 작업

**상황**: PC1에서 커밋 푸시 완료. PC2에서 이어서 작업하려는데 PC2 로컬이 뒤쳄짐.

| Step | 행동 | 결과 |
|------|------|------|
| 0 | PC2에서 `sync-from-private.sh` (작업 시작 전 동기화) | PC1 변경분 반영 |
| 1~6 | (A-1과 동일) | 완료 |

**주의**: Step 0을 생략하면 A-5 상황 발생.

---

# B. "배포해" 시나리오

## B-1. 정상 흐름 — private, clean 상태, 코드 변경 있음

**상황**: private 체크아웃, 미커밋 변경 없음, main 대비 코드 변경 있음

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 미커밋 변경사항 확인 → 없음 | 계속 |
| 2 | `sync-from-private.sh` 실행 → 성공 | 계속 |
| 3 | private과 main 코드 차이 확인 (private 파일 제외) → 코드 변경 있음 | 계속 |
| 4 | 커밋 메시지 작성 (코드 변경만 기술) | 메시지 생성 |
| 5 | 사용자에게 메시지 제시 → 승인 | 계속 |
| 6 | `merge-to-main.sh "승인된 메시지"` → 성공 | 계속 |
| 7 | 완료 보고 | 종료 |

---

## B-2. main 브랜치에서 발동

**상황**: main 체크아웃, 미커밋 변경 없음, 코드 변경 있음

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 미커밋 변경사항 확인 → 없음 | 계속 |
| 2 | `sync-from-private.sh` 실행 → 성공 (스크립트 내부에서 main으로 복귀) | 계속 |
| 3~7 | (B-1과 동일) | 종료 |

양 스크립트 모두 `ORIGINAL_BRANCH` 저장/복귀 로직 있음.

---

## B-3. 미커밋 변경사항 있음

**상황**: private 체크아웃, 코드 수정 (미커밋)

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 미커밋 변경사항 확인 → **있음** | "커밋 푸시해" 먼저 수행 |

**→ "커밋 푸시해" Step 1~6 실행 → 완료 후 "배포해" Step 2로 복귀**

| Step | 행동 | 결과 |
|------|------|------|
| 2 | `sync-from-private.sh` 실행 → 성공 | 계속 |
| 3~7 | (B-1과 동일) | 종료 |

---

## B-4. 코드 변경 없음 (private 파일만 변경)

**상황**: private에서 `.agent/`, `CLAUDE.md`만 변경, 코드는 main과 동일

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 미커밋 변경사항 확인 → 없음 (이미 커밋됨) | 계속 |
| 2 | `sync-from-private.sh` 실행 → 성공 | 계속 |
| 3 | private과 main 코드 차이 확인 (private 파일 제외) → **코드 변경 없음** | "배포할 코드 변경사항이 없습니다. 동기화만 완료." → **종료** |

Step 4~7 진입하지 않음. `merge-to-main.sh` 실행 불필요.

---

## B-5. sync 중 충돌 — 다른 작업자가 같은 파일 수정

**상황**: PC1에서 배포하려는데, 시몬스가 같은 파일을 수정하여 private remote에 push한 상태

| Step | 행동 | 결과 |
|------|------|------|
| 1 | 미커밋 변경사항 확인 → 없음 | 계속 |
| 2 | `sync-from-private.sh` 실행 → **충돌 발생** | 스크립트 중단 |

**복구 절차:**

| Step | 행동 | 결과 |
|------|------|------|
| 2a | 충돌 파일 확인 및 수동 해결 | 편집 |
| 2b | `git add <해결된 파일>` + `git commit` | 머지 커밋 |
| 2c | `git push private private` | 동기화 완료 |
| 2d | 다시 "배포해" 실행 | B-1 Step 2부터 재개 |

---

## B-6. merge-to-main 중 충돌 — main에 직접 push된 변경과 충돌

**상황**: 누군가 origin main에 직접 push한 변경사항과 private 코드가 충돌

| Step | 행동 | 결과 |
|------|------|------|
| 1~2 | sync 성공 | 계속 |
| 3~5 | 코드 차이 확인, 메시지 승인 | 계속 |
| 6 | `merge-to-main.sh` 실행 → squash 머지 중 **충돌** | 스크립트 롤백 |

**복구 절차:**

| Step | 행동 | 결과 |
|------|------|------|
| 6a | 스크립트가 자동 롤백 (`git reset --hard` + `git merge --abort`) | private 브랜치 복귀 |
| 6b | 사용자에게 충돌 원인 보고 | 대기 |
| 6c | `git checkout main && git pull origin main` → 충돌 원인 확인 | 분석 |
| 6d | `git checkout private && git merge main` → 수동 충돌 해결 | private에 main 반영 |
| 6e | 다시 "배포해" 실행 | B-1 처음부터 재개 |

---

## B-7. merge-to-main 중도 실패 — 스크립트 에러

**상황**: `merge-to-main.sh` 실행 중 `set -e`에 의해 중간 단계에서 중단 (예: index.lock, 네트워크 오류)

| Step | 행동 | 결과 |
|------|------|------|
| 6 | `merge-to-main.sh` 실행 → **중도 중단** | 불완전 상태 |

**대응 절차 (수동 복구 시도 금지!):**

```
1. 임의 수동 복구 시도 금지
   - 스크립트 내부 로직(백업→리셋→복원)을 모르는 상태에서 단순 git merge 실행 시
     private 파일 삭제 등 2차 사고 발생

2. 안전한 상태로 복귀
   - rm -f .git/index.lock
   - git checkout private

3. 사용자에게 보고
   - 어떤 단계에서 실패했는지 (step 번호 + 에러 메시지)
   - 이미 완료된 작업 (예: "origin push는 완료, private 재동기화만 실패")
   - 스크립트 재실행 또는 수동 step 진행 중 선택을 요청

4. 사용자 지시에 따라 진행
```

---

# C. 작업자 간 동기화 시나리오

## C-1. AidanPark PC1 → PC2 이동

**상황**: PC1에서 커밋 푸시 완료. PC2에서 이어서 작업.

```
PC1: 코드 작업 → 커밋 → git push private private ✓

PC2: (로컬이 뒤쳄진 상태)
  1. ./.agent/skills/repo-management/scripts/sync-from-private.sh
     → git pull private private → PC1 변경분 반영
  2. 이어서 코드 작업
```

**sync 생략 시**: 작업 후 push가 rejected (A-5 상황 발생)

---

## C-2. 시몬스 작업 후 AidanPark 작업

**상황**: 시몬스가 자체 시스템에서 코드 작업 후 private remote에 push. AidanPark가 이어서 작업.

```
시몬스: 코드 작업 → 커밋 → git push private private ✓

AidanPark:
  1. ./.agent/skills/repo-management/scripts/sync-from-private.sh
     → git pull private private → 시몬스 변경분 반영
  2. 코드 작업 → 커밋 → git push private private
```

**sync 생략 시**: A-5 상황 발생. 시몬스와 다른 파일이면 자동 머지 가능, 같은 파일이면 충돌.

---

## C-3. 동시 작업 — 다른 파일 수정 (충돌 없음)

**상황**: AidanPark과 시몬스가 동시에 다른 파일을 수정

```
AidanPark: install.sh 수정 → 커밋 → push ✓
시몬스:    update.sh 수정 → 커밋 → push rejected

시몬스 복구:
  1. git pull private private --no-edit → 자동 머지 성공
  2. git push private private ✓
```

---

## C-4. 동시 작업 — 같은 파일 수정 (충돌)

**상황**: AidanPark과 시몬스가 같은 파일의 같은 부분을 수정

```
AidanPark: install.sh 30행 수정 → 커밋 → push ✓
시몬스:    install.sh 30행 수정 → 커밋 → push rejected

시몬스 복구:
  1. git pull private private → 충돌 발생
  2. 충돌 파일 수동 해결
  3. git add <해결된 파일> + git commit
  4. git push private private ✓
```

---

## C-5. 시몬스가 배포

**상황**: 시몬스가 자체 시스템에서 "배포해" 실행

```
시몬스:
  1. sync-from-private.sh → AidanPark 변경분 반영
  2. merge-to-main.sh "커밋 메시지"
     → main에 squash 머지
     → git push origin main (public)
     → private 재동기화 + git push private private

AidanPark (다음 작업 시):
  1. sync-from-private.sh → 재동기화된 private 반영
```

**주의**: 배포 후 private 브랜치가 `reset --hard main`으로 재구성되므로, 다른 작업자는 반드시 sync 필요.

---

## C-6. 배포 직후 다른 작업자가 sync 없이 push

**상황**: AidanPark이 배포 완료 (private 재동기화됨). 시몬스가 sync 없이 이전 상태에서 push.

```
AidanPark: 배포 완료 → private 재동기화 (reset --hard main + private 파일 복원) → push ✓

시몬스: (로컬이 배포 전 상태)
  1. git push private private → rejected (히스토리 diverged)
  2. git pull private private → 충돌 가능성 높음
```

**복구**: 시몬스가 `git pull private private`로 merge 시도. 충돌 시 수동 해결.

**예방**: 배포 후 시몬스에게 sync 필요 알림.

---

## C-7. 두 작업자가 동시에 배포 시도

**상황**: AidanPark과 시몬스가 거의 동시에 "배포해" 실행

```
AidanPark: merge-to-main.sh → origin main push ✓
시몬스:    merge-to-main.sh → origin main push rejected (AidanPark이 먼저 push)
```

**결과**: 시몬스의 스크립트가 Step [5/7] push에서 실패. `set -e`에 의해 중단.

**복구**: B-7 절차 수행. 안전한 상태로 복귀 후 다시 "배포해" 실행 (AidanPark 배포분이 main에 반영된 상태에서 재시도).

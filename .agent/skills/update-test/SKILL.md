---
name: update-test
description: 실제 기기에서 oa --update 를 실행하고 결과 로그를 분석하여 문제를 보고한다. Trigger — "업데이트 테스트해", "업데이트 확인해".
license:
compatibility: SSH 접속 가능한 Termux 기기 필요
metadata:
  author: AidanPark
  version: "1.0"
allowed-tools:
---

## 트리거

| 트리거 | 요약 |
|--------|------|
| "업데이트 테스트해", "업데이트 확인해" | 실제 기기에서 oa --update 실행 후 로그 분석 |

## 범위

- 업데이트 실행 및 결과 로그 확인 **만** 수행
- 문제가 발견되면 정리하여 보고
- **문제 해결은 이 스킬의 범위 밖** — 보고만 한다

---

## 절차

```
Step 1. SSH 접속
   - 접속 정보는 .agent/memory/MEMORY.md 의 "테스트 기기" 참조
   - tmux 세션으로 접속 관리
   └─ 접속 실패 → "기기 접속 불가" 보고 → 종료

Step 2. 업데이트 전 현재 상태 기록
   다음 명령어로 현재 버전을 기록한다:
   - openclaw --version
   - node -v
   - opencode --version        (설치된 경우)
   - oh-my-opencode --version  (설치된 경우)
   - claude --version           (설치된 경우)
   - gemini --version           (설치된 경우)
   - codex --version            (설치된 경우)
   - code-server --version      (설치된 경우)

Step 3. 업데이트 실행
   - oa --update 2>&1 | tee ~/.openclaw-android/update.log
   - 완료까지 대기 (수 분 소요)

Step 4. 로그 수집
   - cat ~/.openclaw-android/update.log
   - 전체 로그를 수집한다

Step 5. 로그 분석 — 다음 항목을 순서대로 확인
   
   [5-1] 단계별 완료 여부
   - [1/5] Pre-flight Check
   - [2/5] Download Latest Release
   - [3/5] Update Core Infrastructure
   - [4/5] Update Platform
   - [5/5] Update Optional Tools
   └─ 어떤 단계에서 중단되었는지 확인

   [5-2] 에러/경고 검출
   - [FAIL] 로 시작하는 라인 → 치명적 실패
   - [WARN] 로 시작하는 라인 → 비치명적 경고
   - "Error", "ERR!", "EACCES", "Permission denied" 등 에러 키워드
   - npm/gyp 빌드 에러 (gyp ERR!, npm error)
   - exit code 비정상

   [5-3] 버전 업데이트 확인
   - 업데이트 전 기록(Step 2)과 비교하여 각 컴포넌트가 실제로 업데이트되었는지 확인
   - "X → Y" 로그가 있는데 실제 버전이 안 바뀐 경우 → 문제

   [5-4] 알려진 문제 패턴 체크
   - bun install 시 EACCES 대량 발생 → OpenCode 스탠드얼론 바이너리는 영향 없음 (cosmetic)
   - node-gyp / gyp ERR! → 네이티브 모듈 빌드 실패 (--ignore-scripts 누락 가능성)
   - head -1 로 구버전 바이너리 선택 → sort -V | tail -1 수정 필요
   - libsecret-1 not found → Termux에서 불가, --ignore-scripts로 우회

Step 6. SSH 세션 정리
   - exit 로 SSH 종료
   - tmux kill-session 으로 세션 정리

Step 7. 보고서 작성
```

---

## 보고서 형식

```markdown
## 업데이트 테스트 결과

### 실행 환경
- 기기: [IP:PORT]
- 날짜: [YYYY-MM-DD]

### 버전 변경

| 컴포넌트 | 업데이트 전 | 업데이트 후 | 상태 |
|----------|-----------|-----------|------|
| OpenClaw | X.X.X | Y.Y.Y | ✅ / ❌ |
| Node.js | vX.X.X | vY.Y.Y | ✅ / ❌ |
| ... | ... | ... | ... |

### 발견된 문제

(문제가 없으면 "문제 없음" 으로 기재)

#### 문제 N: [제목]
- **심각도**: 🔴 치명적 / 🟡 경고 / ⚪ cosmetic
- **발생 단계**: [N/5] [단계명]
- **에러 메시지**: (로그에서 발췌)
- **영향 범위**: [어떤 컴포넌트가 영향받는지]
- **모든 사용자 영향 여부**: 예 / 아니오
- **관련 코드**: [파일:라인] (특정 가능한 경우)

### 전체 로그
(접어서 첨부)
```

---

## 주의사항

1. **문제 해결을 시도하지 않는다** — 보고만 한다
2. 업데이트 로그는 반드시 **전체**를 수집한다 (일부만 보면 놓침)
3. 버전 비교는 업데이트 **전후 모두** 기록해야 정확하다
4. `oa --update`는 interactive prompt가 있을 수 있다 (oh-my-opencode 미설치 시 Y/n) — 기본값으로 진행

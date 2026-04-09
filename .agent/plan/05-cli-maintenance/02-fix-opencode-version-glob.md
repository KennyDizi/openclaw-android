# OpenCode 버전 glob 선택 버그 수정

> 작성일: 2026-03-04
> 상태: 작업 예정 — **유일한 실제 버그** (EACCES는 문제 아님 확인됨)
> 우선순위: 높음

## 디바이스 조사 결과 (2026-03-04)

### EACCES는 블로커가 아니었다

SSH 조사 결과, bun의 EACCES 에러(118 패키지)는 **의존성 패키지에만 발생**했고,
**스탠드얼론 바이너리는 정상 설치**되어 있었음:

```
~/.bun/install/cache/opencode-linux-arm64@1.2.15@@@1/bin/opencode  (157,656,619 bytes, Mar 1)
~/.bun/install/cache/opencode-linux-arm64@1.2.16@@@1/bin/opencode  (157,934,848 bytes, Mar 4)  ← 정상 존재
```

OpenCode는 Bun 스탠드얼론 바이너리 — 의존성 패키지가 불필요. EACCES는 cosmetic noise.

### 실제 버그: glob이 구버전을 선택

현재 디바이스 상태:
```
$ opencode --version
1.2.15                    ← 1.2.16이 캐시에 있는데도 구버전 실행

$ cat $PREFIX/bin/opencode
...
exec proot ... "/data/.../opencode-linux-arm64@1.2.15@@@1/bin/opencode" "$@"
                                                 ^^^^^^ 구버전을 가리킴
```

**원인**: `install-opencode.sh:175`의 `head -1`이 알파벳 순으로 1.2.15를 선택.

## 수정

### `head -1` → `sort -V | tail -1` (2곳)

```bash
# 수정 전
FOUND=$(ls $pattern 2>/dev/null | head -1 || true)

# 수정 후
FOUND=$(ls $pattern 2>/dev/null | sort -V | tail -1 || true)
```

### 수정 위치

1. `install-opencode.sh:175` — OpenCode 바이너리 탐색
2. `install-opencode.sh:224` — oh-my-opencode 바이너리 탐색

## 검증 방법

1. 디바이스에서 수정된 `install-opencode.sh`로 OpenCode 재설치
2. `opencode --version` → `1.2.16` 출력 확인
3. `cat $PREFIX/bin/opencode` → wrapper가 `@1.2.16` 경로를 가리키는지 확인

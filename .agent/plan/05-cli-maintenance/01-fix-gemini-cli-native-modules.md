# Gemini CLI 네이티브 모듈 빌드 실패 수정

> 작성일: 2026-03-04
> 상태: 작업 예정
> 우선순위: 낮음 (독립적 이슈, 비차단)

## 문제

`oa --update` 실행 시 Gemini CLI (`@google/gemini-cli`) 업데이트가 네이티브 모듈 빌드 실패로 중단됨.

### 에러 로그

```
# keytar@7.9.0 — libsecret-1 미설치
Package libsecret-1 was not found in the pkg-config search path.
gyp ERR! configure error

# node-pty@1.1.0 — node-gyp 바이너리 PATH 미등록
/data/data/com.termux/files/usr/bin/sh: 1: node-gyp: not found

# tree-sitter-bash@0.25.1 — node-gyp-build 미설치
/data/data/com.termux/files/usr/bin/sh: 1: node-gyp-build: not found

[WARN] Gemini CLI update failed (non-critical)
```

### 발생 버전

- Gemini CLI: 0.31.0 → 0.32.1 업데이트 시
- Node.js: v22.22.0 (glibc)

## 원인

`update-core.sh:276` — `update_ai_tool` 함수가 `npm install -g` 실행 시 `--ignore-scripts` 미사용:

```bash
# 현재 (line 276)
npm install -g "$pkg@latest" --no-fund --no-audit

# OpenClaw은 --ignore-scripts 사용 (비교)
npm install -g openclaw@latest --ignore-scripts
```

Gemini CLI 0.32.1에 추가된 네이티브 의존성의 install 스크립트가 실행되면서 실패.

## 실패 모듈 분석

| 모듈 | 실패 원인 | 용도 | Termux 대안 |
|------|----------|------|------------|
| `keytar@7.9.0` | `libsecret-1` 미설치 | OS 키체인 연동 | Termux에 키체인 없음. 파일 기반 폴백 예상 |
| `node-pty@1.1.0` | `node-gyp` PATH 미등록 | 터미널 에뮬레이션 | CLI 기본 동작에는 불필요할 수 있음 |
| `tree-sitter-bash@0.25.1` | `node-gyp-build` 미설치 | 코드 파싱 | 선택적 기능 |

## 수정 방안

### 방안 A — `--ignore-scripts` 추가 (권장)

`update-core.sh` 의 `update_ai_tool` 함수 수정:

```bash
# line 276
npm install -g "$pkg@latest" --no-fund --no-audit --ignore-scripts
```

**장점**: 간단, 1줄 수정
**위험**: 네이티브 모듈에 의존하는 기능이 동작하지 않을 수 있음

### 방안 B — AI tool별 분기

```bash
case "$pkg" in
    "@google/gemini-cli") npm install -g "$pkg@latest" --no-fund --no-audit --ignore-scripts ;;
    *) npm install -g "$pkg@latest" --no-fund --no-audit ;;
esac
```

**장점**: 다른 AI tool에는 영향 없음
**단점**: 코드 복잡도 증가, 현재 Claude Code/Codex는 문제 없이 동작하므로 불필요

## 수정 대상 파일

- `update-core.sh:276` — `update_ai_tool` 함수 내 npm install 명령

## 검증 방법

1. 수정 후 디바이스에서 `oa --update` 재실행
2. Gemini CLI 업데이트 성공 확인
3. `gemini` 명령어 실행하여 기본 동작 검증 (API 키 필요)

## 참고

- Claude Code, Codex CLI는 동일 `update_ai_tool` 함수로 정상 업데이트됨
- 이 이슈는 Gemini CLI 0.32.1에서 새로 추가된 의존성에 의해 발생
- `--ignore-scripts`는 OpenClaw 설치에서도 동일하게 사용 중 (검증된 패턴)

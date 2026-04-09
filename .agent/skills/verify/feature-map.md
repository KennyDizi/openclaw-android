# Feature Dependency & Conflict Map

verify 스킬의 변경 영향 분석(Step 6)에서 참조하는 문서.

## Feature 목록

| ID | Feature | 주요 스크립트 |
|----|---------|-------------|
| F1 | Install (초기 설치) | `post-setup.sh`, `install.sh`, `scripts/install-*.sh` |
| F2 | Update (업데이트) | `update-core.sh`, `update.sh`, `platforms/openclaw/update.sh` |
| F3 | Patch (패치) | `platforms/openclaw/patches/*`, `patches/*` |
| F4 | Environment (환경 설정) | `scripts/setup-env.sh`, `platforms/openclaw/env.sh`, `.bashrc` |
| F5 | CLI | `oa.sh` |
| F6 | Optional Tools | `scripts/install-code-server.sh`, `install-tools.sh`, `scripts/install-chromium.sh`, `scripts/install-playwright.sh` |
| F7 | Platform | `platforms/openclaw/config.env`, `platforms/openclaw/install.sh`, `platforms/openclaw/update.sh` |
| F8 | Verification | `tests/verify-install.sh`, `platforms/*/status.sh`, `platforms/*/verify.sh` |

## 공유 자원 → Feature 매핑

어떤 자원을 변경하면 어떤 feature들이 영향받는지.

| 공유 자원 | 사용하는 Feature | 위험도 |
|-----------|-----------------|--------|
| `scripts/lib.sh` | F1, F2, F3, F4, F5, F7 (전체) | 높음 |
| `$HOME/.bashrc` | F1, F4, F6 | 높음 |
| `$PREFIX/bin/` (oa, node, npm, git 등) | F1, F2, F5, F6 | 높음 |
| `$HOME/.openclaw/openclaw.json` | F2, F7 | 중간 |
| `$HOME/.openclaw-android/patches/` | F1, F3, F4 | 중간 |
| `platforms/openclaw/config.env` | F1, F2, F7 | 중간 |
| Marker files (`.platform`, `.glibc-arch`) | F1, F2, F5 | 중간 |
| OA_VERSION (4개 파일 분산) | F1, F2, F5 | 높음 |
| `$PREFIX/glibc/` (linker, libs) | F1, F3, F8 | 높음 |
| NODE_OPTIONS 환경변수 | F1, F3, F4 | 중간 |
| `$PROJECT_DIR/bin/` (wrapper 경로) | F1, F2, F5, F8 | 높음 |

## Feature 간 의존 관계

화살표(→)는 "앞 feature가 정상이어야 뒤 feature가 동작"을 의미.

```
F1 (Install) → F3 (Patch)     : install이 openclaw을 깔아야 patch 대상이 존재
F1 (Install) → F4 (Env)       : install이 node/glibc를 깔아야 env 설정이 유효
F1 (Install) → F7 (Platform)  : install이 platform 스크립트를 복사해야 platform 동작
F2 (Update)  → F3 (Patch)     : update가 openclaw을 업데이트하면 patch 재적용 필요
F2 (Update)  → F4 (Env)       : update가 setup-env.sh를 실행하여 env 재설정
F4 (Env)     → F5 (CLI)       : .bashrc의 PATH가 맞아야 oa 명령이 lib.sh를 찾음
F4 (Env)     → F6 (Tools)     : PATH, TMPDIR 등이 맞아야 optional tools 동작
F7 (Platform)→ F3 (Patch)     : platform update.sh가 patch 스크립트 호출
```

## 알려진 상충 관계

### 1. Install(F1) ↔ Update(F2): 실행 순서 의존성

**공유 자원**: `scripts/lib.sh`, platform 스크립트, patches
**상충 패턴**:
- post-setup.sh(F1)는 openclaw 설치 후 `openclaw config set` 실행
- update-core.sh(F2)는 platform update.sh에서 동일 명령 실행
- 두 플로우가 동일 설정을 다른 시점에 적용 → 한쪽 순서가 바뀌면 다른 쪽 가정이 깨짐

**검증 방법**:
- 변경된 명령이 post-setup.sh와 update 플로우 양쪽에서 실행 시점의 의존성이 충족되는지 확인
- post-setup.sh에서는 openclaw 설치(Step 4/7) 이후인지
- update.sh에서는 openclaw npm 업데이트 이후인지

### 2. Patch(F3) ↔ Update(F2): 패치 무효화

**공유 자원**: `$(npm root -g)/openclaw/` 내 JavaScript 파일
**상충 패턴**:
- Patch가 openclaw JS 파일의 hardcoded path를 수정
- Update가 openclaw npm 패키지를 교체하면 패치가 날아감
- 반드시 update → patch 순서로 실행해야 함

**검증 방법**:
- update.sh에서 npm install 후 반드시 openclaw-apply-patches.sh가 호출되는지 확인
- 새로운 패치 추가 시 update 플로우에서도 적용되는지 확인

### 3. Environment(F4) ↔ Install(F1): .bashrc 충돌

**공유 자원**: `$HOME/.bashrc`
**상충 패턴**:
- post-setup.sh(F1)가 .bashrc를 통째로 덮어씀 (초기 설치)
- setup-env.sh(F4)가 marker 기반으로 블록을 교체
- install 후 setup-env가 실행되면 post-setup이 쓴 내용을 덮어쓸 수 있음
- 반대로 setup-env의 marker 형식이 바뀌면 post-setup의 .bashrc와 호환 안 됨

**검증 방법**:
- .bashrc 관련 변경 시 post-setup.sh와 setup-env.sh 양쪽의 .bashrc 쓰기 로직이 호환되는지 확인
- marker 문자열(`# >>> OpenClaw on Android >>>`)이 양쪽에서 동일한지

### 4. CLI(F5) ↔ Update(F2): 버전 불일치

**공유 자원**: `OA_VERSION`, `scripts/lib.sh`의 함수 시그니처
**상충 패턴**:
- oa.sh(F5)는 로컬에 설치된 버전 (이전 update에서 복사됨)
- update-core.sh(F2)는 GitHub에서 새로 다운로드된 버전
- oa.sh가 lib.sh의 함수를 호출하는데, 새 lib.sh에서 함수 시그니처가 바뀌면 구 oa.sh가 깨짐
- 반대로 oa.sh가 먼저 업데이트되고 lib.sh가 아직 구버전이면 같은 문제

**검증 방법**:
- lib.sh의 함수 시그니처(인자 수, 이름)를 변경할 때 oa.sh도 함께 수정되었는지
- OA_VERSION 변경 시 4개 파일 동기화 확인 (이미 Step 5에서 검증)

### 5. Optional Tools(F6) ↔ Environment(F4): PATH 오염

**공유 자원**: `$PATH`, `$HOME/.bashrc`
**상충 패턴**:
- optional tools가 `~/.local/bin/`에 설치
- setup-env.sh가 PATH를 재설정할 때 `~/.local/bin/`을 포함하지 않으면 tool이 안 보임
- Playwright가 .bashrc에 PLAYWRIGHT_* 변수를 추가하는데, setup-env.sh가 .bashrc를 덮어쓰면 손실

**검증 방법**:
- .bashrc에 marker 블록 외부에 쓰인 설정이 setup-env.sh에 의해 보존되는지
- PATH에 `~/.local/bin/`이 포함되는지

### 6. Platform(F7) ↔ Install(F1): config.env 의존

**공유 자원**: `platforms/openclaw/config.env`의 `PLATFORM_NEEDS_*` 플래그
**상충 패턴**:
- config.env에서 `PLATFORM_NEEDS_GLIBC=true`인데 install-glibc.sh가 없으면 install 실패
- config.env의 플래그를 바꾸면 install 플로우의 조건 분기가 달라짐

**검증 방법**:
- config.env 변경 시 대응하는 install 스크립트 존재 확인 (이미 Step 3에서 검증)

### 7. Install(F1) ↔ Verification(F8): 경로/구조 정합성

**공유 자원**: `$PROJECT_DIR/bin/` (wrapper 경로), `$PREFIX/glibc/` (linker), marker 파일 경로
**상충 패턴**:
- Install 스크립트가 파일 경로·디렉토리 구조를 변경하면, 검증 스크립트가 구 경로를 참조하여 false positive FAIL 발생
- 예: wrapper를 `node/bin/`에서 `bin/`으로 이동했지만, verify-install.sh와 status.sh가 구 경로를 확인

**검증 방법**:
- Install 스크립트에서 파일 생성/이동 경로가 변경되면, 검증 스크립트(verify-install.sh, status.sh, verify.sh)의 참조 경로도 함께 변경되었는지 확인
- 가능한 한 lib.sh의 공유 변수(`$BIN_DIR`, `$PROJECT_DIR`)를 사용하여 경로 하드코딩 방지

## Delivery Path Parity (경로 간 기능 동기화)

이 프로젝트는 동일 기능을 **3개 경로**로 전달한다. 기능 수정 시 모든 경로에 반영되어야 한다.

### 경로 정의

| 경로 | 대상 사용자 | 진입점 | 비고 |
|------|-----------|--------|------|
| App Install | 앱 신규 설치 | `post-setup.sh` | 단일 파일, 모든 기능 자체 수행 |
| Termux Install | Termux 신규 설치 | `install.sh` → 모듈 스크립트 | 모듈형, scripts/ + platforms/ 조합 |
| Update | 기존 사용자 업데이트 | `update-core.sh` → `platforms/openclaw/update.sh` | oa --update |

### 기능 ↔ 경로 매핑

| 기능 | App Install (`post-setup.sh`) | Termux Install (modular) | Update |
|------|------------------------------|--------------------------|--------|
| glibc 설치 | [2/7] 직접 수행 | `scripts/install-glibc.sh` | `scripts/install-glibc.sh` (migration) |
| Node.js 설치 | [3/7] 직접 수행 | `scripts/install-nodejs.sh` | `scripts/install-nodejs.sh` |
| OpenClaw npm 설치 | [4/7] npm install | `platforms/openclaw/install.sh` | `platforms/openclaw/update.sh` |
| 패치 적용 | [5/7] 직접 수행 | `platforms/openclaw/patches/*` | `platforms/openclaw/patches/*` |
| mDNS 비활성화 | `glibc-compat.js` (런타임 감지) | `glibc-compat.js` (동일) | `glibc-compat.js` (동일) |
| 환경 설정 (.bashrc) | [6/7] 직접 수행 | `scripts/setup-env.sh` | `scripts/setup-env.sh` |
| sharp 빌드 | [5/7] WASM fallback | `platforms/openclaw/patches/openclaw-build-sharp.sh` | 동일 |
| clawdhub 설치 | [4/7] npm install | `platforms/openclaw/install.sh` | `platforms/openclaw/update.sh` |
| Optional Tools | [7/7] 직접 수행 | `install.sh` [7/8] | `update-core.sh` [5/5] |
| git wrapper | [4/7] 직접 수행 | (install.sh에서 수행) | — |

### Parity 검증 방법

스크립트 수정 시:

1. 변경된 파일이 위 매핑 표의 어느 기능에 해당하는지 확인
2. 해당 기능의 **다른 경로 스크립트**에도 동등한 변경이 있는지 확인
3. 누락 시 ❌ 보고: "기능 X가 경로 A에 추가되었지만, 경로 B에 누락"

**주의**: App Install(`post-setup.sh`)은 단일 파일이므로 기능이 inline으로 구현되어 있다.
Termux Install/Update는 모듈 스크립트에 분산되어 있다. 1:1 파일 매칭이 아니라 **기능 단위**로 비교해야 한다.

### 파일 동기화 (별도)

경로 간 parity와는 별개로, 다음 파일 쌍은 **내용이 완전히 동일**해야 한다:
- `post-setup.sh` ↔ `android/app/src/main/assets/post-setup.sh`

## 검증 시 활용법

Step 6 변경 영향 분석에서:

1. 변경된 파일이 속한 Feature 식별
2. "공유 자원 → Feature 매핑" 표에서 영향받는 다른 Feature 확인
3. "알려진 상충 관계"에서 해당 Feature 쌍의 검증 방법 수행
4. "Delivery Path Parity"에서 다른 경로에 동등 변경이 있는지 확인
5. 새로운 상충 관계 발견 시 이 문서에 추가

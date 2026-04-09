# MEMORY

## 프로젝트 목적

- 다양한 에이전트 플랫폼(openclaw, picoclaw, nanobot, zeroclaw, moltis 등)을 Android에서 구동하기 위한 기반 인프라
- 현재는 openclaw만 지원, 향후 하나씩 추가 예정
- GitHub에 공개된 프로젝트 — 사용자들이 이용 중이며 이슈가 올라옴
- 개발 업무(플랫폼 추가, 기능 개선)와 이슈 해결 업무를 최대한 에이전트가 처리할 수 있도록 세팅

## 프로젝트 상태

- 스크립트 버전: v1.0.13
- 앱 버전: v0.3.0
- 앱 이름: Claw
- public 레포: https://github.com/AidanPark/openclaw-android
- private 레포: https://github.com/AidanPark/openclaw-android-private
- 브랜치: `main` (단일 브랜치)

## 주요 이슈 현황

- #13, #16: 불필요한 패키지 설치 문제 → 필수만 자동 설치, 나머지 사용자 선택으로 수정 완료
- #17: 설치 후 활용 가이드 요청 → 업무 서비스 서버 용도로 사용 중임을 답변
- #18: FTS5 unavailable on Android → Node.js v22.22.0으로 업그레이드하여 해결 (node:sqlite는 정적 번들 SQLite 사용, v22.15.0부터 FTS5 플래그 포함). schmosbyy 확인 대기 중
- #21: Chromium 브라우저 자동화 지원 요청 → Chromium 설치/설정 스크립트 추가, sharp WASM 폴백으로 이미지 처리 해결. 게이트웨이 재시작 후 Discord 실전 테스트 필요
- #62: "Gateway service install not supported on android" — xicoyer 보고. process.platform=linux인데 에러 발생. 원인 조사 중 (OpenClaw CLI 내부 감지 로직 or 설치 문제 가능성)

## 알려진 버그: /usr/bin/env 부재로 npm lifecycle script 실패

- **증상**: `openclaw update` 시 sharp 빌드 단계에서 `/bin/sh: .../node-gyp: No such file or directory` 에러
- **근본 원인**: node wrapper가 `unset LD_PRELOAD` → libtermux-exec 경로 변환 비활성화 → `/usr/bin/env`가 Termux에 없어서 `#!/usr/bin/env sh` shebang 실패
- **영향 범위**: sharp뿐 아니라 `#!/usr/bin/env` shebang을 사용하는 모든 npm lifecycle script에 해당
- **dev 기기 재현 확인**: 2026-03-28, oa v1.0.7, openclaw 2026.3.13
- **부수 이슈**: `~/.openclaw/cron/jobs.json`에 JSON 구문 에러 (두 곳에서 쉼표 누락)

## 테스트 기기

| 기기 | 접속 | 비밀번호 | 비고 |
|------|------|----------|------|
| Phone 1 (dev) | `sshpass -p '1234' ssh -p 8022 100.98.75.32` | 1234 | |
| Phone 2 (test) | `sshpass -p '1234' ssh -p 8022 -o PreferredAuthentications=password -o PubkeyAuthentication=no -l "" 100.98.75.32` | 1234 | `-l ""` 필수 |

## 동기화 규칙

모든 동기화 규칙(파일, 버전, 3개국어, delivery path)은 `.agent/doc-map.md` (SSOT)를 참고하라.

## 최근 변경 이력

- **v1.0.8 / node wrapper shebang fix**: `install-nodejs.sh`의 node wrapper shebang 하드코딩 수정 (`printf`로 `$PREFIX` 확장), systemctl stub shebang 수정, post-setup.sh 루트 추가 (Issue #49 대응)
- **v1.0.8 / 앱 post-setup.sh 동기화**: clawdhub 설치, @snazzah/davey 네이티브 바인딩, openclaw update, sharp WASM 폴백, CLAWDHUB_WORKDIR/CPATH 환경변수 추가 (Issue #40 대응)
- **v1.0.4**: Node.js v22.14.0→v22.22.0 업그레이드 (FTS5 지원), update 메시지에 버전 표시 추가, oh-my-opencode 서비스 제거
- **oh-my-opencode 제거 사유**: OpenCode가 내부 Bun으로 `~/.cache/opencode/node_modules/`에 플러그인을 설치하며, PATH를 통해 인식하지 않음. proot wrapper로 만든 oh-my-opencode가 OpenCode에서 감지되지 않아 제거 결정


## 기술 참고

- `node:sqlite`는 시스템 libsqlite가 아닌 정적 번들된 SQLite를 사용한다
- FTS5는 Node.js v22.15.0 (PR #57621, 2025년 4월)부터 빌드 플래그에 포함
- install-nodejs.sh에 버전 비교 로직 추가: 낮으면 업그레이드, 같거나 높으면 skip
- sharp 네이티브 바이너리(`@img/sharp-linux-arm64`)는 glibc 링크됨. `node.real`은 bionic `libc.so`에 의존하므로 bionic의 `dlopen`이 glibc `.node` 애드온을 로드 불가. `@img/sharp-wasm32 --force`로 WASM 빌드 설치하면 해결
- glibc-runner 환경에서 `process.platform === 'android'`, `node.real`의 RUNPATH는 `$PREFIX/lib` (bionic), NEEDED는 `libc.so`(unversioned, bionic)
- Chromium은 Termux x11-repo에서 bionic 빌드로 설치. glibc Node.js가 bionic Chromium을 fork+exec으로 spawn 가능 (커널이 바이너리 로딩 독립 처리). CDP WebSocket 통신은 OS-level IPC로 libc 무관

## APK 릴리즈 서명

- 서명 정보는 `.agent/skills/release/SKILL.md`에서 관리
- DN: `CN=Claw, OU=OpenClaw, O=OpenClaw, L=Seoul, ST=Seoul, C=KR`
- 유효기간: 10,000일 (RSA 2048)
- SHA-256: `e6f53e8e9e94ae046b5019cebebe830ea4ce4e3622bbb54b124297dc30bbaebd`
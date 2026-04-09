# 코드↔문서 매핑 테이블 (SSOT)

이 문서는 프로젝트의 **모든 동기화 규칙**을 한 곳에서 관리한다.
CLAUDE.md, verify 스킬 등 다른 문서에서 동기화 규칙을 참조할 때는 이 문서를 가리킨다.

## 1. 코드 ↔ 문서 매핑

코드가 수정되면 관련 문서도 함께 현행화해야 한다.

| 코드 경로 | 관련 문서 | 업데이트 항목 |
|-----------|----------|-------------|
| `install.sh` | `README.md` (Installation) | 설치 단계, 요구사항 변경 |
| `oa.sh` | `README.md` (Usage/Commands) | CLI 옵션, 사용법 변경 |
| `update.sh`, `update-core.sh` | `README.md` (Update), `CHANGELOG.md` | 업데이트 방법, 변경 이력 |
| `scripts/install-*.sh` | `README.md` (Architecture) | 의존성, 설치 흐름 변경 |
| `platforms/openclaw/*` | `README.md` (Platforms) | 플랫폼 관련 설명 |
| `android/app/src/**/*.kt` | `CONTRIBUTING.md` (Android App) | 빌드 방법, 코드 스타일 변경 |
| `android/www/**` | `CONTRIBUTING.md` (WebView UI) | 빌드 방법, 의존성 변경 |
| `bootstrap.sh` | `README.md` (How It Works) | 부트스트랩 흐름 변경 |

## 2. 버전 동기화

### OA_VERSION (스크립트 버전)
다음 **4개 파일**에 분산되어 있으며 반드시 동일 값으로 유지. PostToolUse hook이 불일치를 감지한다.
- `scripts/lib.sh`
- `install-tools.sh`
- `update-core.sh`
- `oa.sh`

### 버전 변경 시 필수 작업
| 변경 대상 | 필수 작업 |
|-----------|----------|
| `OA_VERSION` 변경 | `CHANGELOG.md`에 변경 내역 기록 |
| `versionName` (앱 버전) 변경 | `CHANGELOG.md` 기록 + 배포 후 GitHub Release (태그 + 서명 APK) |

## 3. 파일 동기화

다음 파일 쌍은 **내용이 완전히 동일**해야 한다. pre-commit hook이 불일치를 차단한다.
- `post-setup.sh` (루트) ↔ `android/app/src/main/assets/post-setup.sh`

## 4. 3개국어 동기화

문서를 수정할 때는 반드시 영어/한국어/중국어 3개 언어를 동시에 업데이트한다.
한 언어만 수정하고 나머지를 빠뜨리면 안 된다.

| 문서 | 영어 | 한국어 | 중국어 |
|------|------|--------|--------|
| README | `README.md` | `README.ko.md` | `README.zh.md` |
| Troubleshooting | `docs/troubleshooting.md` | `docs/troubleshooting.ko.md` | `docs/troubleshooting.zh.md` |
| Phantom Process | `docs/disable-phantom-process-killer.md` | `docs/disable-phantom-process-killer.ko.md` | `docs/disable-phantom-process-killer.zh.md` |
| SSH Guide | `docs/termux-ssh-guide.md` | `docs/termux-ssh-guide.ko.md` | `docs/termux-ssh-guide.zh.md` |

## 5. Delivery Path Parity (경로 간 기능 동기화)

스크립트 기능 수정 시, 해당 기능이 존재하는 모든 delivery path에 동등하게 반영해야 한다.
상세 매핑은 `.agent/skills/verify/feature-map.md`의 "Delivery Path Parity" 섹션 참고.

## 사용 방법

이 매핑은 Claude Code hook에 의해 자동으로 참조된다. 에이전트가 코드를 수정하면:
1. 매핑 테이블에서 관련 문서를 찾는다.
2. 관련 문서의 해당 섹션을 읽는다.
3. 업데이트가 필요하면 함께 수정한다.

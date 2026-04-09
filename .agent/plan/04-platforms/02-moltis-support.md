# Moltis 지원 기획서

> 작성일: 2026-03-04
> 상태: ✅ 지원 확정 — 우리 프로젝트에 최적의 후보

## 조사 결과 요약

### glibc-runner 필요 여부: ✅ 필요 (확정)

- ARM64 Linux 바이너리: `aarch64-unknown-linux-gnu` — **glibc 동적 링크**
- **musl 빌드 없음** — CI 전체에 musl 타겟 부재 (release.yml 확인)
- 릴리스 아티팩트: `moltis-0.10.11-aarch64-unknown-linux-gnu.tar.gz`
- 외부 공유 라이브러리 불필요 — OpenSSL vendored, SQLite bundled (sqlx), TLS는 rustls (pure Rust)
- **glibc만 제공하면 바이너리가 동작함** → glibc-runner만으로 충분

### Docker 의존성: 선택적 (sandbox 기능만)

- `sandbox.mode = "off"` 설정으로 Docker 없이 실행 가능
- Docker 없이 동작하는 기능: 채팅, LLM 연동, Web UI, MCP, 메모리, Telegram/Discord
- Docker 필요 기능: exec 도구 (쉘 샌드박스), 브라우저 자동화

---

## 런타임 정보

| 항목 | 내용 |
|------|------|
| 레포 | https://github.com/moltis-org/moltis |
| 언어 | Rust |
| Stars | 1.8k |
| 라이선스 | MIT |
| 바이너리 크기 | ~36.5MB (압축), ~80-120MB (비압축) |
| 최소 RAM | 256MB (추정), 512MB+ 권장 |
| 최소 저장공간 | ~200MB |

---

## Android에서 동작하는 기능

| 기능 | 동작 여부 | 비고 |
|------|----------|------|
| 채팅 / LLM 연동 | ✅ | 핵심 기능, Docker 불필요 |
| Web UI | ✅ | localhost:13131 |
| MCP 서버 | ✅ | subprocess로 실행 |
| Telegram / Discord 봇 | ✅ | 네트워크만 필요 |
| 메모리 / 임베딩 | ✅ | SQLite + 로컬 임베딩 |
| 웹 검색 | ✅ | HTTP만 필요 |
| exec 도구 (쉘 샌드박스) | ❌ | Docker 필요 |
| 브라우저 자동화 | ❌ | Docker 컨테이너 필요 |
| 음성 | ⚠️ 부분적 | 클라우드 TTS/STT는 가능, 시스템 오디오 불가 |
| 로컬 LLM (llama.cpp) | ⚠️ 부분적 | GPU 가속 불가 |

---

## 구현 계획

### config.env

```bash
PLATFORM_NAME="moltis"
PLATFORM_DISPLAY_NAME="Moltis"
PLATFORM_NEEDS_GLIBC=true
PLATFORM_NEEDS_NODEJS=false
PLATFORM_NEEDS_BUILD_TOOLS=false
```

### 설치 흐름

```
[1] 환경 검증 (check-env.sh)
[2] 런타임 선택 → moltis
[3] 선택 도구 안내 (L3)
[4] 인프라 설치 (L1) — git, pkg update
[5] glibc-runner 설치 (L2) — pacman, glibc-runner
[6] Moltis 설치 (L2 런타임)
    6.1 GitHub Release에서 ARM64 바이너리 다운로드
        - moltis-{version}-aarch64-unknown-linux-gnu.tar.gz
    6.2 glibc-runner 래퍼 스크립트 생성 (node 래퍼와 동일 패턴)
        - ~/.openclaw-android/moltis/bin/moltis
        - 내용: exec grun moltis-binary "$@"
    6.3 $PREFIX/bin/moltis 심볼릭 링크
    6.4 기본 설정 파일 생성
        - ~/.config/moltis/moltis.toml (sandbox.mode = "off")
    6.5 systemctl 스텁 설치 (기존 것 재활용)
    6.6 환경변수 설정 (.bashrc)
        - MOLTIS_CONFIG_DIR, MOLTIS_DATA_DIR
[7] 선택 도구 설치 (L3)
[8] 검증 (verify)
```

### 필요한 파일

```
platforms/moltis/
├── config.env          # 런타임 메타데이터
├── env.sh              # 환경변수 (MOLTIS_CONFIG_DIR 등)
├── install.sh          # 바이너리 다운로드 + grun 래퍼 + 기본 설정
├── update.sh           # 최신 릴리스 체크 + 바이너리 교체
├── uninstall.sh        # 바이너리 + 설정 제거
├── status.sh           # moltis --version, 설정 상태
└── verify.sh           # 바이너리 실행 가능 여부 확인
```

### 패치 사항

| 패치 | 내용 | 방법 |
|------|------|------|
| sandbox 비활성화 | Docker 없는 환경 대응 | `moltis.toml`에 `[tools.exec.sandbox] mode = "off"` |
| systemd 스텁 | systemctl 호출 무시 | 기존 `patches/systemctl` 재활용 |
| 경로 변환 | /tmp 등 표준 Linux 경로 | glibc-runner가 자동 처리 |

### 업데이트 흐름

1. GitHub API로 최신 릴리스 버전 확인
2. 현재 설치된 버전과 비교
3. 변경 시 새 바이너리 다운로드 + 래퍼 교체
4. moltis.toml은 유지 (사용자 설정 보존)

---

## 난이도 평가: 하

- glibc-runner 인프라 이미 존재
- 단일 바이너리 다운로드 + 래퍼 스크립트만 필요
- Node.js/Python 의존성 없음
- 외부 공유 라이브러리 없음
- OpenClaw과 독립적 (충돌 없음)

# 에이전트 런타임 지원 로드맵

> 작성일: 2026-03-04 (rev.3) → **rev.4 업데이트: 2026-03-29**

## 목적

OpenClaw 외 주요 에이전트 런타임을 순차적으로 지원한다.
우선순위는 **사용자 수 40% + 런타임 이식성 10% + 실익 50%** 기준으로 산정한다.

---

## 평가 기준

### 사용자 수 (GitHub Stars 기준, 100점 만점 정규화)

> 2026-03-29 기준 재조사 결과. 신규 런타임 추가.

| 런타임 | Stars (3/4) | Stars (3/29) | 변동 | 점수 |
|--------|-------------|--------------|------|------|
| NanoBot | 27.9k | 34.6k | +6.7k | 100 |
| NanoClaw | 18.1k | 22.0k | +3.9k | 64 |
| PicoClaw | 21.8k | 25k+ (추정) | +3k | 72 |
| ZeroClaw | 19.4k | 16.0k | -3.4k (레포 분리) | 46 |
| memU | 12.3k | 12.0k | — | 35 |
| Moltis | 1.8k | 2.3k | +0.5k | 7 |
| **OpenCode** (신규) | — | 122.0k | 신규 | — (이미 지원 중) |
| **Junie CLI** (신규) | — | beta | 신규 | 미정 |
| **OpenHands** (신규) | — | 69.0k | 신규 | — (Docker 필수) |

### 런타임 이식성 (100점 만점)

현재 인프라: Termux + glibc-runner + Node.js (linux-arm64)

| 런타임 | 언어 | 이식성 근거 | 점수 |
|--------|------|------------|------|
| Moltis | Rust | glibc 동적 링크 확인. 단일 바이너리, 외부 공유 라이브러리 불필요. glibc-runner만으로 동작 | 95 |
| NanoClaw | TypeScript | Node.js 기반이나 Docker **필수** — Android에서 Docker 실행 불가. 2026-03 Docker 파트너십으로 더욱 Docker 의존 심화 | 10 |
| PicoClaw | Go | 완전 정적 바이너리 — glibc-runner 불필요. v0.2.4에서 32-bit 아키텍처 지원 추가 | N/A |
| ZeroClaw | Rust | musl 정적 바이너리 — glibc-runner 불필요 | N/A |
| NanoBot | Python | Termux 네이티브 Python — glibc-runner 불필요 | N/A |
| memU | Python | Termux 네이티브 Python 프레임워크 — glibc-runner 불필요 | N/A |
| Junie CLI | Kotlin/JVM? | 스탠드얼론 바이너리 제공. 멀티플랫폼 (Linux/macOS/Windows). 바이너리 타입 미확인 | 미정 |
| OpenHands | Python | Docker 필수. CLI 바이너리도 제공하나 핵심 기능은 Docker 컨테이너 내 실행 | 10 |

### 실익 — 세부 조사 결과

| 런타임 | glibc-runner 필요? | 조사 결과 (3/29 업데이트) | 실익 점수 |
|--------|-------------------|-------------------------|----------|
| Moltis | ✅ 필요 (확정) | `aarch64-unknown-linux-gnu` 확인. v0.10.18 (3/9 릴리스). Docker 선택적 (`sandbox.mode = "off"`). 핵심 기능 모두 Docker 없이 동작 | 100 |
| NanoClaw | ✅ 필요하나 블로커 존재 | Docker **필수 하드 의존성** — 2026-03 Docker 파트너십 체결, MicroVM 샌드박스 통합. Docker-free 모드 없음. 블로커 해소 가능성 더 낮아짐 | 0 |
| PicoClaw | ❌ 불필요 (확정) | `CGO_ENABLED=0` 완전 정적 바이너리. Termux에서 직접 실행 가능. v0.2.4에서 32-bit 지원 추가 | 0 |
| NanoBot | ❌ 불필요 | Termux 네이티브 Python으로 충분. 34.6k stars로 성장세 가장 높음 | 0 |
| ZeroClaw | ❌ 불필요 | musl 정적 바이너리 제공. 레포 분리 (zeroclaw-labs/zeroclaw) | 0 |
| memU | ❌ 불필요 | Python 메모리 프레임워크. memUBot이 OpenClaw 대체 에이전트로 사용 가능 | 0 |
| Junie CLI | ❓ 미확인 | 바이너리 타입(정적/동적) 미확인. beta 단계라 안정성 부족. 추후 재평가 | 미정 |
| OpenHands | ❌ 불필요하나 Docker 필수 | Docker/Kubernetes 환경 필수. Android 실행 불가 | 0 |

---

## 종합 점수 및 최종 판정

> 종합 = 사용자 수 × 0.4 + 이식성 × 0.1 + 실익 × 0.5

| 순위 | 런타임 | 사용자(×0.4) | 이식성(×0.1) | 실익(×0.5) | 종합 | 최종 판정 |
|------|--------|-------------|-------------|-----------|------|----------|
| 1 | **Moltis** | 2.8 | 9.5 | 50.0 | **62.3** | ✅ 지원 확정 — glibc-runner 필수, Docker 선택적, 난이도 하 |
| 2 | NanoClaw | 25.6 | 1.0 | 0.0 | **26.6** | 🔴 보류 유지 — Docker 의존 심화 (파트너십 체결) |
| — | OpenCode | — | — | — | — | ✅ 이미 지원 중 (`scripts/install-opencode.sh`) |
| — | Junie CLI | — | — | — | — | 🟡 관찰 — beta, 바이너리 타입 미확인. GA 후 재평가 |
| — | OpenHands | — | — | — | — | 🔴 제외 — Docker 필수 |
| — | NanoBot | 40.0 | — | 0.0 | — | ❌ 제외 — Termux 네이티브 Python |
| — | PicoClaw | 28.8 | — | 0.0 | — | ❌ 제외 — 완전 정적 바이너리 |
| — | ZeroClaw | 18.4 | — | 0.0 | — | ❌ 제외 — musl 정적 바이너리 |
| — | memU | 14.0 | — | 0.0 | — | ❌ 제외 — Termux 네이티브 Python |

---

## rev.4 주요 변경 사항 (2026-03-29)

### 기존 런타임 변동

1. **NanoClaw**: Docker 파트너십 체결 (3/13). MicroVM 샌드박스 통합. Docker-free 모드 가능성 더욱 낮아짐 → **보류 유지**
2. **NanoBot**: 27.9k → 34.6k stars. 가장 높은 성장세. 여전히 Python 기반으로 Termux 네이티브 실행 가능
3. **PicoClaw**: v0.2.4에서 32-bit 아키텍처 지원 추가. 여전히 정적 바이너리
4. **ZeroClaw**: 레포 분리 (openagen → zeroclaw-labs). stars 16k (레포 이전 영향 가능)
5. **Moltis**: 1.8k → 2.3k stars. v0.10.18 릴리스. 판정 변경 없음

### 신규 런타임 평가

1. **OpenCode** (122k stars): Go 기반 터미널 코딩 에이전트. 75+ LLM 프로바이더. **이미 `install-opencode.sh`로 지원 중**
2. **Junie CLI** (JetBrains): 2026-03 beta 출시. LLM-agnostic. 바이너리 타입 미확인 → **GA 후 재평가**
3. **OpenHands** (69k stars): Python 기반, Docker 필수. Android 실행 불가 → **제외**
4. **Copilot CLI** (GitHub): 2026-03 GA. 클로즈드 소스 → **대상 외**

### 결론

- **Moltis 지원 확정 유지** — 여전히 유일하게 glibc-runner가 필요한 런타임
- **신규 후보 없음** — 새 런타임들은 모두 정적 바이너리/Python/Docker 기반
- **Junie CLI만 관찰** — beta → GA 후 바이너리 분석 필요

---

## 구현 계획

### Phase 1 — Moltis (확정, 즉시 착수 가능)

- **상세 기획서**: `02-moltis-support.md`
- **런타임**: Rust 단일 바이너리 (`aarch64-unknown-linux-gnu`)
- **최신 버전**: v0.10.18 (2026-03-09)
- **설치 방식**: GitHub Release에서 바이너리 다운로드 + glibc-runner 래퍼
- **핵심 작업**:
  - `platforms/moltis/` 플러그인 생성 (config.env, install.sh, update.sh 등)
  - glibc-runner 래퍼 스크립트 (Node.js 래퍼와 동일 패턴)
  - 기본 설정: `sandbox.mode = "off"` (Docker 없는 환경 대응)
  - systemctl 스텁 재활용
- **예상 난이도**: 하 (glibc-runner 인프라 이미 존재, 단일 바이너리)

### NanoClaw (보류 유지)

- **상세 기획서**: `03-nanoclaw-support.md`
- **블로커**: Docker 하드 의존성 — 2026-03 Docker 파트너십으로 더욱 강화
- **재검토 조건**: NanoClaw 업스트림에서 Docker-free 모드 추가 시 (가능성 낮음)

### Junie CLI (관찰)

- **상태**: beta (2026-03-09 출시)
- **재평가 시점**: GA 출시 후
- **확인 필요**: 바이너리 타입 (정적/glibc 동적), arm64 지원 여부

---

## 제외 런타임 대응

| 런타임 | 대응 방식 |
|--------|----------|
| PicoClaw | 📄 Termux 직접 설치 가이드 제공 (정적 바이너리 다운로드) |
| NanoBot | 📄 Termux 직접 설치 가이드 제공 (`pkg install python && pip install nanobot-ai`) |
| ZeroClaw | 📄 Termux 직접 설치 가이드 제공 (musl 바이너리 다운로드) |
| memU | 📄 Termux 직접 설치 가이드 제공 (`pip install memu-py`) |
| OpenHands | 📄 Docker 환경 필요 안내 (Android 미지원) |

---

## 참고사항

- 사용자 수는 2026-03-29 기준이며, 주기적 재평가 필요
- 실익 점수는 세부 조사(바이너리 분석, CI 확인) 결과 확정됨
- 세부 기획서: `02-moltis-support.md`, `03-nanoclaw-support.md`, `04-picoclaw-support.md`

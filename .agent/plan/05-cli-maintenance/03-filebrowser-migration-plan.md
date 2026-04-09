# dufs → Filebrowser 교체 계획

## Overview

파일 전송 서버를 [dufs](https://github.com/sigoden/dufs) (단순 HTTP/WebDAV 디렉토리 리스팅)에서 [Filebrowser](https://github.com/filebrowser/filebrowser) (풀 웹 파일매니저)로 교체한다.

glibc-runner 도입으로 표준 Linux 바이너리 실행이 가능해졌기 때문에, Termux pkg에 의존하지 않는 더 강력한 도구를 사용할 수 있게 되었다.

## 왜 교체하는가

| | dufs | Filebrowser |
|---|---|---|
| 유형 | 정적 HTTP/WebDAV 서버 | 웹 기반 파일 매니저 |
| UI | 기본 디렉토리 리스팅 | 풀 파일 매니저 UI (Explorer 스타일) |
| 인증 | Basic Auth (단일 계정) | 유저/권한 관리 (다중 사용자) |
| 파일 편집 | ❌ | ✅ 텍스트 에디터 내장 |
| 공유 링크 | ❌ | ✅ 링크 생성 (만료 설정 가능) |
| 검색 | ❌ | ✅ 파일명 검색 |
| 업/다운로드 | ✅ | ✅ (드래그&드롭, 다중 파일, 폴더) |
| 설치 방식 | Termux pkg (Bionic) | GitHub 릴리스 바이너리 (Go) |
| 바이너리 크기 | ~5MB | ~35-40MB |
| 메모리 사용 | ~10-15MB | 유휴 50-200MB (썸네일 비활성 시 절감) |
| 데이터 저장소 | 없음 (stateless) | BoltDB 단일 파일 (~설정, 유저, 공유링크) |

**핵심 이점**: dufs는 단순 파일 업/다운로드만 가능하지만, Filebrowser는 웹 기반 파일 탐색기로서 파일 편집, 공유 링크 생성, 다중 사용자 관리 등 실질적인 파일 관리 기능을 제공한다.

---

## Filebrowser 기술 정보

### 바이너리

- **언어**: Go (BoltDB 내장 — 외부 DB 서버 불필요)
- **릴리스**: GitHub Releases, `linux-arm64` 바이너리 제공
- **다운로드 URL 패턴**:
  ```
  https://github.com/filebrowser/filebrowser/releases/download/v{VERSION}/linux-arm64-filebrowser.tar.gz
  ```
- **최신 버전 확인**: `https://api.github.com/repos/filebrowser/filebrowser/releases/latest`
- **현재 최신**: v2.61.0

### 기본 설정

| 항목 | 기본값 |
|------|--------|
| 포트 | 8080 |
| 바인드 주소 | `127.0.0.1` (Termux에서는 `0.0.0.0` 명시 필요) |
| 루트 디렉토리 | `.` (현재 디렉토리) |
| 데이터베이스 | `./filebrowser.db` |
| 기본 계정 | admin / 랜덤 비밀번호 (첫 실행 시 콘솔에 1회 출력) |
| 인증 | 활성 (로그인 필요) |

### CLI 주요 명령

```bash
# 버전 확인
filebrowser version

# 기본 실행
filebrowser --port 8081 --root /sdcard --database ~/.filebrowser.db

# 인증 없이 실행 (--noauth)
filebrowser --port 8081 --root /sdcard --noauth

# 설정 초기화
filebrowser config init --database ~/.filebrowser.db

# 유저 관리
filebrowser users add USERNAME PASSWORD --database ~/.filebrowser.db
filebrowser users update USERNAME --password NEWPASS --database ~/.filebrowser.db

# 설정 변경
filebrowser config set --port 8081 --root /sdcard --database ~/.filebrowser.db
```

 Filebrowser의 CLI 플래그는 `-p` (short)와 `--port` (long) 모두 지원한다.
또한 `FB_` 접두사 환경변수로도 설정 가능:
```bash
export FB_PORT=8080
export FB_ADDRESS=0.0.0.0
export FB_ROOT=/path/to/files
export FB_DATABASE=/path/to/filebrowser.db
export FB_NOAUTH=true
filebrowser  # 환경변수 자동 적용
```

**Termux 저메모리 환경 최적화 플래그**:
```bash
filebrowser --disableThumbnails --disablePreviewResize --disableImageResolutionCalc
```
썸네일/이미지 처리를 비활성화하면 메모리 사용량을 50-200MB 수준으로 유지할 수 있다.

**버전 출력 형식**:
```
Version: v2.61.0
Commit: 148b3c5
Built: 2026-02-28T10:09:34Z
```

### glibc 호환성 (검증 필요)

Go 바이너리의 링킹 방식에 따라 두 가지 시나리오가 존재한다:

| 시나리오 | 조건 | 대응 |
|----------|------|------|
| 정적 링킹 (또는 musl) | `ldd filebrowser` → "not a dynamic executable" | 직접 실행 (grun 불필요) |
| 동적 링킹 (glibc) | `ldd filebrowser` → glibc 의존성 표시 | grun wrapper 필요 (code-server, Node.js와 동일 방식) |

**설치 스크립트에서 자동 감지**:
```bash
# 직접 실행 시도 → 실패하면 grun wrapper 생성
if ./filebrowser version &>/dev/null; then
    # 직접 실행 가능 (정적 링킹)
    cp ./filebrowser "$PREFIX/bin/filebrowser"
else
    # grun wrapper 필요 (동적 링킹)
    cp ./filebrowser "$PREFIX/bin/filebrowser.real"
    cat > "$PREFIX/bin/filebrowser" << 'WRAPPER'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
exec "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" "$(dirname "$0")/filebrowser.real" "$@"
WRAPPER
    chmod +x "$PREFIX/bin/filebrowser"
fi
```

---

## 영향 범위

### 변경 대상 파일

| 파일 | 변경 유형 | 내용 |
|------|-----------|------|
| `scripts/install-deps.sh` | **수정** | `dufs`를 PACKAGES 배열에서 제거 |
| `scripts/install-filebrowser.sh` | **신규** | Filebrowser 설치/업데이트 전용 스크립트 |
| `install.sh` | **수정** | Filebrowser 설치 단계 추가 (code-server 설치 전후) |
| `update-core.sh` | **수정** | dufs 설치/검사를 filebrowser로 교체 |
| `uninstall.sh` | **수정** | Filebrowser 제거 로직 추가 |
| `oa.sh` | **수정** | `--status`에서 dufs → filebrowser로 버전 표시 |
| `bootstrap.sh` | **수정** | install-filebrowser.sh 다운로드 추가 |
| `README.md` | **수정** | dufs 언급을 filebrowser로 교체 |
| `README.ko.md` | **수정** | 동일 |

### 기존 사용자 영향

- **`oa --update`**: 기존 dufs 사용자에게 filebrowser 설치를 제안. dufs는 자동 제거하지 않음 (pkg로 설치된 것이므로 별도 관리)
- **`oa --uninstall`**: filebrowser 제거 프롬프트 추가
- **`oa --status`**: filebrowser 상태 표시 (dufs가 있으면 그것도 표시)

---

## 구현 계획

### 1. `scripts/install-filebrowser.sh` (신규)

code-server 설치 스크립트와 유사한 구조. GitHub 릴리스에서 최신 arm64 바이너리를 다운로드하여 설치.

**설치 흐름**:
```
1. 이미 설치되어 있으면 스킵 (또는 업데이트 모드에서 버전 비교)
2. GitHub API로 최신 버전 조회
3. linux-arm64-filebrowser.tar.gz 다운로드
4. tar 추출
5. glibc 의존성 자동 감지 → 직접 설치 또는 grun wrapper 생성
6. $PREFIX/bin/filebrowser 에 설치
7. 데이터베이스 디렉토리 생성 (~/.openclaw-android/filebrowser/)
8. filebrowser version 으로 검증
```

**업데이트 모드** (`update` 인자):
```bash
# 현재 버전과 최신 버전 비교
CURRENT=$(filebrowser version 2>/dev/null | grep -oP 'v[\d.]+' || echo "")
LATEST=$(curl -sL "https://api.github.com/repos/filebrowser/filebrowser/releases/latest" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)

if [ "$CURRENT" = "$LATEST" ]; then
    echo "[OK] filebrowser already up to date ($CURRENT)"
    exit 0
fi
```

### 2. `scripts/install-deps.sh` (수정)

```diff
 PACKAGES=(
     git
     python
     make
     cmake
     clang
     binutils
     tmux
     ttyd
-    dufs
     android-tools
 )
```

dufs 제거. Filebrowser는 별도 스크립트로 설치.

### 3. `install.sh` (수정)

스텝 수 변경: 11 → 12 (또는 기존 스텝 재배치)

```
[1/12] Environment Check
[2/12] Installing Base Dependencies    ← dufs 제거됨
[3/12] Installing glibc Environment
[4/12] Setting Up Paths
[5/12] Configuring Environment Variables
[6/12] Installing OpenClaw + Patches
[7/12] Installing Filebrowser          ← 신규 (또는 code-server 다음)
[8/12] Installing code-server
[9/12] Installing OpenCode + oh-my-opencode
[10/12] AI CLI Tools
[11/12] Verifying Installation
[12/12] Updating OpenClaw
```

또는 기존 11스텝 유지하고, Filebrowser를 Dependencies 단계에서 설치하는 방안도 고려.

### 4. `update-core.sh` (수정)

**Step [2/10] 기존 dufs 블록 교체**:

```bash
# 기존:
# Install dufs if not already installed
if command -v dufs &>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   dufs already installed (...)"
else
    ...pkg install -y dufs...
fi

# 변경:
# Install/update filebrowser
if command -v filebrowser &>/dev/null; then
    echo -e "${GREEN}[OK]${NC}   filebrowser already installed ($(filebrowser version 2>/dev/null | head -1))"
else
    INSTALL_FB=true
    if [ -t 0 ]; then
        read -rp "Filebrowser (web file manager) is not installed. Install it? [Y/n] " REPLY
        [[ "$REPLY" =~ ^[Nn]$ ]] && INSTALL_FB=false
    fi
    if [ "$INSTALL_FB" = true ]; then
        bash "$SCRIPTS_DIR/install-filebrowser.sh" || echo -e "${YELLOW}[WARN]${NC} Failed to install filebrowser (non-critical)"
    else
        echo -e "${YELLOW}[SKIP]${NC} Skipping filebrowser"
    fi
fi
```

**Step [8/10] filebrowser 업데이트 추가** (기존 code-server 업데이트와 유사):
```bash
echo ""
echo "[8/10] Updating filebrowser..."
if command -v filebrowser &>/dev/null; then
    bash "$SCRIPTS_DIR/install-filebrowser.sh" update || echo -e "${YELLOW}[WARN]${NC} Failed to update filebrowser"
else
    # 미설치 시 설치 여부 질문
    ...
fi
```

### 5. `uninstall.sh` (수정)

code-server 제거 블록 뒤에 Filebrowser 제거 추가:

```bash
# Remove Filebrowser
echo ""
if command -v filebrowser &>/dev/null || [ -f "$PREFIX/bin/filebrowser" ]; then
    read -rp "Remove Filebrowser (web file manager)? [Y/n] " REPLY
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
        rm -f "$PREFIX/bin/filebrowser"
        rm -f "$PREFIX/bin/filebrowser.real"  # grun wrapper인 경우
        rm -rf "$HOME/.openclaw-android/filebrowser"  # DB, 설정
        echo -e "${GREEN}[OK]${NC}   Removed filebrowser"
    else
        echo -e "${YELLOW}[KEEP]${NC} Keeping filebrowser"
    fi
fi
```

### 6. `oa.sh` — `--status` (수정)

```bash
# 기존:
if command -v dufs &>/dev/null; then
    local dufs_ver
    dufs_ver=$(dufs --version 2>/dev/null | head -1 || echo "installed")
    echo "  dufs:        ${dufs_ver}"
else
    echo -e "  dufs:        ${YELLOW}not installed${NC}"
fi

# 변경:
if command -v filebrowser &>/dev/null; then
    local fb_ver
    fb_ver=$(filebrowser version 2>/dev/null | head -1 || echo "installed")
    echo "  filebrowser: ${fb_ver}"
else
    echo -e "  filebrowser: ${YELLOW}not installed${NC}"
fi
```

### 7. `bootstrap.sh` (수정)

다운로드 파일 목록에 `install-filebrowser.sh` 추가:

```bash
SCRIPTS=(
    ...
    "scripts/install-filebrowser.sh"
    ...
)
```

### 8. `README.md` / `README.ko.md` (수정)

모든 dufs 언급을 filebrowser로 교체:

| 위치 | 변경 내용 |
|------|-----------|
| Status Check 설명 | "dufs" → "Filebrowser" |
| Update 설명 | "dufs" → "Filebrowser" |
| What It Does 패키지 테이블 | dufs 행을 filebrowser로 교체 |
| Additional Install Options 테이블 | dufs → filebrowser, 설명 업그레이드 |
| Detailed Installation Flow | install-deps.sh에서 dufs 제거, install-filebrowser.sh 단계 추가 |

---

## 마이그레이션 전략 (기존 사용자)

### `oa --update` 시나리오

```
Case 1: dufs 설치됨 + filebrowser 미설치
  → "Filebrowser (web file manager) is a powerful upgrade from dufs. Install it? [Y/n]"
  → Y: filebrowser 설치. dufs는 유지 (사용자가 직접 pkg uninstall dufs 가능)
  → N: 스킵

Case 2: filebrowser 이미 설치됨
  → 버전 비교 후 업데이트 또는 스킵

Case 3: 둘 다 미설치
  → "Filebrowser (web file manager) is not installed. Install it? [Y/n]"
```

### dufs 자동 제거 여부

**제거하지 않음**. 이유:
- dufs는 `pkg install`로 설치된 Termux 네이티브 패키지
- 사용자가 다른 용도로 사용 중일 수 있음
- 자동 제거는 예기치 않은 동작
- 안내 메시지로 수동 제거 방법 제공:
  ```
  [INFO] dufs is still installed. You can remove it with: pkg uninstall dufs
  ```

---

## 설치 경로

```
$PREFIX/bin/filebrowser              ← 실행 파일 (또는 grun wrapper)
$PREFIX/bin/filebrowser.real         ← 실제 바이너리 (grun wrapper인 경우만)
$HOME/.openclaw-android/filebrowser/ ← 데이터 디렉토리
$HOME/.openclaw-android/filebrowser/filebrowser.db ← SQLite DB
```

---

## PoC 검증 항목

SSH 기기에서 수동 테스트:

| # | 검증 항목 | 명령 | 성공 기준 |
|---|-----------|------|-----------|
| 1 | 바이너리 다운로드 | `curl -fsSL ... \| tar xz` | 파일 추출 성공 |
| 2 | 링킹 방식 확인 | `file filebrowser` / `ldd filebrowser` | 정적/동적 판별 |
| 3 | 직접 실행 | `./filebrowser version` | 버전 출력 |
| 4 | grun 실행 (동적인 경우) | `grun ./filebrowser version` | 버전 출력 |
| 5 | 서버 시작 | `filebrowser --port 8081 --root $HOME --noauth` | 8081 포트 리슨 |
| 6 | 브라우저 접속 | `http://<phone-ip>:8081` | Web UI 표시 |
| 7 | 파일 업로드 | 브라우저에서 파일 업로드 | 업로드 성공 |
| 8 | 파일 다운로드 | 브라우저에서 파일 다운로드 | 다운로드 성공 |
| 9 | 메모리 사용량 | `ps aux \| grep filebrowser` | RSS < 50MB |

---

## 버전 관리

이 변경은 기능 교체이므로 **v1.1.0** (마이너 버전 업) 적절.

## 예상 작업량

| 항목 | 난이도 | 예상 시간 |
|------|--------|-----------|
| install-filebrowser.sh 신규 작성 | 중 | code-server 스크립트 참고하여 작성 |
| install-deps.sh 수정 | 하 | dufs 1줄 제거 |
| update-core.sh 수정 | 중 | dufs 블록 → filebrowser 블록 교체 |
| uninstall.sh 수정 | 하 | filebrowser 제거 블록 추가 |
| oa.sh 수정 | 하 | --status 1블록 교체 |
| install.sh 수정 | 하 | 스텝 추가 |
| bootstrap.sh 수정 | 하 | 다운로드 목록 추가 |
| README.md 수정 | 중 | dufs → filebrowser 전체 교체 |
| README.ko.md 수정 | 중 | 동일 |
| PoC 검증 | 중 | SSH 기기 테스트 |

---

## 참고

- Filebrowser GitHub: https://github.com/filebrowser/filebrowser
- Filebrowser Docs: https://filebrowser.org
- dufs GitHub: https://github.com/sigoden/dufs

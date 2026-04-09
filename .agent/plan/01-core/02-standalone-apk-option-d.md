# Option D: Hybrid Wrapper — 상세 실행 계획

> 작성일: 2026-03-05
> 상태: Draft (Oracle 검증 완료, 라이선스·배포 전략 확정, **아키텍처 확정: Thin APK + WebView UI + OTA**)
> 상위 문서: `01-standalone-apk.md` (초기 조사, 4개 옵션 비교, 아카이브)
> 요약: Thin APK (~5MB) + WebView UI + OTA 업데이트. Termux bootstrap 런타임 다운로드 + terminal-view + 플랫폼 선택기
> 프로젝트: github.com/AidanPark/openclaw-android (238 stars, v1.0.4)

---

## 0. 배경 및 의사결정 경위

### 0.1 프로젝트 목적

openclaw-android는 다양한 에이전트 런타임(OpenClaw, PicoClaw, NanoBot, ZeroClaw, Moltis 등)을
Android에서 구동하기 위한 기반 인프라다. 현재는 OpenClaw만 지원하며, 향후 런타임을 추가할 예정.
GitHub에 공개되어 사용자들이 이용 중이며 이슈가 올라오고 있다.

### 0.2 문제 정의

현재 설치 과정:
1. F-Droid에서 Termux 설치
2. `pkg update && pkg install curl`
3. `curl -sL myopenclawhub.com/install | bash` (3-10분)
4. `openclaw onboard` → `openclaw gateway`

**핵심 문제**: 5단계, 2개 앱 설치, CLI 숙련도 필요. 사용자가 Termux 설치 + 스크립트 실행에 피로감.

### 0.3 의사결정 타임라인

| 단계 | 발견/결정 | 영향 |
|------|----------|------|
| 1. 초기 조사 | 4개 옵션 비교 (A: Termux 포크, B: termux-shared, C: Clean Room, D: Hybrid) | Option D 선택 |
| 2. Node.js 조사 | nodejs-mobile(Node 18), LiquidCore(Dead), node-on-android(Dead), Official(실험적) 분석 | Bionic-native Node.js 불채택 |
| 3. child_process 발견 | Android Bionic에서 child_process 불가 → 호환 레이어 필수 | glibc-runner 필요 판단 |
| 4. AnyClaw 발견 | Termux bootstrap 방식의 독립 APK가 Play Store에 존재 (10K+ DL) | 선례 확인 |
| 5. Oracle 검증 | ① targetSdk=28 불필요 (jniLibs는 항상 exec 가능) ② glibc-runner→Termux bootstrap 전환 권고 ③ child_process 제약은 JNI 임베딩 한정, standalone 프로세스는 OK | **핵심 설계 수정** |
| 6. 범위 확정 | OAuth/API키 UI 제거 — 플랫폼이 터미널에서 온보딩 처리 | 앱 범위 축소 |
| 7. 라이선스 확정 | GPL v3 수용 — 소스 전부 공개 | APK 레포 GPL v3 |
| 8. 배포 전략 확정 | Play Store 미게시 — F-Droid + GitHub Releases | 16KB 정렬·심사 리스크 제거 |
| 9. 아키텍처 확정 | AnyClaw 리서치 → **Option B 채택**: targetSdk 28, jniLibs 미사용, bootstrap ZIP 직접 추출, terminal-view 로컬 소스 모듈 | **실행 아키텍처 확정** |
| 10. 구현 상세 리서치 | fixTermuxPaths 범위(텍스트+ELF), apt 설정(apt.conf 재작성, HTTPS→HTTP), libtermux-exec.so 동작, terminal-view 빌드 상세, minSdk=24 확정 | **Phase 0 실행 가능** |
| 11. Thin APK + WebView UI | APK 최소화 (~5MB), bootstrap 런타임 다운로드, WebView UI (터미널 제외), OTA 업데이트 아키텍처 채택 | **APK 재설치 최소화 구조 확정** |

### 0.4 기각된 대안

**Option A (Termux 포크)**: Termux 전체 포크. 200+ 파일, upstream 추적 부담. 유지보수 비용 > 이점.

**Option B (termux-shared 라이브러리)**: `termux-shared`는 Termux 플러그인 앱용 IPC 레이어. 독립 앱에 필요한 것은 `terminal-view`(터미널 UI)이지 `termux-shared`(통신 레이어)가 아니다.

**Option C (Clean Room)**: 8-12주 소요. 터미널 에뮬레이터 직접 구현 필요. terminal-view 라이브러리를 쓸 수 있으므로 이 비용을 들일 이유 없음.

**Bionic-native Node.js (nodejs-mobile)**: Node 18만 지원 (OpenClaw은 22+ 필요). `child_process.spawn()`, `fork()`, `cluster` 미지원. OpenClaw의 핵심 기능(git, npm, shell 명령 실행)이 불가.

**"Termux 자동설치 앱"**: Termux 설치 여부 확인 → 자동 설치 → 스크립트 실행. 개발 2주면 충분하지만, "2개 앱" 문제를 해결하지 못함. 근본적 UX 개선 아님.

**jniLibs 패키징 (Oracle 초기 권고)**: 핵심 바이너리를 `lib_*.so`로 jniLibs에 넣어 exec 보장. AnyClaw 리서치 결과 targetSdk 28이면 `/data/data/` 경로에서도 exec 가능하므로 불필요한 복잡성. jniLibs 미사용이 AnyClaw/Termux F-Droid 동일 방식.

---

## 1. 아키텍처 개요

### 1.1 핵심 원칙

- **Thin APK (~5MB)**: APK에는 Kotlin 앱 셸 + libtermux.so만 포함. Bootstrap은 런타임 다운로드.
- **WebView UI**: 터미널(terminal-view PTY)만 네이티브. 나머지 모든 UI는 WebView로 구현 → www.zip으로 런타임 업데이트.
- **APK 재설치 최소화**: UI 변경, bootstrap 업데이트, 플랫폼 업데이트, 스크립트 변경 모두 APK 재설치 없이 OTA 업데이트.
- **앱 = 런타임 + 터미널 + 플랫폼 선택기**. 그 이상은 하지 않는다.
- LLM 인증, 대시보드, 온보딩은 각 **플랫폼이 터미널 안에서 처리**.
- 검증된 기술만 사용: Termux bootstrap (AnyClaw 증명), terminal-view (ReTerminal 증명).
- **targetSdk 28**: W^X 우회 — `/data/data/` 경로에서 exec 가능. AnyClaw, Termux F-Droid 동일 방식.

### 1.2 레이어 구조

```
┌──────────────────────────────────────────────────────┐
│ OpenClaw APK (~5MB, com.openclaw.android)            │
│ targetSdkVersion = 28, minSdkVersion = 24            │
│ ┌──────────────────────────────────────────────────┐ │
│ │ APK 고정 (Kotlin, 재설치 시에만 변경)             │ │
│ │ ├── MainActivity.kt  ← WebView + TerminalView    │ │
│ │ │                       컨테이너                  │ │
│ │ ├── OpenClawService.kt ← FGS (START_STICKY)      │ │
│ │ ├── BootstrapManager.kt ← 다운로드 + 추출         │ │
│ │ ├── JsBridge.kt ← @JavascriptInterface            │ │
│ │ │                  (WebView ↔ Kotlin 브릿지)       │ │
│ │ └── libtermux.so ← PTY (NDK, terminal-view)       │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ 런타임 업데이트 가능 (OTA, APK 재설치 불필요)     │ │
│ │ ├── www/              ← WebView UI (www.zip)      │ │
│ │ │   ├── index.html                                │ │
│ │ │   ├── app.js         ← SPA (React)              │ │
│ │ │   ├── setup/          ← 첫 실행 셋업 UI         │ │
│ │ │   ├── platforms/      ← 플랫폼 선택기            │ │
│ │ │   ├── settings/       ← 설정 화면               │ │
│ │ │   └── dashboard/      ← 대시보드                │ │
│ │ ├── bootstrap/         ← Termux bootstrap (다운로드)│ │
│ │ │   ├── usr/bin/        ← sh, coreutils, apt       │ │
│ │ │   ├── usr/lib/        ← 공유 라이브러리, SSL     │ │
│ │ │   ├── usr/etc/        ← resolv.conf, SSL certs   │ │
│ │ │   └── SYMLINKS.txt   ← 심볼릭 링크 정의         │ │
│ │ ├── runtime/           ← 첫 실행 후 apt 설치      │ │
│ │ │   ├── Node.js v22+   (apt-get download)          │ │
│ │ │   ├── git             (apt-get download)         │ │
│ │ │   └── libtermux-exec.so (LD_PRELOAD)             │ │
│ │ ├── scripts/           ← 관리 스크립트 (OTA)      │ │
│ │ │   ├── update.sh                                  │ │
│ │ │   └── platform-manager.sh                       │ │
│ │ └── config.json        ← 원격 설정 (기능 플래그)  │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ Data Layer (/data/data/com.openclaw.android/)    │ │
│ │ ├── files/usr/          ← $PREFIX (exec 가능)     │ │
│ │ ├── files/home/         ← $HOME                   │ │
│ │ └── files/tmp/          ← $TMPDIR                 │ │
│ └──────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 1.3 기존 계획 대비 변경 사항

| 항목 | 기존 (standalone-apk.md) | 수정안 (본 문서) | 근거 |
|------|------------------------|-----------------|------|
| 런타임 | glibc-runner (pacman) | **Termux bootstrap** | APK 내 검증 사례 없음 → AnyClaw 증명된 방식 채택 |
| bootstrap 번들 | assets/bootstrap-aarch64.zip (APK 포함) | **첫 실행 시 런타임 다운로드** | APK ~30-40MB → ~5MB. 사용자 데이터 절약 |
| UI | 네이티브 Kotlin UI | **WebView UI** (터미널 제외) | www.zip으로 런타임 업데이트 가능. APK 재설치 불필요 |
| 업데이트 | APK 재빌드 + 재설치 | **OTA 업데이트** (bootstrap, 웹UI, 스크립트, 설정) | APK 재설치는 libtermux.so 버그, 새 JsBridge API, FGS 변경 시에만 |
| APK 크기 | ~30-40MB | **~5MB** | Bootstrap + 웹UI를 런타임 다운로드로 분리 |
| targetSdkVersion | 28 → 35 (Oracle 권고) | **28** | AnyClaw 리서치: targetSdk 28이면 `/data/data/` exec 가능. jniLibs 불필요 |
| minSdkVersion | 미정 | **24** | bootstrap `apt-android-7` 변형이 API 24+ 전용 바이너리 포함 |
| 바이너리 실행 | jniLibs (`lib_*.so`) + 심볼릭 링크 | **bootstrap ZIP에서 직접 추출** | targetSdk 28 = W^X 미적용. jniLibs 패키징 불필요 |
| Node.js/git | APK에 번들 (jniLibs) | **첫 실행 시 apt 설치** | `apt-get download` + `dpkg-deb -x` (AnyClaw 패턴) |
| 터미널 라이브러리 | terminal-view (JitPack) | **terminal-view (로컬 소스 모듈)** | ReTerminal 방식. ndkBuild로 libtermux.so 직접 생성 |
| Foreground Service | specialUse 타입 | **일반 START_STICKY** | targetSdk 28에서 specialUse 불필요 (Android 14+ API) |
| 배포 채널 | Play Store 검토 | **F-Droid + GitHub Releases** | Play Store 미게시. 16KB 정렬·심사 리스크 제거 |
| 예상 기간 | 4-6주 | **6-8주** | Thin APK + WebView UI + OTA 아키텍처 추가 |
| OAuth / API 키 UI | 네이티브 UI 구현 | **제거** | 플랫폼 온보딩이 터미널에서 처리 |
| 라이선스 | 미정 | **GPL v3** | 소스 전부 공개. Termux 패키지(GPL) 번들 의무 충족 |

---

## 2. 기술 결정

### 2.1 런타임: Termux Bootstrap (런타임 다운로드)

**왜 glibc-runner에서 전환하는가:**

glibc-runner는 현재 Termux CLI 프로젝트에서는 잘 작동하지만 APK 내부에서는:
- pacman, `$PREFIX` 레이아웃, POSIX 유틸리티 등 Termux 의존성이 숨어 있다
- 이를 APK에서 재구축하면 스코핑되지 않은 작업이 대량 발생 (예상 10주+)
- APK 안에서 glibc의 `ld.so`가 정상 작동하는지 **전례가 없다**

**child_process 제약에 대한 정확한 이해 (Oracle 검증):**

child_process 불가는 **JNI 임베딩(nodejs-mobile) 한정**이지, Bionic vs glibc 문제가 아니다.
Node.js를 **독립 프로세스**로 실행하면 (Termux bootstrap 또는 glibc-runner 모두)
child_process.spawn()이 정상 작동한다. 이것은 glibc-runner가 필수인 이유가 아니다.

| Node.js 실행 방식 | child_process | 근거 |
|-------------------|---------------|------|
| JNI 임베딩 (nodejs-mobile) | ❌ 불가 | Android Zygote 모델, SELinux 제한 |
| 독립 프로세스 (Termux bootstrap) | ✅ 가능 | Termux/AnyClaw에서 증명 |
| 독립 프로세스 (glibc-runner) | ✅ 가능 | 현재 CLI 프로젝트에서 증명 |

**Termux bootstrap 방식 (Thin APK 패턴):**

AnyClaw는 bootstrap을 assets에 번들하지만 (~25MB), 우리는 **첫 실행 시 런타임 다운로드**로 변경하여 APK 크기를 ~5MB로 최소화한다:
```
bootstrap-aarch64.zip 내용물 (Termux GitHub Releases에서 다운로드, ~25MB):
├── usr/bin/         ← sh, coreutils, apt
├── usr/lib/         ← 공유 라이브러리, SSL, libtermux-exec.so
├── usr/etc/         ← resolv.conf, SSL certs
├── usr/share/       ← terminfo 등
└── SYMLINKS.txt     ← 심볼릭 링크 정의
```

- **다운로드 URL**: Termux 공식 GitHub Releases (`bootstrap-2026.02.12-r1+apt.android-7`)
- `download-bootstrap.sh`로 링크 관리, 원격 config.json으로 URL 동적 제어 가능
- **`apt-android-7` 변형**: API 24+ (Android 7.0+) 전용. `DT_RUNPATH` 사용, busybox 불필요
- 첫 실행 시 `ZipInputStream` → staging 디렉토리 → atomic rename → `fixTermuxPaths`
- Node.js/git은 **APK에 번들하지 않음** — 첫 실행 후 `apt-get download` + `dpkg-deb -x`로 설치 (postinst 미실행)

**차이점 (AnyClaw vs 우리):**

| 항목 | AnyClaw | 우리 (Thin APK) |
|------|---------|-----------------|
| Bootstrap | assets/에 번들 (~25MB) | **런타임 다운로드** |
| APK 크기 | ~30-40MB | **~5MB** |
| 첨 실행 네트워크 | Node.js/git만 다운로드 | Bootstrap + Node.js/git 다운로드 |
| 오프라인 첫 실행 | ✅ 가능 | ❌ 불가 (네트워크 필수) |
**기존 CLI 프로젝트(Termux용)는 glibc-runner를 계속 사용.** APK 프로젝트만 Termux bootstrap 사용.

### 2.1.1 OpenClaw 런타임 의존성 분류

탐색 에이전트 분석 결과를 APK 번들 관점에서 재분류:

| 분류 | 구성요소 | APK 포함 | 런타임 다운로드 | 비고 |
|------|---------|----------|-----------------|------|
| **APK 고정** | libtermux.so (PTY) | ✅ NDK 빌드 | - | terminal-view 로컬 모듈 |
| **APK 고정** | Kotlin 앱 셸 (MainActivity, JsBridge, FGS 등) | ✅ | - | ~5MB |
| **BOOTSTRAP** | sh, coreutils, apt, SSL certs, libtermux-exec.so | ❌ | ✅ 첫 실행 다운로드 | Termux 공식 bootstrap (~25MB) |
| **WEB UI** | www/ (index.html, app.js, 셋업/플랫폼/설정 UI) | ❌ | ✅ www.zip OTA | APK 재설치 없이 UI 업데이트 |
| **RUNTIME** | Node.js v22+, npm, git | ❌ | ✅ apt 설치 | `apt-get download` + `dpkg-deb -x` |
| **BUILD-ONLY** | python, make, cmake, clang, binutils | ❌ | ❌ 별도 | native 모듈 빌드 시에만 (Phase 2+ 검토) |
| **OPTIONAL** | tmux, ttyd, dufs, code-server | ❌ | ❌ 별도 | 앱 내 설치 옵션 |
| **OPTIONAL** | Claude Code, Gemini CLI, Codex CLI | ❌ | ❌ 별도 | 플랫폼 온보딩에서 설치 |

**APK 크기 추정** (arm64-v8a 전용):
- libtermux.so (NDK): ~1MB
- Kotlin/Android 코드 + WebView 컨테이너: ~4MB
- **APK: ~5MB** (Bootstrap, 웹UI는 첫 실행 시 런타임 다운로드)

### 2.2 바이너리 실행: targetSdk 28 + Bootstrap ZIP 추출

**Android의 exec 정책과 targetSdk의 관계:**

| targetSdkVersion | `/data/data/<pkg>/files/` exec | W^X 적용 |
|------------------|-------------------------------|----------|
| **28 이하** | ✅ 가능 | 미적용 |
| 29+ (Android 10+) | ❌ 불가 | 적용 |

AnyClaw (targetSdk 28), Termux F-Droid (targetSdk 28) 모두 이 방식을 사용.
Play Store 미게시이므로 targetSdk 제약 없음.

**왜 targetSdk 35 + jniLibs가 아닌가:**

Oracle 초기 권고는 targetSdk 35 + jniLibs 패키징이었다 (핵심 바이너리를 `lib_*.so`로 이름 변경 → `jniLibs/arm64-v8a/`에 배치 → `/data/app/.../lib/arm64-v8a/`에서 exec). AnyClaw 리서치 후 이를 기각한 이유:

| 문제 | 설명 | 영향 |
|------|------|------|
| **런타임 바이너리 exec 불가** | targetSdk 29+에서 `files/usr/bin/`이 exec 불가. 사용자가 `apt install tmux`, `apt install python` 등으로 설치해도 실행 불가. jniLibs에 없는 바이너리는 영원히 실행 불가 | 터미널 앱의 존재 이유를 부정하는 **구조적 제약** |
| **바이너리 업데이트 = APK 리빌드** | Node.js 22→24, git 패치 등 모든 바이너리 업데이트가 APK 릴리즈 사이클에 묶임. `apt upgrade`로 즉시 업데이트 불가 | 유지보수 부담 **영구적** |
| **앱 업데이트 시 심볼릭 링크 파손** | `/data/app/<pkg>-XXXX/lib/` 경로의 해시(`XXXX`)가 업데이트마다 변경. 모든 심볼릭 링크 재생성 필요. UserLAnd에서 반복 이슈 | **매 업데이트** 시 발생 |
| **이중 경로 복잡성** | 핵심 바이너리(`/data/app/.../lib/`)와 나머지(`/data/data/.../files/usr/`)가 분리. PATH, 라이브러리 로딩, 스크립트 실행에서 지속적 구분 필요 | 코드 복잡성 **영구적** |

이는 초기 설정 부담이 아니라 **프로젝트 수명 내내 지속되는 구조적 제약**이다.
Termux 자체도 F-Droid에서 targetSdk 28을 사용하는 이유가 동일하다.

#### 2.2.1 Bootstrap 설치 흐름 (Thin APK 방식)

AnyClaw `BootstrapInstaller.kt` 패턴 기반, **assets 대신 네트워크 다운로드**:

```kotlin
class BootstrapInstaller(private val context: Context) {

    fun install(onProgress: (Float, String) -> Unit) {
        val prefixDir = File(context.filesDir, "usr")
        if (prefixDir.exists()) return  // 이미 설치됨

        val stagingDir = File(context.filesDir, "usr-staging")
        stagingDir.mkdirs()

        // 1. 네트워크에서 bootstrap ZIP 다운로드 + 추출
        val zipFile = downloadBootstrap(onProgress)  // Termux GitHub Releases
        ZipInputStream(zipFile.inputStream()).use { zip ->
            var entry = zip.nextEntry
                while (entry != null) {
                    if (entry.name == "SYMLINKS.txt") {
                        // 심볼릭 링크 정의 별도 처리 (경로 치환 포함)
                        processSymlinks(zip, stagingDir)
                    } else if (!entry.isDirectory) {
                        val file = File(stagingDir, entry.name)
                        file.parentFile?.mkdirs()
                        file.outputStream().use { out -> zip.copyTo(out) }
                        if (entry.name.startsWith("bin/") || entry.name.endsWith(".so")) {
                            file.setExecutable(true)
                        }
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
        }

        // 2. Termux 경로 수정 (하드코딩된 /data/data/com.termux → 실제 경로)
        fixTermuxPaths(stagingDir)

        // 3. apt 설정 (sources.list HTTP 다운그레이드 + apt.conf 재작성)
        configureApt(stagingDir)

        // 4. Atomic rename
        stagingDir.renameTo(prefixDir)

        // 5. libtermux-exec.so 설정
        setupTermuxExec(prefixDir)

        // 6. Node.js + git 설치
        installRuntimePackages(onProgress)
    }
}
```

#### 2.2.2 fixTermuxPaths 상세 범위

bootstrap ZIP에는 `/data/data/com.termux/files/usr` 경로가 **텍스트 파일과 ELF 바이너리 모두에** 하드코딩되어 있다. 우리 패키지명(`com.openclaw.android`)으로 치환이 필요.

**텍스트 파일 치환:**

| 대상 | 방법 | 비고 |
|------|------|------|
| `SYMLINKS.txt` 심볼릭 링크 타겟 | ZIP 추출 시 **실시간** 경로 교체 | `processSymlinks()`에서 처리 |
| `var/lib/dpkg/status` | 문자열 치환 (`com.termux` → `com.openclaw.android`) | 패키지 상태 DB |
| `var/lib/dpkg/info/*.list` | 동일 문자열 치환 | 설치된 파일 목록 |
| `libexec/git-core/git-*` 스크립트 | shebang 경로 치환 (`sed -i`) | git 서브커맨드 스크립트 |

**ELF 바이너리 패치:**

| 대상 | 방법 | 비고 |
|------|------|------|
| `bin/make`, `bin/cmake` | **바이너리 바이트 치환** + null-padding | shell 경로가 컴파일타임 상수로 포함 |

```python
# AnyClaw의 ELF 패치 로직 (Python으로 실행)
pairs = [
    (b"/data/data/com.termux/files/usr/bin/sh", b"/system/bin/sh"),
    (b"/data/data/com.termux/files/usr/bin/bash", b"/system/bin/sh"),
]
for old, new in pairs:
    padded = new + b"\x00" * (len(old) - len(new))  # 원본 길이 유지
    data = data.replace(old, padded)
```

> ⚠️ `make`, `cmake`는 Phase 0에서 필요 없음 (BUILD-ONLY). ELF 패치는 Phase 2+ 검토 시 구현.

#### 2.2.3 apt 설정 (out-of-the-box 미작동)

bootstrap 추출 후 `apt-get`이 **즉시 작동하지 않는다**. 두 가지 설정이 필요:

**문제 1: HTTPS 실패 — `libgnutls.so` 인증서 경로 하드코딩**

`libgnutls.so` 바이너리 내부에 `/data/data/com.termux/files/usr/etc/tls/cert.pem` 경로가 컴파일타임 상수로 포함. 패키지명이 다르면 인증서를 찾지 못해 HTTPS apt 실패.

해결: **`sources.list`를 HTTP로 다운그레이드** (AnyClaw 방식)

```kotlin
fun configureSources(prefix: File) {
    val sourcesList = File(prefix, "etc/apt/sources.list")
    if (sourcesList.exists()) {
        sourcesList.writeText(
            sourcesList.readText()
                .replace("https://", "http://")
                .replace("com.termux", context.packageName)
        )
    }
}
```

> 대안: `SSL_CERT_FILE` 환경변수로 인증서 경로 지정 → HTTPS 유지 가능할 수 있음. Phase 0에서 검증.

**문제 2: apt.conf 경로 불일치**

bootstrap의 apt는 `com.termux` 경로를 기본 사용. **apt.conf 전체 재작성** 필요:

```kotlin
fun configureApt(prefix: File) {
    val aptConf = File(prefix, "etc/apt/apt.conf")
    aptConf.writeText("""
        Dir "/";
        Dir::State "${prefix}/var/lib/apt/";
        Dir::State::status "${prefix}/var/lib/dpkg/status";
        Dir::Cache "${prefix}/var/cache/apt/";
        Dir::Log "${prefix}/var/log/apt/";
        Dir::Etc "${prefix}/etc/apt/";
        Dir::Etc::SourceList "${prefix}/etc/apt/sources.list";
        Dir::Etc::SourceParts "";
        Dir::Bin::dpkg "${prefix}/bin/dpkg";
        Dir::Bin::Methods "${prefix}/lib/apt/methods/";
        Dir::Bin::apt-key "${prefix}/bin/apt-key";
        Dpkg::Options:: "--force-configure-any";
        Dpkg::Options:: "--force-bad-path";
        Dpkg::Options:: "--instdir=${prefix}";
        Acquire::AllowInsecureRepositories "true";
    """.trimIndent())
}
```

실행 시 `APT_CONFIG` 환경변수로 이 파일을 명시적으로 지정해야 한다.

#### 2.2.4 libtermux-exec.so 동작 상세

`libtermux-exec.so`는 `LD_PRELOAD`로 로딩되어 `execve()` 인터셉트 시 절대경로를 `$TERMUX__PREFIX` 기준으로 재매핑한다. 예: `/bin/sh` → `$TERMUX__PREFIX/bin/sh`.

**핵심**: 재컴파일 불필요. **`TERMUX__PREFIX` 환경변수로 런타임 설정**.

```kotlin
// 환경변수만 설정하면 동작
"LD_PRELOAD" to "${prefix}/lib/libtermux-exec.so",
"TERMUX__PREFIX" to prefix.absolutePath,
"TERMUX_PREFIX" to prefix.absolutePath,  // 호환용
```

환경변수가 없으면 컴파일타임 기본값 `/data/data/com.termux/files/usr`로 fallback한다.

**두 가지 변형:**

| 변형 | 대상 | 파일명 |
|------|------|--------|
| direct-ld-preload | Android 10 미만 (targetSdk ≤ 28) | `libtermux-exec-direct-ld-preload.so` |
| linker-ld-preload | Android 10+ (system linker exec) | `libtermux-exec-linker-ld-preload.so` |

`libtermux-exec.so`는 `termux-exec-ld-preload-lib setup` 스크립트 실행 후 생성되는 심볼릭 링크/복사본. **어떤 변형이 필요한지는 Phase 0에서 bootstrap ZIP 내용을 확인하여 결정.**

#### 2.2.5 프로세스 실행 환경 (전체 환경변수)

AnyClaw `CodexServerManager.kt` 패턴 기반, 리서치로 확인된 전체 목록:

```kotlin
fun buildEnvironment(): ProcessBuilder {
    val prefix = File(context.filesDir, "usr")
    val home = File(context.filesDir, "home")

    val pb = ProcessBuilder("sh", "-c", command)
    pb.environment().clear()  // 깨끗한 환경에서 시작

    pb.environment().apply {
        // 기본 경로
        put("PREFIX", prefix.absolutePath)
        put("HOME", home.absolutePath)
        put("TMPDIR", File(context.filesDir, "tmp").absolutePath)
        put("PATH", "${prefix}/bin:${prefix}/bin/applets")
        put("LD_LIBRARY_PATH", "${prefix}/lib")

        // libtermux-exec 경로 변환
        put("LD_PRELOAD", "${prefix}/lib/libtermux-exec.so")
        put("TERMUX__PREFIX", prefix.absolutePath)
        put("TERMUX_PREFIX", prefix.absolutePath)

        // apt/dpkg
        put("APT_CONFIG", "${prefix}/etc/apt/apt.conf")
        put("DPKG_ADMINDIR", "${prefix}/var/lib/dpkg")

        // SSL (libgnutls.so 하드코딩 경로 우회 시도)
        put("SSL_CERT_FILE", "${prefix}/etc/tls/cert.pem")

        // 로케일/터미널
        put("LANG", "en_US.UTF-8")
        put("TERM", "xterm-256color")
    }

    pb.directory(home)
    pb.redirectErrorStream(true)
    return pb
}
```

### 2.3 터미널 UI: terminal-view (로컬 소스 모듈)

**Termux의 터미널 라이브러리 구조:**
- `terminal-emulator`: VT100/xterm 에뮬레이션 엔진 (순수 Java, 14개 클래스)
- `terminal-view`: Android View 구현 (8개 클래스 + 리소스, terminal-emulator를 `api`로 의존)

**로컬 소스 모듈로 통합 (ReTerminal 방식):**

```
app/
├── build.gradle.kts              ← Kotlin DSL
├── src/main/...
terminal-emulator/                ← Termux 소스 복사 (ReTerminal에서 byte-for-byte 동일)
├── build.gradle                  ← ⚠️ Groovy DSL (.kts 아님)
├── src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/termux/terminal/
│   │   ├── JNI.java             ← JNI 브릿지 클래스
│   │   ├── TerminalEmulator.java
│   │   ├── TerminalSession.java
│   │   ├── TerminalSessionClient.java
│   │   └── ... (14개 Java 파일)
│   └── jni/
│       ├── Android.mk           ← NDK 빌드 (5줄, CMake 아님)
│       └── termux.c             ← 유일한 C 소스 (5개 JNI 함수)
terminal-view/                    ← Termux 소스 복사
├── build.gradle                  ← ⚠️ Groovy DSL (.kts 아님)
├── src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/termux/view/
│   │   ├── TerminalView.java    ← 앱에 임베드하는 View
│   │   ├── TerminalViewClient.java
│   │   ├── TerminalRenderer.java
│   │   └── ... (8개 Java 파일)
│   └── res/
│       ├── drawable/             ← 텍스트 선택 핸들
│       └── values/strings.xml
settings.gradle.kts               ← include(":app", ":terminal-emulator", ":terminal-view")
```

**빌드 설정 핵심:**

```groovy
// terminal-emulator/build.gradle (Groovy DSL)
apply plugin: 'com.android.library'
android {
    compileSdkVersion 35
    ndkVersion = "28.0.13004108"    // NDK r28 (r21+ 가능)
    namespace = "com.termux.terminal"
    defaultConfig {
        minSdkVersion 24
        externalNativeBuild {
            ndkBuild {
                cFlags "-std=c11", "-Wall", "-Wextra", "-Werror",
                       "-Os", "-fno-stack-protector", "-Wl,--gc-sections"
            }
        }
        ndk { abiFilters 'arm64-v8a' }   // arm64 전용
    }
    externalNativeBuild {
        ndkBuild { path "src/main/jni/Android.mk" }   // CMake 아님
    }
}
```

```makefile
# terminal-emulator/src/main/jni/Android.mk (전체 — 5줄)
LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE:= libtermux
LOCAL_SRC_FILES:= termux.c
include $(BUILD_SHARED_LIBRARY)
```

```groovy
// terminal-view/build.gradle (Groovy DSL)
apply plugin: 'com.android.library'
android {
    compileSdkVersion 35
    namespace = "com.termux.view"
    defaultConfig { minSdkVersion 24 }
}
dependencies {
    api project(":terminal-emulator")     // api — 앱에 transitive 노출
}
```

**`termux.c` JNI 함수 (5개):**

| 함수 | 역할 |
|------|------|
| `createSubprocess()` | PTY master 열기 + `fork()` + `execvp()` → 셸 시작 |
| `setPtyWindowSize()` | 터미널 리사이즈 (`TIOCSWINSZ`) |
| `setPtyUTF8Mode()` | UTF-8 모드 설정 |
| `waitFor()` | 자식 프로세스 종료 대기 |
| `close()` | 파일 디스크립터 닫기 |

**왜 JitPack이 아닌 로컬 소스인가:**
- JitPack 빌드 불안정 (서비스 장애 시 빌드 실패)
- 커스터마이즈 용이 (UI 테마, 키보드 처리 등)
- ReTerminal이 이 방식의 성공 사례 (ReTerminal 소스 = Termux 소스 byte-for-byte 동일)

**라이선스**: Apache 2.0 — 상업적 사용 가능, 포크/수정 가능.

**터미널 라이브러리 대안 비교:**

| 라이브러리 | 출처 | 상태 | PTY | 라이선스 | 비고 |
|-----------|------|------|-----|---------|------|
| **termux/terminal-view** | Termux | ✅ Active | ✅ JNI | Apache 2.0 | 최다 검증. **로컬 소스 모듈로 사용** (ReTerminal 증명) |
| jackpal/AndroidTerm | jackpal | ❌ Archived (2015) | ✅ JNI | Apache 2.0 | Termux의 원조. 더 이상 유지보수 안됨 |
| AidanPark/XTerm.js (WebView) | xterm.js | ✅ Active | ❌ WebSocket | MIT | WebView 기반, 네이티브 PTY 아님. AnyClaw 방식 |
| navasmdc/TerminalView | navasmdc | ⚠️ 소규모 | ❌ 없음 | ? | 순수 UI 컴포넌트, PTY/셸 연동 없음 |

**결론**: `terminal-view`가 유일하게 실전 검증된 Active 선택지. 대안 없음.

### 2.4 프로세스 관리

targetSdk 28에서는 `FOREGROUND_SERVICE_SPECIAL_USE` (Android 14+ API)가 불필요.
일반 Foreground Service + `START_STICKY`로 충분. AnyClaw 동일 방식.

```kotlin
class OpenClawService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }
}
```

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<service
    android:name=".OpenClawService"
    android:exported="false" />
```

**배터리 최적화 예외 요청 (AnyClaw 패턴):**

```kotlin
// 첫 실행 시 배터리 최적화 예외 요청
val pm = getSystemService(POWER_SERVICE) as PowerManager
if (!pm.isIgnoringBatteryOptimizations(packageName)) {
    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
    intent.data = Uri.parse("package:$packageName")
    startActivity(intent)
}
```

### 2.5 DNS 브릿지

**문제**: musl libc로 링크된 바이너리 (예: Codex CLI Rust 바이너리)는 `/etc/resolv.conf`에서 DNS 서버를 읽는다. Android에는 이 파일이 없다.

**해결**: AnyClaw 패턴 — Node.js CONNECT 프록시

```javascript
// proxy.js — 포트 18924
// Node.js는 Android의 Bionic DNS resolver를 사용하므로 DNS 정상 작동
// musl 바이너리는 HTTPS_PROXY=http://localhost:18924 로 경유
const http = require('http');
const net = require('net');

const proxy = http.createServer();
proxy.on('connect', (req, clientSocket) => {
    const [host, port] = req.url.split(':');
    const serverSocket = net.connect(port, host, () => {
        clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
        serverSocket.pipe(clientSocket);
        clientSocket.pipe(serverSocket);
    });
});
proxy.listen(18924);
```

**적용 시점**: musl 바이너리 (AI CLI 도구 일부)를 사용할 때만 필요. Phase 0에서 검증.

### 2.6 WebView UI 아키텍처

**전략: Native Shell + WebView UI**

터미널(terminal-view PTY)만 네이티브로 유지하고, 나머지 모든 UI는 WebView로 구현한다.
APK 재설치 없이 www.zip 교체만으로 UI를 업데이트할 수 있다.

**네이티브 vs WebView 분리:**

| 네이티브 (변경 시 APK 재설치 필요) | WebView (변경 시 www.zip OTA) |
|------|------|
| TerminalView (PTY, libtermux.so) | 셋업 UI (첫 실행 온보딩) |
| OpenClawService (FGS) | 플랫폼 선택기 |
| BootstrapManager (다운로드 + 추출) | 설정 화면 |
| JsBridge (@JavascriptInterface) | 대시보드 |
| | 탭 바 / 네비게이션 |

**WebView UI 파일 구조:**

```
files/usr/share/openclaw-app/www/    ← www.zip으로 업데이트
├── index.html                        ← 엔트리포인트
├── app.js                            ← SPA (React)
├── styles.css
├── setup/                            ← 첫 실행 셋업 UI
├── platforms/                        ← 플랫폼 선택기
├── settings/                         ← 설정 화면
└── dashboard/                        ← 대시보드
```

**JsBridge API 전체 명세 (`@JavascriptInterface`, WebView → Kotlin):**

WebView의 JavaScript에서 `window.OpenClaw.<method>()` 형태로 호출한다. 모든 반환값은 JSON 문자열.
비동기 작업(설치, 명령 실행 등)은 즉시 반환하고 결과를 EventBridge(§2.8)로 전달한다.

| 도메인 | 메서드 | 시그니처 | 반환 | 설명 |
|--------|--------|----------|------|------|
| **Terminal** | `showTerminal` | `()` | void | WebView 숨기고 TerminalView 표시 |
|  | `showWebView` | `()` | void | TerminalView 숨기고 WebView 표시 |
|  | `createSession` | `(): String` | `{id, name}` | 새 터미널 세션 생성 |
|  | `switchSession` | `(id: String)` | void | 해당 세션으로 전환 (`attachSession`) |
|  | `closeSession` | `(id: String)` | void | 세션 종료 |
|  | `getTerminalSessions` | `(): String` | `[{id, name, active}]` | 모든 세션 목록 |
|  | `writeToTerminal` | `(id: String, data: String)` | void | 특정 세션에 입력 전송 |
| **Setup** | `getSetupStatus` | `(): String` | `{bootstrap, runtime, www, platform}` | 전체 셋업 상태 (각 boolean) |
|  | `getBootstrapStatus` | `(): String` | `{installed, version, prefixPath}` | Bootstrap 설치 상태 |
|  | `startSetup` | `()` | void | 셋업 시작 (비동기, EventBridge `setup_progress`) |
| **Platform** | `getAvailablePlatforms` | `(): String` | `[{id, name, icon, desc}]` | config.json 기반 사용 가능 플랫폼 |
|  | `getInstalledPlatforms` | `(): String` | `[{id, name, version}]` | 설치된 플랫폼 |
|  | `installPlatform` | `(id: String)` | void | 플랫폼 설치 (비동기, EventBridge) |
|  | `uninstallPlatform` | `(id: String)` | void | 플랫폼 제거 |
|  | `switchPlatform` | `(id: String)` | void | 활성 플랫폼 전환 |
|  | `getActivePlatform` | `(): String` | `{id, name}` | 현재 활성 플랫폼 |
| **Tools** | `getInstalledTools` | `(): String` | `[{id, name, version}]` | 설치된 추가 도구 |
|  | `installTool` | `(id: String)` | void | 도구 설치 (비동기, EventBridge) |
|  | `uninstallTool` | `(id: String)` | void | 도구 제거 |
|  | `isToolInstalled` | `(id: String): String` | `{installed, version}` | 특정 도구 설치 여부 |
| **Commands** | `runCommand` | `(cmd: String): String` | `{exitCode, stdout, stderr}` | 동기 명령 실행 (짧은 명령, 5초 타임아웃) |
|  | `runCommandAsync` | `(callbackId: String, cmd: String)` | void | 비동기 명령 (EventBridge `command_output`) |
| **Updates** | `checkForUpdates` | `(): String` | `[{component, current, latest, available}]` | 업데이트 확인 |
|  | `applyUpdate` | `(component: String)` | void | 업데이트 적용 ("www", "bootstrap", "scripts") |
| **System** | `getAppInfo` | `(): String` | `{versionName, versionCode, packageName}` | 앱 정보 |
|  | `getBatteryOptimizationStatus` | `(): String` | `{isIgnoring}` | 배터리 최적화 예외 상태 |
|  | `requestBatteryOptimizationExclusion` | `()` | void | 배터리 최적화 예외 요청 다이얼로그 |
|  | `openSystemSettings` | `(page: String)` | void | 시스템 설정 열기 ("battery", "app_info") |
|  | `copyToClipboard` | `(text: String)` | void | 클립보드에 복사 |
|  | `getStorageInfo` | `(): String` | `{totalBytes, freeBytes, bootstrapBytes, wwwBytes}` | 저장 공간 정보 |
|  | `clearCache` | `()` | void | 앱 캐시 삭제 |

**구현 스켈레톤 (Kotlin):**

```kotlin
class JsBridge(
    private val activity: MainActivity,
    private val sessionManager: TerminalSessionManager,
    private val bootstrapManager: BootstrapManager,
    private val eventBridge: EventBridge  // §2.8
) {
    private val gson = Gson()

    // --- Terminal ---
    @JavascriptInterface
    fun showTerminal() = activity.runOnUiThread { activity.showTerminal() }

    @JavascriptInterface
    fun showWebView() = activity.runOnUiThread { activity.showWebView() }

    @JavascriptInterface
    fun createSession(): String {
        val session = sessionManager.createSession()
        return gson.toJson(mapOf("id" to session.id, "name" to session.title))
    }

    @JavascriptInterface
    fun switchSession(id: String) = activity.runOnUiThread {
        sessionManager.switchSession(id)  // TerminalView.attachSession()
    }

    // --- Setup (비동기 — 진행률은 EventBridge로 전달) ---
    @JavascriptInterface
    fun getSetupStatus(): String = gson.toJson(bootstrapManager.getStatus())

    @JavascriptInterface
    fun startSetup() {
        CoroutineScope(Dispatchers.IO).launch {
            bootstrapManager.startSetup { progress, message ->
                eventBridge.emit("setup_progress",
                    mapOf("progress" to progress, "message" to message))
            }
        }
    }

    // --- Commands ---
    @JavascriptInterface
    fun runCommand(cmd: String): String {
        val result = CommandRunner.runSync(cmd, timeoutMs = 5000)
        return gson.toJson(result)  // {exitCode, stdout, stderr}
    }

    @JavascriptInterface
    fun runCommandAsync(callbackId: String, cmd: String) {
        CoroutineScope(Dispatchers.IO).launch {
            CommandRunner.runStreaming(cmd) { output ->
                eventBridge.emit("command_output",
                    mapOf("callbackId" to callbackId, "data" to output))
            }
        }
    }
}
```

**JavaScript (React) 호출:**

```javascript
// 동기 — 즉시 JSON 반환
const sessions = JSON.parse(window.OpenClaw.getTerminalSessions());
const status = JSON.parse(window.OpenClaw.getSetupStatus());

// 비동기 — 결과는 EventBridge 이벤트로 수신 (§2.8 참고)
window.OpenClaw.startSetup();
window.OpenClaw.runCommandAsync("cmd-001", "node -v");
```

**WebView 설정:**

```kotlin
webView.apply {
    settings.javaScriptEnabled = true
    settings.domStorageEnabled = true
    settings.allowFileAccess = true
    addJavascriptInterface(JsBridge(activity), "OpenClaw")
    loadUrl("file:///data/data/${packageName}/files/usr/share/openclaw-app/www/index.html")
}
```

**WebView ↔ TerminalView 전환 패턴:**

```kotlin
class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var terminalView: TerminalView

    fun showTerminal() {
        webView.visibility = View.GONE
        terminalView.visibility = View.VISIBLE
    }

    fun showWebView() {
        terminalView.visibility = View.GONE
        webView.visibility = View.VISIBLE
    }
}
```

### 2.7 OTA 업데이트 아키텍처

**목표: APK 재설치 최소화**

대부분의 변경사항을 런타임 업데이트로 처리하여 사용자의 APK 재설치 부담을 제거한다.

**업데이트 가능 요소:**

| 요소 | 업데이트 방법 | 적용 방식 |
|------|--------------|----------|
| **Web UI** | www.zip 다운로드 → www/ 교체 | `webView.reload()` |
| **Bootstrap** | 새 ZIP 다운로드 → 재추출 | 앱 재시작 |
| **관리 스크립트** | update.sh, platform-manager.sh 교체 | 기존 `oa --update` 재활용 |
| **원격 설정** | config.json 폴링 | 플랫폼 목록, 기능 플래그, bootstrap URL |
| **런타임 패키지** | apt upgrade / npm update | 터미널에서 직접 또는 자동 |

**원격 설정 (config.json):**

```json
{
  "version": 1,
  "bootstrap": {
    "url": "https://github.com/termux/termux-packages/releases/download/...",
    "version": "bootstrap-2026.02.12-r1+apt.android-7",
    "sha256": "..."
  },
  "www": {
    "url": "https://github.com/AidanPark/openclaw-android-app/releases/download/.../www.zip",
    "version": "1.0.0",
    "sha256": "..."
  },
  "platforms": [
    { "id": "openclaw", "name": "OpenClaw", "icon": "🧠", "description": "..." },
    { "id": "moltis", "name": "Moltis", "icon": "⚡", "description": "..." },
    { "id": "zeroclaw", "name": "ZeroClaw", "icon": "🔷", "description": "..." }
  ],
  "features": {
    "dns_proxy": true,
    "elf_patch": false
  }
}
```

**Web UI 업데이트 흐름:**

```kotlin
class WebUIUpdater(private val context: Context) {
    private val wwwDir = File(context.filesDir, "usr/share/openclaw-app/www")

    suspend fun update(url: String, sha256: String) {
        // 1. 다운로드
        val zipFile = downloadFile(url)
        if (sha256(zipFile) != sha256) throw SecurityException("Hash mismatch")

        // 2. staging에 추출
        val staging = File(wwwDir.parentFile, "www-staging")
        unzip(zipFile, staging)

        // 3. atomic 교체
        val backup = File(wwwDir.parentFile, "www-backup")
        wwwDir.renameTo(backup)
        staging.renameTo(wwwDir)
        backup.deleteRecursively()

        // 4. WebView 리로드 (무중단)
        activity.runOnUiThread { webView.reload() }
    }
}
```

**APK 재설치가 필요한 경우 vs 불필요한 경우:**

| APK 재설치 필요 (매우 드물) | APK 재설치 불필요 (OTA) |
|------|------|
| libtermux.so 버그 수정 | UI 변경 (www.zip) |
| 새 JsBridge API 추가 | Bootstrap 업데이트 |
| FGS 로직 변경 | Node.js/git/플랫폼 업데이트 |
| minSdk/targetSdk 변경 | 기능 플래그 변경 |
| | 업데이트 로직 자체 변경 |
| | 관리 스크립트 변경 |
| | 플랫폼 목록/설명 변경 |

### 2.8 EventBridge (Kotlin → WebView 이벤트 전달)

JsBridge(§2.6)는 WebView→Kotlin 방향이다. 반대 방향(Kotlin→WebView) 이벤트 전달에는
`evaluateJavascript` + `CustomEvent` 패턴을 사용한다.

**아키텍처:**

```
Kotlin (EventBridge)                    React (WebView)
────────────────────                    ───────────────
eventBridge.emit(type, data)
  → webView.evaluateJavascript(
      "window.__oc.emit('type', data)"
    )
                                        → window.__oc.emit(type, data)
                                        → dispatchEvent(CustomEvent)
                                        → React useNativeEvent() hook에서 수신
```

**Kotlin 구현:**

```kotlin
class EventBridge(private val webView: WebView) {
    private val gson = Gson()

    fun emit(type: String, data: Any?) {
        val json = gson.toJson(data ?: emptyMap<String, Any>())
        val script = "window.__oc&&window.__oc.emit('$type',$json)"
        webView.post { webView.evaluateJavascript(script, null) }
    }
}
```

**WebView 수신측 초기화 (index.html에 삽입):**

```javascript
window.__oc = {
    emit(type, data) {
        window.dispatchEvent(new CustomEvent(`native:${type}`, { detail: data }));
    }
};
```

**React Hook:**

```typescript
function useNativeEvent<T>(type: string, handler: (data: T) => void) {
    useEffect(() => {
        const listener = (e: CustomEvent<T>) => handler(e.detail);
        window.addEventListener(`native:${type}`, listener as EventListener);
        return () => window.removeEventListener(`native:${type}`, listener as EventListener);
    }, [type, handler]);
}

// 사용 예
function SetupScreen() {
    const [progress, setProgress] = useState(0);
    const [message, setMessage] = useState('');

    useNativeEvent<{progress: number, message: string}>('setup_progress', (data) => {
        setProgress(data.progress);
        setMessage(data.message);
    });

    return <ProgressBar value={progress} label={message} />;
}
```

**이벤트 타입 정의:**

| 이벤트 타입 | 페이로드 | 발생 시점 |
|------------|---------|----------|
| `setup_progress` | `{progress: float, message: string, step: string}` | 첫 실행 셋업 진행 중 |
| `install_progress` | `{target: string, progress: float, message: string}` | 플랫폼/도구 설치 중 |
| `command_output` | `{callbackId: string, data: string, done: boolean}` | `runCommandAsync` 결과 스트리밍 |
| `session_changed` | `{id: string, action: "created"\|"closed"\|"switched"}` | 터미널 세션 변경 |
| `update_available` | `{component: string, currentVersion: string, latestVersion: string}` | 업데이트 감지 |
| `battery_optimization_changed` | `{isIgnoring: boolean}` | 배터리 최적화 상태 변경 |

### 2.9 초기 다운로드 URL 전략

첫 실행 시 Bootstrap, www.zip 등의 다운로드 URL을 어떻게 결정하는지 정의한다.

**원칙: BuildConfig 하드코딩 + config.json 오버라이드**

APK 빌드 시 기본 URL을 `BuildConfig`에 하드코딩하고, 원격 `config.json`으로 동적 오버라이드한다.
네트워크 실패 시에도 하드코딩 URL로 동작을 보장한다.

**BuildConfig 상수 (§9.1 `build.gradle.kts` 참고):**

```kotlin
// app/build.gradle.kts defaultConfig 내
buildConfigField("String", "BOOTSTRAP_URL",
    "\"https://github.com/termux/termux-packages/releases/download/bootstrap-2026.02.12-r1%2Bapt.android-7/bootstrap-aarch64.zip\"")
buildConfigField("String", "WWW_URL",
    "\"https://github.com/AidanPark/openclaw-android-app/releases/download/v1.0.0/www.zip\"")
buildConfigField("String", "CONFIG_URL",
    "\"https://raw.githubusercontent.com/AidanPark/openclaw-android-app/main/config.json\"")
```

**URL 결정 흐름:**

```
앱 시작
  ├─ 캐시된 config.json 있음?
  │   ├─ YES → 캐시 URL 사용
  │   └─ NO  → 원격 config.json fetch (5초 타임아웃)
  │            ├─ 성공 → 원격 URL 사용 + 로컬 캐시 저장
  │            └─ 실패 → BuildConfig 하드코딩 URL 사용 (폴백)
  └─ Bootstrap 설치 완료 후 → config.json을 로컬에 캐시
```

**Kotlin 구현:**

```kotlin
class UrlResolver(private val context: Context) {
    private val configFile = File(
        context.filesDir, "usr/share/openclaw-app/config.json"
    )

    suspend fun getBootstrapUrl(): String {
        val config = loadConfig()
        return config?.bootstrap?.url ?: BuildConfig.BOOTSTRAP_URL
    }

    suspend fun getWwwUrl(): String {
        val config = loadConfig()
        return config?.www?.url ?: BuildConfig.WWW_URL
    }

    private suspend fun loadConfig(): RemoteConfig? {
        // 1. 로컬 캐시 확인
        if (configFile.exists()) {
            return parseConfig(configFile.readText())
        }
        // 2. 원격 fetch (5초 타임아웃)
        return try {
            withTimeout(5000) {
                val json = URL(BuildConfig.CONFIG_URL).readText()
                configFile.parentFile?.mkdirs()
                configFile.writeText(json)  // 캐시 저장
                parseConfig(json)
            }
        } catch (e: Exception) {
            null  // BuildConfig 폴백
        }
    }
}
```

**config.json은 §2.7에 정의된 원격 설정과 동일.** Bootstrap/www URL, 플랫폼 목록, 기능 플래그를 포함하며
OTA 업데이트 URL도 이 설정으로 관리한다.

---

## 3. 사용자 경험 (첫 실행)

```
① APK 설치 (F-Droid / GitHub Releases, **~5MB**)
    ↓
② 앱 실행 → 첫 화면 (WebView UI)
    ┌──────────────────────────────────┐
    │         🧠 OpenClaw              │
    │                                  │
    │    Downloading environment...     │
    │    ████░░░░░░░░░░░░░  25%        │
    │    Downloading bootstrap (1/4)    │
    │                                  │
    └──────────────────────────────────┘
    bootstrap-aarch64.zip 다운로드 (~25MB, 네트워크 의존)
    ↓
    ┌──────────────────────────────────┐
    │    Extracting bootstrap...        │
    │    ████████░░░░░░░░░  45%        │
    │    Extracting files (2/4)         │
    └──────────────────────────────────┘
    ZIP 추출 + fixTermuxPaths + apt 설정 (~30초)
    ↓
    ┌──────────────────────────────────┐
    │    Installing runtime...         │
    │    ████████████░░░░░  65%        │
    │    Downloading Node.js (3/4)     │
    └──────────────────────────────────┘
    apt-get download nodejs-lts npm git + dpkg-deb -x (1-3분, 네트워크 의존)
    ↓
    ┌──────────────────────────────────┐
    │    Downloading Web UI...         │
    │    ███████████████░░  90%        │
    │    Setting up UI (4/4)           │
    └──────────────────────────────────┘
    www.zip 다운로드 + 추출 (~1MB)
    ↓
③ 플랫폼 선택 (WebView UI)
    ┌──────────────────────────────────┐
    │  Select platform:                │
    │                                  │
    │  🧠 OpenClaw                     │
    │  ⚡ Moltis                       │
    │  🔷 ZeroClaw                     │
    │                                  │
    └──────────────────────────────────┘
    선택한 플랫폼 설치 (npm install 등)
    ↓
④ 터미널 Ready
    ┌──────────────────────────────────┐
    │  [Terminal]  [Dashboard]    [⚙]  │  ← WebView 탭 바
    ├──────────────────────────────────┤
    │  $ openclaw onboard              │  ← 네이티브 TerminalView
    │  ...                             │
    │  (플랫폼이 인증/설정 처리)          │
    │                                  │
    ├──────────────────────────────────┤
    │  ⌨ 키보드                         │
    └──────────────────────────────────┘
    - Terminal: 풀 PTY 셸 (네이티브 terminal-view)
    - Dashboard: 플랫폼 Control UI (WebView)
    - ⚙: 설정 (WebView — 추가 도구 설치, PPK 가이드)
```

---

## 4. 파일시스템 레이아웃

targetSdk 28 → `/data/data/` 경로에서 exec 가능. 단일 경로 구조.

```
/data/data/com.openclaw.android/files/              ← 모든 데이터 (exec 가능)
    usr/                                             ← $PREFIX
        bin/                                         ← 실행 파일 (sh, node, git, npm, ...)
        lib/                                         ← 공유 라이브러리, libtermux-exec.so
        etc/                                         ← SSL certs, apt.conf, sources.list
            apt/apt.conf                             ← 재작성 필수 (§2.2.3)
            apt/sources.list                         ← HTTP 다운그레이드 필수 (§2.2.3)
        share/                                       ← terminfo 등
            openclaw-app/                            ← 앱 전용 데이터
                www/                                 ← WebView UI (§2.6)
                    index.html                       ← SPA 엔트리포인트
                    app.js                           ← 메인 JS
                    styles.css
                    setup/                           ← 셋업 UI
                    platforms/                       ← 플랫폼 선택기
                    settings/                        ← 설정
                    dashboard/                       ← 대시보드
                config.json                          ← 원격 설정 캐시 (§2.7)
                scripts/                             ← 관리 스크립트 (OTA)
                    update.sh
                    platform-manager.sh
        var/                                         ← apt 캐시, dpkg 상태
            lib/dpkg/status                          ← fixTermuxPaths 대상 (§2.2.2)
    home/                                            ← $HOME
        .openclaw/                                   ← OpenClaw 데이터
    tmp/                                             ← $TMPDIR
```

**jniLibs 미사용**: targetSdk 28이므로 `files/usr/bin/` 경로의 바이너리가 직접 exec 가능.
별도의 `lib_*.so` 패키징이나 심볼릭 링크 생성이 필요 없음.

---

## 5. AnyClaw과의 차별점

### 5.1 AnyClaw 프로필

| 항목 | 값 |
|------|---|
| 레포 | `friuns2/openclaw-android-assistant` |
| Stars | 58 |
| Play Store | 10K+ 다운로드, 평점 4.2 |
| Contributors | 2명 (bus factor 위험) |
| 기술 스택 | Kotlin + WebView (Vue.js), Termux bootstrap |
| 지원 프로바이더 | OpenAI 전용 |
| 터미널 | ❌ 없음 — WebView 채팅 인터페이스만 제공 |

### 5.2 알려진 이슈

| 이슈 | 내용 | 우리의 대응 |
|------|------|-----------|
| **#1: 터미널 없음** | 사용자가 shell 명령을 직접 실행할 수 없음. 채팅으로만 상호작용 | ✅ 풀 PTY 터미널 제공 |
| **#2: 파일시스템 도구 미지원** | file system tool이 없어 파일 조작 불가 | ✅ 터미널에서 모든 파일 조작 가능 |

### 5.3 보안 우려

AnyClaw는 `danger-full-access`를 기본값으로 사용. 이는 LLM에게 시스템 전체 접근 권한을 부여하며,
사용자가 인지하지 못한 채 민감한 조작이 발생할 수 있다. 우리는 **플랫폼 온보딩에서 사용자가 직접 권한을 선택**하도록 한다.

### 5.4 비교표

| 항목 | AnyClaw | 우리 |
|------|---------|------|
| 터미널 | ❌ WebView 전용 (Issue #1) | ✅ **풀 PTY 터미널** |
| AI 프로바이더 | OpenAI 전용 | ✅ **모든 프로바이더** (Claude, Gemini, 로컬 LLM) |
| 플랫폼 | OpenClaw + Codex | ✅ **OpenClaw, Moltis, ZeroClaw 등 선택** |
| AI CLI 도구 | Codex CLI만 | ✅ **Claude Code, Gemini CLI, Codex CLI 전부** |
| 셸 접근 | ❌ 불가 (Issue #2) | ✅ git, npm, 스크립트 실행 가능 |
| 보안 | danger-full-access 기본값 | ✅ 사용자 선택 가능 |
| UI | WebView (Vue.js) | Terminal + Dashboard (WebView) 탭 전환 |
| bus factor | 2 contributors | — (프로젝트 초기) |
| 배포 | Play Store 10K+ DL | F-Droid + GitHub Releases |

---

## 6. 경쟁 환경

| 프로젝트 | Stars | 접근 방식 | 터미널 | 멀티 프로바이더 | 상태 |
|---------|-------|----------|--------|---------------|------|
| **openclaw-android (우리, CLI)** | 238 | Termux + glibc-runner | ✅ (Termux) | ✅ | 배포 중 (v1.0.4) |
| **AnyClaw** | 58 | 독립 APK + WebView | ❌ | ❌ (OpenAI) | Play Store |
| **openclaw-termux** | 322 | Flutter + Termux | ✅ | ? | 12 릴리즈 |
| **ZeroClaw-Android** | 176 | Kotlin + Rust (네이티브) | ✅ | ✅ (25+) | 27 릴리즈 |
| **우리 APK (계획)** | — | Thin APK (~5MB) + WebView UI + OTA | ✅ | ✅ | Phase 0 |

**시사점**: 시장 진입 속도가 중요. 런타임 순수성보다 빠른 출시 우선.

---

## 7. 개발 로드맵

### Phase 0: PoC 검증 (1-2주)

핵심 가정을 검증하는 최소 APK. Bootstrap은 이 단계에서만 assets에 포함 (PoC 검증 목적).

- [ ] Android 프로젝트 생성 (Kotlin, Gradle, **targetSdk 28, minSdk 24**)
- [ ] terminal-view **로컬 소스 모듈** 통합 (Groovy DSL `build.gradle`, ndkBuild)
- [ ] NDK 빌드: `termux.c` → `libtermux.so` (Android.mk, 5줄)
- [ ] Termux 공식 bootstrap ZIP (`download-bootstrap.sh`) → assets에 포함 (PoC만)
- [ ] Bootstrap Installer: ZIP 추출 → staging → atomic rename
- [ ] **fixTermuxPaths**: SYMLINKS.txt 실시간 치환 + dpkg status/info 텍스트 치환
- [ ] **apt 설정**: `apt.conf` 재작성 + `sources.list` HTTP 다운그레이드
- [ ] **libtermux-exec.so 설정**: 변형 확인 + `TERMUX__PREFIX` 환경변수 동작 검증
- [ ] 환경 구성: `ProcessBuilder` + `environment().clear()` + 전체 환경변수 (§2.2.5)
- [ ] `sh` 실행 → 터미널에서 명령어 동작 확인
- [ ] Node.js/git 설치: `apt-get download` + `dpkg-deb -x` → `node -v`, `git --version` 확인
- [ ] `child_process.spawn('git')` 작동 확인
- [ ] Foreground Service (일반 START_STICKY) 프로세스 유지 테스트
- [ ] DNS 해석 테스트 (musl 바이너리 필요 여부 판단)
- [ ] `SSL_CERT_FILE` 환경변수로 HTTPS apt 가능 여부 확인 (HTTP 다운그레이드 대안)

**Phase 0 산출물**: PoC APK — 터미널에서 `node -v` + `git --version` + `child_process` 작동

### Phase 1: MVP + Thin APK + WebView UI (3-4주)

- [ ] **Bootstrap 런타임 다운로드**: assets 번들 → BootstrapManager로 네트워크 다운로드 + 진행률 UI
- [ ] **WebView UI 구현**: www/ 디렉토리 구조, React SPA 프레임워크
- [ ] **JsBridge 구현**: @JavascriptInterface — 터미널 제어, 플랫폼 관리, 명령 실행, 업데이트 제어
- [ ] **WebView ↔ TerminalView 전환**: 탭 바 탐색, 네이티브 PTY + WebView UI 공존
- [ ] **멀티 터미널 세션**: TerminalSessionManager (createSession/switchSession/removeSession), 세션 탭 바 UI, `TerminalView.attachSession()` API 기반 세션 전환
- [ ] Platform Selector (WebView): 플랫폼 선택 UI + 플랫폼 설치 자동화
- [ ] 기존 platform-plugin 아키텍처 (`platforms/<name>/`) 통합
- [ ] `openclaw onboard` → `openclaw gateway` 풀 플로우 동작
- [ ] 셋업 UI (WebView): 첫 실행 온보딩 흐름 (다운로드 → 추출 → 런타임 설치 → 플랫폼 선택)
- [ ] 설정 화면 (WebView): 추가 도구 설치, PPK 가이드 링크

**Phase 1 산출물**: 설치 가능한 Thin APK (~5MB) — 플랫폼 선택 → 온보딩 → 게이트웨이 실행

### Phase 2: OTA 업데이트 + 안정화 + 배포 (2-3주)

- [ ] **www.zip OTA 업데이트**: WebUIUpdater — 다운로드 + staging + atomic 교체 + 리로드
- [ ] **Bootstrap OTA 업데이트**: 새 ZIP 다운로드 + 재추출
- [ ] **원격 설정**: config.json 폴링 (플랫폼 목록, 기능 플래그, bootstrap/www URL)
- [ ] **관리 스크립트 OTA**: update.sh, platform-manager.sh 자동 교체
- [ ] 에러 핸들링 + 크래시 리포팅
- [ ] GitHub Releases APK 자동 빌드 (CI/CD)
- [ ] www.zip CI/CD 빌드 파이프라인
- [ ] F-Droid 메타데이터 준비
- [ ] 테스트 기기 매트릭스 검증 (Android 10-15)
- [ ] ELF 바이너리 패치 (make, cmake 등 BUILD-ONLY 도구)

### Phase 3: 최적화 (선택)

- [ ] delta 업데이트 (www.zip, bootstrap 패치만 다운로드)
- [ ] 오프라인 모드: bootstrap 내장 옵션 (APK ~30MB 변형)
- [ ] WebView 성능 최적화 (Service Worker 캐싱, 레이지 로딩)

---

## 8. 리스크 및 미검증 사항

### 🔴 미검증 — Phase 0에서 반드시 확인

| # | 가정 | 검증 방법 | 실패 시 대안 |
|---|------|----------|-------------|
| V1 | targetSdk 28에서 `files/usr/bin/` 바이너리가 exec 가능 | 빈 APK에서 bootstrap 추출 후 `sh` 실행 | jniLibs 패키징으로 전환 (Oracle 초기 권고 방식) |
| V2 | Termux bootstrap의 Node.js가 APK 데이터 디렉토리에서 정상 작동 | `node -v` + 간단한 JS 실행 | 공식 Node.js + glibc-runner 폴백 |
| V3 | terminal-view 로컬 소스 모듈이 독립 앱에서 빌드·동작 | 모듈 생성 후 ndkBuild + PTY 실행 | JitPack 폴백 (`com.github.termux:terminal-view`) |
| V4 | DNS 해석이 Termux bootstrap 환경에서 작동 | `curl https://example.com` 실행 | DNS 브릿지 프록시 구현 |
| V5 | `apt-get download` + `dpkg-deb -x`로 설치한 패키지가 정상 작동 | Node.js, git 설치 후 기본 명령 실행 | bootstrap ZIP에 직접 번들 |
| V6 | `apt.conf` 재작성 + HTTP 다운그레이드로 apt가 작동 | `apt-get update` + `apt-get download` 실행 | `SSL_CERT_FILE` 환경변수로 HTTPS 시도 |
| V7 | `libtermux-exec.so`가 `TERMUX__PREFIX` 환경변수로 정상 동작 | 경로 변환 확인 (`/bin/sh` → `$PREFIX/bin/sh`) | bootstrap 내 setup 스크립트 실행 또는 direct 변형 직접 지정 |

### 🟡 알려진 리스크 — 완화 방안 있음

| 리스크 | 영향 | 완화 방안 |
|--------|------|----------|
| Phantom Process Killer (Android 12+) | 백그라운드 프로세스 종료 | Foreground Service + ADB 가이드 (앱 내 완전 해결 불가) |
| **첫 실행 시 네트워크 필수** (~25MB bootstrap + ~100MB 런타임) | 오프라인 첫 실행 불가, 사용자 이탈 | 진행률 UI + 단계별 가이드. Phase 3에서 오프라인 모드 검토 |
| 첫 실행 3-5분 대기 (다운로드 + 추출 + 런타임 설치) | 사용자 이탈 | 단계별 진행률 (4단계) + "커피 한 잔" 가이드 |
| Bootstrap 다운로드 실패 시 복구 불가 | 첫 실행 실패 | 재시도 UI + CDN 폴백 URL |
| openclaw-termux (322 stars) 경쟁 | 시장 선점 | 빠른 출시 + 터미널+멀티플랫폼 차별화 |
| targetSdk 28의 Google Play 제약 | Play Store 게시 불가 | F-Droid + GitHub Releases 전용 (Play Store 미게시 확정) |
| `libgnutls.so` 인증서 경로 하드코딩 | apt HTTPS 실패 | HTTP 다운그레이드 (AnyClaw 방식) 또는 `SSL_CERT_FILE` 환경변수 |
| ELF 바이너리 내 하드코딩된 shell 경로 | `make`, `cmake` 등 실행 실패 | 바이너리 바이트 패치 (null-padding). Phase 0에서는 불필요 (BUILD-ONLY) |
| `dpkg postinst` 스크립트의 경로 문제 | `apt-get install` 시 postinst 실패 가능 | `apt-get download` + `dpkg-deb -x`로 postinst 우회 (AnyClaw 방식) |
| WebView JavaScript 인젝션 | 악의적 웹 컨텐츠 실행 | 로컬 파일만 로드 (`file:///`), 원격 URL 차단, CSP 헤더 |
| www.zip 다운로드 실패 | UI 업데이트 불가 | SHA256 검증 + 백업 유지 + 롤백 |
| config.json 위변조 | 악의적 설정 배포 | HTTPS 전송 + 무결성 검증 (SHA256) |

### 🟢 확인된 사항 — 추가 검증 불필요

| 사항 | 근거 |
|------|------|
| Termux bootstrap이 APK 안에서 작동 | AnyClaw (Play Store, 10K+ 다운로드, targetSdk 28) |
| terminal-view가 독립 앱에 통합 가능 | ReTerminal (Material 3 터미널 앱, 로컬 소스 모듈, byte-for-byte 동일) |
| terminal-view ndkBuild 설정 | Android.mk 5줄 + termux.c 1개 파일. NDK r21+ 작동. ReTerminal에서 검증 |
| terminal-view 모듈은 Groovy DSL | `.build.gradle` (`.kts` 아님). 앱 모듈과 혼용 가능. ReTerminal 동일 구조 |
| Foreground Service로 프로세스 유지 | Termux, UserLAnd, AnyClaw 모두 동일 방식 |
| Apache 2.0으로 terminal-view 사용 가능 | Termux 라이선스 확인 완료 |
| GPL v3 수용, 소스 전부 공개 | APK 레포 GPL v3. Termux 패키지(GPL) 번들 의무 충족 |
| Play Store 미게시 → targetSdk 제약 없음 | F-Droid + GitHub Releases 배포. targetSdk 28 사용 가능 |
| `ProcessBuilder` + `environment().clear()` 패턴 | AnyClaw `CodexServerManager.kt`에서 증명 (SHA: ef189176) |
| `libtermux-exec.so`는 재컴파일 불필요 | `TERMUX__PREFIX` 환경변수로 런타임 설정. 환경변수 없으면 `com.termux` fallback |
| fixTermuxPaths 범위 확인 | 텍스트(SYMLINKS.txt, dpkg, git shebang) + ELF(make, cmake) 바이트 패치. AnyClaw 구현 확인 |
| apt.conf 재작성 + HTTP 다운그레이드 패턴 | AnyClaw `BootstrapInstaller.kt` L180-214에서 구현 확인 |
| `apt-android-7` bootstrap은 minSdk 24 필요 | Termux 공식 — API 24+ 바이너리, `DT_RUNPATH` 사용 |
| Gradle 9.x + AGP 8.x에서 targetSdk 28 + NDK 빌드 호환 | ReTerminal Fdroid flavor에서 검증됨 |

| WebView 기반 UI로 앱 수준의 품질 가능 | React + CSS 애니메이션으로 네이티브 수준 UX 달성 가능 |
| @JavascriptInterface로 WebView↔Kotlin 브릿지 가능 | Android 공식 API. 안정적이며 다수 앱에서 사용 |
| OTA 업데이트 패턴 검증됨 | 기존 CLI 프로젝트의 `oa --update` 셀 스크립트 방식과 동일 컴셋. www.zip은 추가 레이어 |
---

## 9. 기존 프로젝트와의 관계

```
openclaw-android/                    ← 현재 레포 (CLI, Termux 기반)
├── Termux + glibc-runner 방식       ← 계속 유지, v1.0.4
├── .agent/plan/01-core/01-standalone-apk.md    ← 초기 조사 문서 (아카이브)
└── .agent/plan/01-core/02-standalone-apk-option-d.md  ← 본 문서

openclaw-android-app/                ← 새 레포 (APK, Phase 0에서 생성)
├── app/                             ← Kotlin Android 프로젝트
│   └── src/main/java/com/openclaw/android/
│       ├── MainActivity.kt          ← WebView + TerminalView 컨테이너
│       ├── OpenClawService.kt       ← FGS
│       ├── BootstrapManager.kt      ← 다운로드 + 추출
│       ├── JsBridge.kt              ← @JavascriptInterface
│       └── WebUIUpdater.kt          ← www.zip OTA
├── terminal-emulator/               ← Termux 소스 (로컬 모듈, Groovy DSL)
│   └── src/main/jni/termux.c        ← NDK 빌드 (Android.mk)
├── terminal-view/                   ← Termux 소스 (로컬 모듈, Groovy DSL)
├── www/                             ← WebView UI 소스 (www.zip으로 빌드)
│   ├── index.html
│   ├── app.js                       ← SPA (React)
│   ├── styles.css
│   ├── setup/                       ← 셋업 UI
│   ├── platforms/                   ← 플랫폼 선택기
│   ├── settings/                    ← 설정
│   └── dashboard/                   ← 대시보드
├── scripts/
│   └── download-bootstrap.sh        ← Termux 공식 bootstrap 다운로드
└── .github/workflows/               ← CI/CD (APK 빌드 + www.zip 빌드 + 릴리즈)
```

**공유 자산:**
- `platforms/` 플러그인 구조 — APK 프로젝트에서도 동일한 `config.env` + `install.sh` 사용 가능
- `patches/` — glibc-compat.js, argon2-stub.js (Termux bootstrap 환경에서도 필요할 수 있음)

**독립 유지:**
- APK 코드 (Kotlin, Gradle) → 별도 레포
- Bootstrap 소스 → `download-bootstrap.sh`로 Termux 공식 릴리스에서 다운로드
- 배포 채널 분리 (CLI: curl 설치, APK: F-Droid/GitHub Releases)

### 9.1 app 모듈 빌드 설정 (`build.gradle.kts`)

**gradle/libs.versions.toml (버전 카탈로그):**

```toml
[versions]
agp = "8.13.1"
kotlin = "2.2.21"
coreKtx = "1.17.0"
appcompat = "1.7.1"
material = "1.13.0"
constraintlayout = "2.2.1"
lifecycleRuntimeKtx = "2.10.0"
kotlinxCoroutines = "1.10.2"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
androidx-appcompat = { group = "androidx.appcompat", name = "appcompat", version.ref = "appcompat" }
material = { group = "com.google.android.material", name = "material", version.ref = "material" }
androidx-constraintlayout = { group = "androidx.constraintlayout", name = "constraintlayout", version.ref = "constraintlayout" }
androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycleRuntimeKtx" }
kotlinx-coroutines-android = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "kotlinxCoroutines" }
gson = { module = "com.google.code.gson:gson", version = "2.12.1" }

[plugins]
androidApplication = { id = "com.android.application", version.ref = "agp" }
kotlinAndroid = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
```

**app/build.gradle.kts:**

```kotlin
plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.kotlinAndroid)
}

android {
    namespace = "com.openclaw.android"
    compileSdk = 36

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    defaultConfig {
        applicationId = "com.openclaw.android"
        minSdk = 24
        //noinspection ExpiredTargetSdkVersion
        targetSdk = 28
        versionCode = 1
        versionName = "1.0.0"

        ndk { abiFilters += listOf("arm64-v8a") }

        // 초기 다운로드 URL (§2.9)
        buildConfigField("String", "BOOTSTRAP_URL",
            "\"https://github.com/termux/termux-packages/releases/download/bootstrap-2026.02.12-r1%2Bapt.android-7/bootstrap-aarch64.zip\"")
        buildConfigField("String", "WWW_URL",
            "\"https://github.com/AidanPark/openclaw-android-app/releases/download/v1.0.0/www.zip\"")
        buildConfigField("String", "CONFIG_URL",
            "\"https://raw.githubusercontent.com/AidanPark/openclaw-android-app/main/config.json\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-DEBUG"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    packaging {
        jniLibs { useLegacyPackaging = true }
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

dependencies {
    implementation(project(":terminal-emulator"))
    implementation(project(":terminal-view"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.gson)
    // WebView + @JavascriptInterface — Android SDK 기본 포함, 추가 의존성 불필요
}
```

**settings.gradle.kts:**

```kotlin
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "openclaw-android-app"
include(":app", ":terminal-emulator", ":terminal-view")
```

**gradle/wrapper/gradle-wrapper.properties:**

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-bin.zip
```

**호환성 (2026년 3월 기준):**

| 구성요소 | 버전 | 비고 |
|---------|------|------|
| Gradle | 9.3.1 | AGP 8.13.x 호환 |
| AGP | 8.13.1 | Stable, targetSdk 28 정상 지원 |
| JDK | 17 | AGP 8.x 필수 |
| NDK | 28.2.13676358 | AGP 9.x 기본값 (r21+ 호환) |
| Kotlin | 2.2.21 | Stable |

> **terminal-emulator, terminal-view 모듈**은 Groovy DSL(`.build.gradle`)을 유지한다(§2.3). 앱 모듈만 Kotlin DSL.

---

## 10. 참고 자료

### 선행 프로젝트
- **AnyClaw**: `friuns2/openclaw-android-assistant` (SHA: `ef189176`) — 가장 직접적인 참고 (독립 APK, Termux bootstrap, targetSdk 28)
  - `scripts/download-bootstrap.sh` — Termux 공식 릴리스 다운로드 (`bootstrap-2026.02.12-r1+apt.android-7`)
  - `BootstrapInstaller.kt` — ZipInputStream → staging → atomic rename → fixTermuxPaths
    - **fixTermuxPaths**: SYMLINKS.txt 실시간 치환 + dpkg status/info 텍스트 치환
    - **apt.conf 재작성**: `Dir "/";` + 모든 경로를 실제 prefix로 명시 (L180-199)
    - **sources.list**: HTTPS→HTTP 다운그레이드 + `com.termux`→자신의 패키지명 (L206-214)
    - **ELF 바이너리 패치**: make/cmake의 shell 경로를 null-padding으로 치환 (L432-455)
  - `CodexServerManager.kt` — `buildEnvironment()`: 전체 환경변수 설정
    - `LD_PRELOAD`, `TERMUX__PREFIX`, `APT_CONFIG`, `DPKG_ADMINDIR` 등
  - Node.js 설치: `apt-get download nodejs-lts npm` + `dpkg-deb -x` (postinst 미실행)
  - DNS 프록시: `proxy.js` (CONNECT 프록시, 포트 18924) — musl 바이너리 전용
- **ReTerminal**: `RohitKushvaha01/ReTerminal` (SHA: `9d2d8939`) — terminal-view 로컬 소스 모듈 사용 사례 (Material 3)
  - `terminal-emulator/` + `terminal-view/` 디렉토리 구조 (Groovy DSL)
  - NDK 빌드: `Android.mk` (5줄) + `termux.c` (5개 JNI 함수) → `libtermux.so`
  - ndkVersion = `28.0.13004108`, Gradle 9.2.1, AGP 8.13.1
  - Jetpack Compose `AndroidView { TerminalView(...) }` 패턴
  - Fdroid flavor: `targetSdk = 28` (우리와 동일)
- **node-on-android-demo**: `siepra/node-on-android-demo` — Node.js APK 경량 레퍼런스

### Termux Bootstrap 생성
- **termux/termux-packages** — `generate-bootstraps.sh`: apt repo에서 .deb 다운로드 → ar x → tar xf → rootfs 추출
- 심볼릭 링크: `SYMLINKS.txt`에 `target←linkpath` 형식으로 분리 저장
- CI: 매주 일요일 자동 빌드, GitHub Releases에 게시
- 릴리즈 태그: `bootstrap-2026.03.01-r1+apt.android-7`
- `termux-exec` 패키지: `TERMUX_PKG_ESSENTIAL=true` — bootstrap에 항상 포함

### Termux-exec (경로 변환 라이브러리)
- **termux/termux-exec-package** (SHA: `4606100`) — libtermux-exec.so 소스
  - `TERMUX__PREFIX` 환경변수로 런타임 경로 설정 (재컴파일 불필요)
  - 두 변형: `direct-ld-preload` (Android <10), `linker-ld-preload` (Android 10+)
  - `termux-exec-ld-preload-lib setup` 스크립트로 적절한 변형 선택

### Android 플랫폼
- **Termux**: `termux/termux-app` (SHA: `3f0dec3`) — JNI PTY, Foreground Service, targetSdk 28 구현 참고
  - `apt-android-7` bootstrap: API 24+ 전용, `DT_RUNPATH` 사용, busybox 불필요
  - `apt-android-5` bootstrap: API 21+ (Android 5/6), busybox 기반 — 우리는 미사용
- **Chaquopy**: `chaquo/chaquopy` — JNI 임베딩 패턴 참고

### 기술 문서
- W^X SELinux 정책: `android-review.googlesource.com/c/platform/system/sepolicy/+/804149`
- targetSdk 28과 exec 정책: targetSdk ≤ 28이면 `/data/data/` 경로에서 exec 가능 (W^X 미적용)
- Foreground Service: 일반 `START_STICKY` (targetSdk 28에서 specialUse 불필요)
- 16KB page alignment: Android 15+ Play Store 요구사항 (2025.11~) — Play Store 미게시이므로 해당 없음
- terminal-view 소스: `github.com/termux/termux-app` (terminal-emulator, terminal-view)

### 경쟁 프로젝트
- **openclaw-termux**: 322 stars, Flutter + Termux, 12 releases — 시장 선점 경쟁자
- **ZeroClaw-Android**: 176 stars, Kotlin + Rust (네이티브), 25+ 프로바이더, 27 releases

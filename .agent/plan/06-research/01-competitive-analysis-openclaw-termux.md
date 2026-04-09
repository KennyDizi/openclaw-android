# 경쟁 분석: openclaw-termux (mithun50)

> 작성일: 2026-03-07
> 상태: Final
> 목적: openclaw-termux 프로젝트의 기술 아키텍처를 분석하고, 우리 계획과의 차별성을 평가한다.

---

## 1. 프로젝트 프로필

| 항목 | 값 |
|------|---|
| 저장소 | https://github.com/mithun50/openclaw-termux |
| Stars / Forks | 416 / 70 (2026-03-07 기준) |
| 버전 / 릴리즈 | v1.8.3, 14개 릴리즈, 181 커밋 |
| 기술 스택 | Flutter (Dart 64%) + Kotlin (29%) + proot-distro + Ubuntu |
| 배포 방식 | APK (GitHub Releases) + npm CLI (`openclaw-termux`) |
| 라이선스 | MIT |
| 개발자 | Mithun Gowda B (NextGenX) |

---

## 2. 핵심 아키텍처

### 런타임 스택

```
Android APK (Flutter)
  → proot-distro → Ubuntu 24.04 (arm64)
    → Node.js 22 (nodesource)
      → OpenClaw Gateway (localhost:18789)
```

- **proot-distro**: 전체 Ubuntu 배포판을 proot 위에서 실행 (~500MB)
- **성능 오버헤드**: ptrace 기반 syscall 인터셉트로 5-30% 성능 저하
- **APK 크기**: Flutter 앱 (추정 30-50MB+)

### Flutter 앱 구성

| 구성 요소 | 기술 |
|-----------|------|
| 터미널 에뮬레이터 | `xterm` + `flutter_pty` 패키지 |
| 대시보드 | `webview_flutter` (WebView) |
| 게이트웨이 관리 | Kotlin Foreground Service |
| Node 연동 | WebSocket (`web_socket_channel`) |
| 인증 | Ed25519 (`cryptography` 패키지) |

### Kotlin 네이티브 (MethodChannel)

`MainActivity.kt`에서 Flutter ↔ Android 네이티브 브릿지 담당:

| Kotlin 파일 | 역할 |
|-------------|------|
| `BootstrapManager.kt` | rootfs 추출, Node.js 설치, 디렉토리 관리 |
| `ProcessManager.kt` | proot 명령 실행 (`runInProotSync`) |
| `GatewayService.kt` | OpenClaw 게이트웨이 Foreground Service |
| `NodeForegroundService.kt` | Node 연결 유지 Foreground Service |
| `ScreenCaptureService.kt` | MediaProjection 화면 녹화 |
| `TerminalSessionService.kt` | 터미널 세션 유지 |
| `SshForegroundService.kt` | SSH 서버 관리 |

---

## 3. 디바이스 연동 아키텍처 (Node Protocol)

### 원리

OpenClaw Gateway에 내장된 **Node Protocol v3** (WebSocket)을 활용한다.
Flutter 앱이 "node"로 등록하여 Android 하드웨어를 AI에 노출한다.

### 전체 Flow

```
① 사용자: "사진 찍어줘"
② LLM → tool_call: camera.snap
③ OpenClaw Gateway → WebSocket → node.invoke.request
④ Flutter App (NodeWsService) → JSON 디코딩 → NodeFrame
⑤ NodeService → command 라우팅 → CameraCapability 핸들러
⑥ CapabilityHandler → Android 권한 확인 (permission_handler)
⑦-A Flutter 플러그인 경로: camera/geolocator 패키지 → Android Camera2/LocationManager
⑦-B Kotlin 네이티브 경로: MethodChannel → SensorManager/Vibrator/MediaProjection
⑧ 결과 (base64 등) → WebSocket → Gateway → LLM
⑨ LLM → 사용자 응답: "책상 위에 노트북이 보입니다"
```

### 구현 패턴 3가지

**① Flutter 플러그인 직접 사용 (Dart 레벨)**

| Capability | 플러그인 | 명령 |
|-----------|---------|------|
| Camera | `camera` (Google/Flutter 팀) | snap, clip, list |
| Flash | `camera` (torch 모드) | on, off, toggle, status |
| Location | `geolocator` (Baseflow) | get |

**② Kotlin 네이티브 브릿지 (MethodChannel)**

| Capability | Android API | 명령 |
|-----------|------------|------|
| Sensor | `SensorManager` | read, list |
| Haptic | `Vibrator` / `VibratorManager` | vibrate |
| Screen | `MediaProjection` | record |

**③ 미구현 (스텁)**

| Capability | 상태 |
|-----------|------|
| Canvas | NOT_IMPLEMENTED 응답만 반환 |

### 연결 안정성 관리

| 메커니즘 | 설명 |
|---------|------|
| Exponential backoff | 재연결 대기 (350ms × 1.7^n, 최대 8초) |
| 30초 ping | WebSocket keepalive |
| 45초 watchdog | 연결 상태 감시, 자동 재연결 |
| 90초 stale 감지 | 데이터 수신 없으면 강제 재연결 |
| Foreground Service | 백그라운드 프로세스 유지 |
| 앱 resume 처리 | stale 체크 + 서비스 alive 확인 |

### 게이트웨이 설정 패칭

게이트웨이 시작 전 `openclaw.json`에 Node.js 원라이너로 `allowCommands` 주입:

```json
{
  "gateway": {
    "nodes": {
      "denyCommands": [],
      "allowCommands": [
        "camera.snap", "camera.clip", "camera.list",
        "flash.on", "flash.off", "flash.toggle", "flash.status",
        "location.get", "screen.record",
        "sensor.read", "sensor.list",
        "haptic.vibrate",
        "canvas.navigate", "canvas.eval", "canvas.snapshot"
      ]
    }
  }
}
```

### 인증 흐름

1. 앱 최초 실행 → Ed25519 키쌍 생성 (SharedPreferences 저장)
2. deviceId = SHA-256(public key)
3. Gateway WebSocket 연결 → challenge nonce 수신
4. 서명 payload: `"v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce"`
5. Ed25519 서명 → connect 프레임 전송 (caps/commands 포함)
6. 로컬 연결 시 페어링 자동 승인: `openclaw nodes approve <code>`

---

## 4. 우리 계획과의 비교

### 핵심 기술 차이

| 항목 | openclaw-termux | 우리 계획 (Thin APK) |
|------|----------------|---------------------|
| 런타임 | proot-distro + Ubuntu (~500MB) | Termux bootstrap 직접 추출 (~200MB) |
| 성능 | proot 오버헤드 5-30% | 네이티브 속도 |
| APK 크기 | Flutter APK (30-50MB+) | ~5MB (런타임 다운로드) |
| exec 방식 | proot execve 인터셉트 | targetSdk 28 → 직접 exec |
| 터미널 | Flutter xterm + flutter_pty | terminal-view (Termux PTY) |
| UI | Flutter 네이티브 | Kotlin + WebView (OTA 가능) |
| 업데이트 | APK 재설치 | OTA (www.zip, bootstrap, 스크립트) |
| 멀티 플랫폼 | ❌ OpenClaw 전용 | ✅ platform-plugin 아키텍처 |
| 디바이스 연동 | ✅ 7종 (카메라, GPS, 센서 등) | ❌ 미계획 |
| SSH 관리 | ✅ 내장 | ❌ 미계획 |

### 우리가 우위인 부분

1. **런타임 아키텍처**: proot 없이 네이티브 실행 → 성능, 용량, 안정성 우위
2. **OTA 업데이트**: UI 변경에 APK 릴리즈 불필요
3. **멀티 플랫폼**: OpenClaw 외 Moltis 등 확장 가능
4. **APK 크기**: ~5MB vs 30-50MB+

### 우리가 열위인 부분

1. **시장 선점**: 이미 v1.8.3, 416 stars, 14 릴리즈
2. **디바이스 기능 통합**: 7종 하드웨어 capability (우리 계획에 없음)
3. **UI 완성도**: Flutter 네이티브 UI 대시보드
4. **앱 내 AI 프로바이더 설정**: 7개 프로바이더 API 키 설정 UI

### 우리에게 적용 가능한 점

- **디바이스 연동**: OpenClaw Node Protocol은 공식 프로토콜이므로 Kotlin + OkHttp WebSocket으로 동일 구현 가능. Phase 3+ 검토 대상.
- **Stars 성장세**: 계획 문서 작성 시점(3/5) 322 → 분석 시점(3/7) 416. 속도 경쟁에서 뒤처지지 않도록 Phase 0 착수 서두를 필요.

---

## 5. 참고사항

- 분석 대상 커밋: main 브랜치 (2026-03-07 기준)
- Stars 수는 조사 시점 기준이며, 급격히 증가 중
- 경쟁 환경 테이블(`01-core/02-standalone-apk-option-d.md` §6)의 openclaw-termux stars 수 업데이트 필요 (322 → 416)

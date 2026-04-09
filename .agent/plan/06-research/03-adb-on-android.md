# ADB 활용 분석: Termux 환경에서의 가능성과 한계

> 작성일: 2026-03-07
> 상태: Final
> 목적: Termux에서 adb를 설치하고 사용할 때의 기술적 가능성, 제약사항, AI 에이전트 연동 시나리오를 정리한다.

---

## 1. 현재 상태

우리 프로젝트에서 adb (`android-tools`)는 **선택적 도구(L3)**로 포함되어 있다.

| 파일 | 역할 |
|------|------|
| `install.sh` | 최초 설치 시 `"Install android-tools (adb)?"` Y/n 프롬프트 |
| `install-tools.sh` | 사후 설치 (`oa --install`)에서 동일 제공 |

자동 설치가 아니라 사용자 선택 시에만 설치된다.
주요 용도: Phantom Process Killer 비활성화 가이드에서 adb 명령 필요.

---

## 2. Termux에서 adb 사용 조건

### 자기 자신 폰 제어 (비루트)

Termux는 일반 앱이므로, 같은 기기의 시스템 레벨에 접근하려면 **무선 디버깅**을 통해 adb 프로토콜로 연결해야 한다.

**설정 절차:**

```
1. 설정 → 개발자 옵션 → 무선 디버깅 ON
2. "페어링 코드로 기기 페어링" 탭
   → 페어링 코드 (6자리)와 페어링 포트 표시
3. Termux에서:
   adb pair localhost:<페어링포트> <페어링코드>
   adb connect localhost:<연결포트>
   (연결 포트는 무선 디버깅 메인 화면에 표시. 페어링 포트와 다름)
4. adb devices → "localhost:<포트> device" 확인
```

**통신 경로:**

```
Termux (adb client) → localhost (루프백) → adbd (같은 폰 시스템 레벨)
```

- 외부 네트워크 불필요 (루프백 통신)
- Wi-Fi, 데이터가 꺼져 있어도 루프백 자체는 동작

### 핵심 제약: Wi-Fi 의존성

| 상황 | 무선 디버깅 | adb 사용 |
|------|-----------|---------|
| Wi-Fi ON | ✅ 활성화 | ✅ 가능 |
| Wi-Fi OFF | ❌ 대부분의 기기에서 자동 비활성화 | ❌ 사용 불가 |
| Wi-Fi 토글 (껐다 켬) | 포트 번호 변경될 수 있음 | ⚠️ 재연결 필요 |
| 재부팅 | 무선 디버깅 연결 해제 | ⚠️ 재연결 필요 (페어링은 유지) |

- Android가 무선 디버깅을 Wi-Fi 기능의 하위 항목으로 취급하기 때문
- **사실상 Wi-Fi ON이 전제 조건**

### 루트 환경

루트가 있으면 무선 디버깅 없이 직접 adbd에 접근 가능:

```bash
su -c "setprop service.adb.tcp.port 5555"
su -c "stop adbd && start adbd"
adb connect localhost:5555
```

또는 adb 없이 `su`로 시스템 명령 직접 실행:

```bash
su -c "pm list packages"
su -c "dumpsys battery"
su -c "screencap -p /sdcard/screenshot.png"
```

| | 비루트 | 루트 |
|---|---|---|
| adb 사용 | 무선 디버깅 필수 (Wi-Fi 의존) | `su`로 adbd 직접 제어 |
| Wi-Fi 필요 | 사실상 필요 | 불필요 |
| 재연결 | Wi-Fi 토글/재부팅마다 필요 | 재부팅 전까지 유지 |
| adb 없이 시스템 명령 | ❌ 불가 | ✅ `su -c`로 직접 실행 |

---

## 3. AI 에이전트 연동 시나리오

### OpenClaw exec tool을 통한 adb 사용

adb가 PATH에 있고 무선 디버깅이 연결된 상태라면, OpenClaw의 `exec` tool로 adb 명령 실행 가능:

```
사용자: "내 폰 모델명 알려줘"
  → LLM: exec("adb shell getprop ro.product.model")
  → Termux 셸에서 adb 실행
  → 결과 반환
```

### 실용적 명령 예시

| 명령 | 용도 | 위험도 |
|------|------|-------|
| `adb shell getprop ro.product.model` | 기기 모델명 | 없음 |
| `adb shell getprop ro.build.version.release` | Android 버전 | 없음 |
| `adb shell dumpsys battery` | 배터리 상태 | 없음 |
| `adb shell pm list packages` | 설치된 앱 목록 | 없음 |
| `adb shell screencap -p /sdcard/test.png` | 스크린샷 | 낮음 |
| `adb shell settings put global ...` | 시스템 설정 변경 | **높음** |
| `adb install <apk>` | 앱 설치 | 중간 |

### 상시 기능 vs 일회성 기능

| 유형 | 예시 | adb 적합도 |
|------|------|-----------|
| 일회성 설정 | PPK 비활성화 | ✅ 적합 (현재 용도) |
| 일회성 진단 | 기기 정보 확인 | ✅ 적합 |
| 상시 기능 | AI가 수시로 adb 명령 | ❌ 부적합 (연결 불안정) |

---

## 4. 결론

### 현재 위치

- adb는 **일회성/진단 용도**로 적합하며, 현재 그렇게 안내하고 있다 (PPK 비활성화)
- 상시 AI 기능으로 adb를 활용하는 것은 **무선 디버깅의 불안정성** 때문에 실용적이지 않다

### openclaw-termux와의 비교

openclaw-termux는 adb를 사용하지 않고, 대신 **Flutter + Android API 직접 호출** (Node Protocol)로 디바이스 연동을 구현했다. 이 방식이 상시 기능에는 더 적합하다:

| 방식 | 안정성 | 상시 사용 | 구현 비용 |
|------|-------|----------|----------|
| adb (무선 디버깅) | ⚠️ Wi-Fi 의존, 재연결 필요 | ❌ 부적합 | 낮음 (이미 있음) |
| Android API 직접 호출 | ✅ 항상 동작 | ✅ 적합 | 높음 (APK 내 구현 필요) |

### 향후 참고

- 우리 앱(APK)에서 디바이스 연동이 필요해지면, adb가 아닌 **Kotlin에서 Android API 직접 호출 + OpenClaw Node Protocol**로 구현해야 한다
- adb는 계속 선택적 도구(L3)로 유지하되, **일회성 작업 용도**로만 안내

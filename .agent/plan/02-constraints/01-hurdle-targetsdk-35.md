# 허들 분석: targetSdk 35로의 전환

> 작성일: 2026-03-06
> 상태: Final
> 상위 문서: `01-core/02-standalone-apk-option-d.md`
> 현재 상태: targetSdk 28 확정 (Option B)
> 요약: targetSdk 29+ 전환의 핵심 차단 요소는 W^X SELinux 정책. 우회 경로는 존재하나 각각 심각한 트레이드오프를 수반.

---

## 0. 이 문서의 목적

현재 계획은 targetSdk 28로 확정되어 있다. 향후 Google Play 배포, 최신 Android API 활용, 또는 정책 변경으로 targetSdk 35+가 필요해질 경우를 대비하여 **무엇이 차단하고 있는지**, **어떤 우회 경로가 있는지**, **각각의 대가는 무엇인지**를 정리한다.

---

## 1. 핵심 차단 요소: W^X SELinux 정책

### 1.1 무엇이 문제인가

Android 10 (API 29)부터 앱의 `/data/data/` 디렉토리에서 바이너리를 실행할 수 없다.

```
avc: denied { execute } for name="node" dev="dm-X"
     scontext=u:r:untrusted_app:s0:...
     tcontext=u:object_r:app_data_file:s0:...
     tclass=file permissive=0
```

### 1.2 왜 이렇게 되었나

AOSP 커밋 `0dd738d8` (2019)에서 `app_neverallows.te`에 다음 규칙이 추가됨:

```
neverallow { all_untrusted_apps -mediaprovider } { app_data_file privapp_data_file }:file execute;
```

이 규칙은 **compile-time neverallow**로, SELinux 정책이 빌드될 때 검증된다. 런타임에 SELinux를 permissive로 바꿔도 우회할 수 없다 (root 없이는 SELinux 모드 변경 자체가 불가).

### 1.3 SELinux 도메인 계층

앱의 targetSdkVersion에 따라 다른 SELinux 도메인에서 실행됨:

| targetSdk | SELinux 도메인 | `/data/data/` exec |
|-----------|---------------|-------------------|
| ≤ 25 | `untrusted_app_25` | ✅ 허용 |
| 26–27 | `untrusted_app_27` | ✅ 허용 |
| 28 | `untrusted_app_27` | ✅ 허용 |
| 29–30 | `untrusted_app_29` | ❌ 차단 |
| 31+ | `untrusted_app_32` | ❌ 차단 |

**targetSdk 28이 마지노선**: 28까지는 `untrusted_app_27` 도메인이 적용되어 `/data/data/` 경로에서 exec이 허용된다. 29부터는 `untrusted_app_29` 도메인으로 전환되며, 해당 도메인에는 `app_data_file:file { execute }` 권한이 없다.

### 1.4 우리 앱에 미치는 영향

OpenClaw APK의 핵심 동작:

1. Bootstrap ZIP을 `/data/data/com.openclaw.android/files/usr/`에 추출
2. 추출된 바이너리 실행: `bash`, `apt`, `coreutils`, `node`, `git` 등
3. `apt install`로 추가 패키지 설치 → 바이너리 추출 → 실행

**모든 단계가 `/data/data/` 경로에서의 exec에 의존한다.** targetSdk 29+에서는 단 하나의 바이너리도 실행할 수 없다.

---

## 2. 우회 경로 분석

### 2.1 jniLibs (APK 내 네이티브 라이브러리)

**원리**: APK의 `lib/arm64-v8a/` 디렉토리에 포함된 `.so` 파일은 설치 시 `/data/app/.../lib/arm64/`로 추출되며, 이 경로의 파일은 `apk_data_file` SELinux 라벨을 가진다. `apk_data_file`에는 exec이 허용됨.

**증거**: LADB 앱 (targetSdk 30)이 이 방식으로 ADB 바이너리를 실행한다.

**제약:**

| 제약 사항 | 설명 | 심각도 |
|-----------|------|--------|
| `.so` 확장자 필수 | `lib_node.so`, `lib_bash.so` 등으로 이름 변경 필요 | 중간 |
| 빌드 타임 전용 | APK 빌드 시 포함. 런타임에 새 바이너리 추가 불가 | 🔴 치명적 |
| `extractNativeLibs=true` | APK에서 실제 파일로 추출해야 함. APK 크기 증가 | 낮음 |
| Thin APK 모델 파괴 | 모든 바이너리를 APK에 미리 넣어야 함 → APK 수백 MB | 🔴 치명적 |
| `apt install` 불가 | 런타임에 설치한 패키지의 바이너리는 exec 불가 | 🔴 치명적 |

**결론**: ❌ 핵심 바이너리(node, bash)만 넣는 것은 가능하나, `apt install`로 설치되는 모든 패키지의 바이너리 실행이 불가능하므로 Termux bootstrap 아키텍처와 근본적으로 양립 불가.

### 2.2 System Linker Exec (`/system/bin/linker64`)

**원리**: 동적 링커 `/system/bin/linker64`를 직접 호출하여 바이너리를 로드하면, exec 시스템 콜이 아닌 `mmap`으로 실행되어 SELinux exec 검사를 우회.

```bash
/system/bin/linker64 /data/data/.../usr/bin/bash --login
```

**현황**: termux-exec에서 PR#24로 연구됨. 일부 바이너리에서 동작 확인.

**제약:**

| 제약 사항 | 설명 | 심각도 |
|-----------|------|--------|
| 모든 바이너리에 적용 필요 | 쉘 스크립트의 shebang (`#!/bin/bash`)이 동작하지 않음 — exec이 차단되므로 | 🔴 치명적 |
| `fork+exec` 패턴 깨짐 | C 프로그램 내부의 `execve()` 호출도 모두 패치 필요 | 🔴 치명적 |
| libtermux-exec.so 의존 | `LD_PRELOAD`로 `execve`를 가로채 linker64 호출로 변환 필요 | 높음 |
| Android 버전별 차이 | linker64 동작이 Android 버전마다 다를 수 있음 | 높음 |
| 안정성 미검증 | 프로덕션 수준의 검증 사례 없음 | 높음 |

**결론**: ⚠️ 이론적으로 가능하나, 프로덕션 수준의 안정성 확보에 상당한 엔지니어링 필요. Termux 프로젝트도 2019년 이후 이 경로를 채택하지 않음.

### 2.3 PRoot (ptrace 기반 에뮬레이션)

**원리**: `ptrace()` 시스템 콜로 자식 프로세스의 모든 시스템 콜을 가로채어, `execve()`를 다른 경로나 방식으로 대체.

**선례**: UserLAnd 앱 (targetSdk 30, Play Store 배포)이 이 방식을 사용.

**제약:**

| 제약 사항 | 설명 | 심각도 |
|-----------|------|--------|
| 성능 오버헤드 | 모든 시스템 콜을 가로채므로 5~30% 성능 저하 | 높음 |
| Phantom Process Killer | Android 12+에서 ptrace 프로세스 트리가 팬텀 프로세스로 감지됨 | 높음 |
| FGS 타임아웃 | Android 15에서 Foreground Service 6분 타임아웃 → 백그라운드 동작 불안정 | 높음 |
| 복잡성 | PRoot 자체의 버그, 호환성 이슈 지속적 관리 필요 | 중간 |
| ptrace 제한 가능성 | 향후 Android가 ptrace 자체를 제한할 수 있음 | 중간 |

**결론**: ⚠️ 유일하게 프로덕션에서 검증된 경로 (UserLAnd). 그러나 성능 오버헤드와 Android 12+ 이후 불안정성 증가가 우려.

### 2.4 memfd_create + fexecve

**원리**: 메모리에 익명 파일을 생성(`memfd_create`)하고, `fexecve()`로 실행. 파일 시스템을 거치지 않으므로 SELinux 파일 라벨 검사 우회.

**결론**: ❌ 불가. SELinux는 파일 라벨 기준으로 exec을 차단하는데, `memfd_create`로 생성된 파일도 `tmpfs:file` 라벨을 받으며, 이 라벨에 대한 exec 역시 차단됨.

### 2.5 우회 경로 종합 비교

| 경로 | 실현 가능성 | `apt install` 호환 | 성능 영향 | 프로덕션 선례 | 장기 안정성 |
|------|------------|-------------------|----------|-------------|-----------|
| jniLibs | ✅ | ❌ 불가 | 없음 | LADB (제한적) | 안정 |
| System Linker | ⚠️ | ⚠️ 조건부 | 미미 | 없음 | 불확실 |
| PRoot | ✅ | ✅ | -5~30% | UserLAnd | 하락 추세 |
| memfd_create | ❌ | — | — | — | — |

---

## 3. Termux 프로젝트의 판단

### 3.1 Termux의 결론 (2019~현재)

Termux는 2019년 W^X 정책 도입 이후 targetSdk를 28에서 올리지 않는 것으로 결정.

**근거:**
- `app_neverallows.te`의 `neverallow`는 SELinux 정책 빌드 타임에 강제. 우회 불가.
- jniLibs는 `apt install`과 양립 불가
- PRoot 성능 오버헤드는 터미널 앱으로서 UX를 저하
- Google은 향후 이 제한을 완화할 가능성이 낮음 (보안 방향과 반대)

### 3.2 Termux의 대응

- Google Play에서 자진 철수 (2020)
- F-Droid 전용 배포 (targetSdk 28 허용)
- GitHub Releases 병행
- Google Play 재진입 시도 없음

### 3.3 AnyClaw (friuns2/openclaw-android-assistant)

- Play Store에 배포 중 (targetSdk 34)
- **그러나**: APK 내에 Termux bootstrap을 jniLibs로 포함하지 않음
- 별도 메커니즘으로 exec 문제를 처리하는 것으로 추정 (상세 미확인)
- 10K+ 다운로드이나, 사용자 리뷰에서 안정성 이슈 다수 보고

---

## 4. Google Play 배포 시 추가 허들

targetSdk 35를 달성하더라도 Play Store 배포에는 추가 장벽이 존재:

### 4.1 targetSdk 정책

| 시점 | 요구 사항 |
|------|----------|
| 2025년 8월 | 새 앱: targetSdk ≥ 35 |
| 기존 앱 | 1년 이내 최신 major API - 1 이상 |

targetSdk 28은 Play Store에서 **즉시 거부**.

### 4.2 16KB 페이지 정렬

Android 15+에서 16KB 페이지 크기를 사용하는 기기 등장. Play Store는 모든 네이티브 라이브러리의 16KB 정렬을 요구하기 시작.

- Termux bootstrap의 모든 바이너리를 16KB 정렬로 재빌드해야 함
- 또는 런타임 다운로드 바이너리이므로 Play Store 검사를 피할 수 있는지 불확실

### 4.3 GPL v3 라이선스

별도 문서 (`02-hurdle-firebase-analytics.md`) 참조. Play Store 배포 자체는 GPL v3와 양립 가능하나, 독점 SDK (Firebase 등) 포함 시 위반.

---

## 5. 향후 변화 가능성

### 5.1 Google이 정책을 완화할 가능성

**낮음.**
- W^X는 보안 강화 방향이며, 완화는 보안 후퇴를 의미
- AOSP에 `neverallow`로 하드코딩되어 있어, 예외를 만들려면 SELinux 정책 전체를 수정해야 함
- 2019년 이후 6년간 완화 없음

### 5.2 새로운 우회 기술 등장 가능성

**중간.**
- System Linker Exec 방식이 성숙할 가능성 있음
- WebAssembly 기반 실행 환경이 대안이 될 수 있음
- 그러나 `apt install` 호환 경로는 현재 PRoot 외에 없음

### 5.3 F-Droid targetSdk 요구사항 변화 가능성

**낮음.**
- F-Droid는 FOSS 원칙 우선. 기술적 제약을 이유로 targetSdk를 강제하지 않음
- Termux가 F-Droid의 대표적 앱 중 하나이므로, Termux를 배제하는 정책은 비현실적

---

## 6. 의사결정 요약

### 현재 결정: targetSdk 28 유지

**근거:**
1. W^X SELinux 정책이 `neverallow`로 하드코딩 — 런타임 우회 불가
2. Termux bootstrap 아키텍처 (`apt install` → exec)가 targetSdk 29+와 근본적으로 양립 불가
3. Termux 프로젝트가 6년간 같은 결론 유지
4. F-Droid + GitHub Releases 배포에 targetSdk 28은 아무 문제 없음
5. PRoot 우회는 가능하나, 성능 오버헤드 + 불안정성으로 UX 저하

### targetSdk 35로 전환이 합리적이 되는 조건

다음 중 하나가 충족될 때 재검토:

1. **Google이 앱별 exec 허용 메커니즘을 도입** — 현재 징후 없음
2. **System Linker Exec이 프로덕션 수준으로 안정화** — Termux 커뮤니티 모니터링 필요
3. **Google Play 배포가 비즈니스적으로 필수** — 이 경우 PRoot 또는 아키텍처 전면 재설계 필요
4. **Termux 프로젝트가 targetSdk 29+로 전환** — 이를 따라가는 것이 가장 안전한 경로

### 모니터링 대상

| 대상 | 확인 주기 | 소스 |
|------|----------|------|
| Termux GitHub releases | 분기별 | github.com/termux/termux-app |
| termux-exec PR#24 (System Linker) | 분기별 | github.com/termux/termux-exec |
| AOSP SELinux 정책 변경 | 연간 | android.googlesource.com |
| F-Droid targetSdk 정책 | 연간 | f-droid.org/docs |

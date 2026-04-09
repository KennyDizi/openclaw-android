---
name: release
description: 배포/릴리즈 절차서. 동기화(검증+public push) + 앱 변경 시 APK/GitHub Release. Trigger — "배포해", "릴리즈해".
license:
compatibility: Requires gh CLI, git, access to origin + public remotes. APK 빌드 시 Gradle + signing keystore 추가 필요.
metadata:
  author: AidanPark
  version: "2.0"
allowed-tools:
---

# release

코드 변경을 검증하고 public 레포에 배포한다.
앱 코드(Kotlin/WebView) 변경이 포함된 경우 APK 빌드 + GitHub Release까지 수행한다.

## 필수 규칙

- 릴리즈 전 CHANGELOG.md에 해당 버전 변경 내역이 있는지 확인한다.
- 커밋 메시지: 영문, imperative 스타일, prefix 없음.
- public 레포에 숨김파일(`.agent/`, `CLAUDE.md`) 포함 절대 금지.
- origin(private) push는 승인 없이 진행. public push만 관리자 승인.

## 서명 정보 (APK 빌드 시)

| 항목 | 값 |
|------|-----|
| Keystore | `android/claw-release.jks` |
| Alias | `claw` |
| Password (store/key) | `claw2026` |
| local.properties 경로 | `android/local.properties` |

## 트리거

| 트리거 | 요약 |
|--------|------|
| "배포해", "릴리즈해", "앱 릴리즈", "릴리즈 만들어" | 전체 배포/릴리즈 절차 실행 |

## 절차

```
Step 1. 미커밋 변경사항 확인
   └─ 있음 → repo-management의 "커밋 푸시해" 절차 수행
   └─ 없음 → 계속

Step 2. 버전 범프 (필요 시)
   - 앱 코드(Kotlin/WebView) 변경이 없으면 OA_VERSION만 올린다
   - OA_VERSION 4개 파일 동기화 (doc-map.md 참고)
   - CHANGELOG.md에 변경 내역 기록
   - 커밋 푸시
   └─ 이미 범프됨 → 계속

Step 3. 동기화 확인
   .agent/doc-map.md (SSOT)를 참조하여:

   [3-1] 코드↔문서 동기화
   - 변경된 코드에 대응하는 문서가 함께 수정되었는지 확인
   - 3개국어 동기화 대상이면 영/한/중 모두 수정되었는지 확인
   - 버전 변경 시 CHANGELOG.md가 업데이트되었는지 확인

   [3-2] 경로 간 기능 동기화 (Delivery Path Parity)
   - 스크립트 기능이 수정된 경우, 해당 기능이 존재하는 모든 경로에
     동등하게 반영되었는지 확인
   - 경로: App Install(post-setup.sh) / Termux Install(모듈 스크립트) / Update
   - 상세 매핑은 .agent/skills/verify/feature-map.md 참고

   [3-3] 파일 동기화
   - post-setup.sh ↔ android/app/src/main/assets/post-setup.sh 동일 확인

   └─ 모두 충족 → 계속
   └─ 누락 → 수정 후 커밋 푸시, Step 3 재확인

Step 4. 코드 검증 (verify 스킬 실행)
   .agent/skills/verify/SKILL.md 절차서를 읽고 그대로 수행한다.
   - shellcheck 정적 분석
   - install/update 플로우 무결성
   - 버전 일관성 (4개 파일)
   - 변경 영향 분석 (set -e 안전성, 실행 시점 의존성, 변수/함수 영향)
   - Delivery Path Parity
   - Feature 상충 분석
   └─ ALL PASS → 계속
   └─ FAIL 있음 → 사용자에게 보고, 수정 또는 진행 여부 확인

Step 5. 실기기 사전 검증
   - 변경된 파일을 디바이스에 직접 배포 (ADB push 등)
   - 변경된 기능이 정상 동작하는지 확인
   - 주의: oa --update는 public 레포에서 받으므로 배포 전에는 사용 불가
     → 파일 직접 복사 후 기능 단위 테스트

   [5-1] 이슈 수정인 경우: 사용자 환경 재현 필수
   - 클린/신규 설치 환경에서 테스트하지 마라. 이슈 보고자의 실제 상태를 재현하라.
   - 재현 절차:
     (a) 이슈의 환경 정보 파악 (기존 설치 상태, 버전, 에러 발생 경로)
     (b) 테스트 기기에서 해당 상태를 시뮬레이션 (예: 의존성 삭제, 이전 버전 스크립트 유지)
     (c) 이슈의 에러가 재현되는지 확인
     (d) 수정 적용 후 **사용자가 할 동작**(oa --update 등)을 그대로 실행하여 검증
   - 신규 설치 테스트만으로 통과 판정 금지

   └─ 문제 없음 → 계속
   └─ 문제 발견 → 수정 후 Step 3부터 재시작

Step 6. 앱 릴리즈 판단
   build.gradle.kts의 versionName이 변경되었는지 확인한다.
   └─ versionName 변경됨 → Step 7 (APK 빌드) 진행
   └─ versionName 변경 없음 (스크립트만 변경) → Step 8 (public 동기화)로 건너뜀

Step 7. APK 빌드 (앱 릴리즈 시만)
   [7-1] 사전 검증
   ├─ 서명 키 확인: android/claw-release.jks 존재 확인
   └─ local.properties에 RELEASE_STORE_FILE 설정 확인
       └─ 없으면 → 자동 설정 (경로: ../claw-release.jks, 비밀번호: claw2026)

   [7-2] 빌드
   cd android && ./gradlew assembleRelease
   └─ 성공 → APK 경로와 크기 보고, 계속
   └─ 실패 → 에러 보고 → 중단

Step 8. public 레포 동기화
   ./.agent/skills/repo-management/scripts/deploy-to-public.sh "커밋 메시지"

   커밋 메시지 규칙:
   - 코드 변경사항만 기술한다
   - 숨김파일(.agent/, .claude/, CLAUDE.md) 관련 내용은 포함하지 않는다

   └─ "배포할 변경사항 없음" → 종료
   └─ 성공 → 계속
   └─ 실패 → repo-management의 "스크립트 중도 실패 시 대응" 절차 수행

Step 9. 실기기 배포 후 검증 (update-test 스킬 실행)
   .agent/skills/update-test/SKILL.md 절차서를 읽고 그대로 수행한다.
   - oa --update로 public 레포에서 정상 다운로드되는지 확인
   - 업데이트 로그 분석 (단계 완료, 에러/경고, 버전 변경)
   - 변경된 기능 재확인
   └─ 문제 없음 → 계속
   └─ 문제 발견 → 사용자에게 보고, 핫픽스 또는 롤백

Step 10. GitHub Release 생성 (앱 릴리즈 시만)
   Step 6에서 versionName 변경이 확인된 경우에만 수행.

   gh release create v{RELEASE_VERSION} \
     android/app/build/outputs/apk/release/app-release.apk \
     --repo AidanPark/openclaw-android \
     --title "v{RELEASE_VERSION}" \
     --notes "{릴리즈 노트}"

   릴리즈 노트 작성 규칙:
   - CHANGELOG.md의 해당 버전 항목을 기반으로 작성
   - 카테고리별 그룹핑 (Added, Changed, Fixed 등)
   - 마지막에 Full Changelog 링크 포함

Step 11. 미러 링크 검증 (앱 릴리즈 시만)
   - ghfast.top 미러 링크가 latest를 따라가는지 확인:
     curl -sI "https://ghfast.top/https://github.com/AidanPark/openclaw-android/releases/latest/download/app-release.apk"
   - HTTP 302/200 응답 확인
   - 실패 시 → 관리자에게 보고

Step 12. 이슈 대응 (해당 시)
   - 관련 GitHub 이슈에 수정 버전 안내 댓글
```

---

## 스크립트 중도 실패 시 대응

repo-management 스킬의 "스크립트 중도 실패 시 대응" 절차를 따른다.

## 주의사항

- **미러 링크**: README.zh.md의 ghfast.top 링크는 `/releases/latest/download/`를 사용하므로 GitHub Release가 Latest로 설정되면 자동으로 최신 APK를 가리킨다. 별도 수정 불필요.
- **이전 버전 태그**: Full Changelog 링크를 위해 `gh release list --repo AidanPark/openclaw-android --limit 2`로 이전 버전 태그를 확인한다.
- **스크립트만 변경**: versionName 변경 없이 OA_VERSION만 올린 경우, Step 7/10/11은 건너뛴다. deploy-to-public.sh + oa --update 검증만 수행.

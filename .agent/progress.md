# Progress

## 현재 작업

- 없음 (v1.0.22 배포 완료)

## 완료

- **Issue #103**: ELF 바이너리 자동 래핑 — glibc-compat.js에 PT_INTERP 기반 래핑, shebang 해석, LD_PRELOAD 충돌 해결, shell 인터셉트 구현. libcap.so.2 보충 라이브러리 배포. 실기기 테스트 통과 (S20+, v1.0.20 → v1.0.22 업데이트 경로).
- **Issue #105**: localhost DNS 해석 실패 — glibc-compat.js에 localhost shortcut 추가, glibc/etc/hosts 파일 생성 로직 추가. 실기기 테스트 통과.
- v1.0.22 커밋/푸시/public 동기화 완료

## 다음 할 일

- Issue #103, #105 응답 및 관리자 승인 후 클로즈
- 유형 C (신규 설치) 테스트 — 별도 기기 또는 재설치 필요
- P1 잔여 (HARNESS.md 참고)
  - bug-fix 스킬
  - 앱 모듈 테스트 인프라 구축 (JUnit5 + MockK)
  - 로깅 추상화 도입 (AppLogger)

## 블로커

- 없음

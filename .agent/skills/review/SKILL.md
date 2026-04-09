---
name: review
description: 코드 리뷰 절차서. 커밋 전 2-pass 코드 리뷰를 수행한다. Trigger — "리뷰해", "코드 리뷰", "리뷰해줘".
license:
compatibility:
metadata:
  author: AidanPark
  version: "1.0"
allowed-tools:
---

# review

커밋 전 변경 코드를 2-pass로 리뷰하고, 기계적 수정은 즉시 적용하며, 판단이 필요한 사항만 관리자에게 보고한다.

## 필수 규칙

- 리뷰 대상은 **staged + unstaged 변경사항** 전체다. 커밋되지 않은 변경만 본다.
- 변경이 없으면 "리뷰할 변경사항이 없습니다" → 종료.
- 자동 수정(Fix-First)은 **관리자 승인 후** 적용한다.
- 리뷰 결과는 한국어로 보고한다.

## 트리거

| 트리거 | 요약 |
|--------|------|
| "리뷰해", "코드 리뷰", "리뷰해줘" | 변경 코드에 대한 2-pass 리뷰 수행 |

## 범위

### 하는 일

- 변경된 코드의 2-pass 리뷰 (Critical + Informational)
- 기술 스택별 체크 (Shell Script / Kotlin / React-TypeScript)
- 기계적 수정 가능 항목 자동 수정 제안 (Fix-First)
- 변경 영향 분석

### 하지 않는 일

- 커밋/푸시 (repo-management 스킬 담당)
- 배포 (release 스킬 담당)
- 전체 코드베이스 감사 (변경분만 리뷰)

## 절차

```
Step 1. 변경사항 수집
   git diff (unstaged) + git diff --cached (staged)를 합쳐 전체 변경분 파악.
   변경된 파일 목록과 변경 라인 수를 요약.
   └─ 변경 없음 → "리뷰할 변경사항이 없습니다" → 종료
   └─ 변경 있음 → 계속

Step 2. Pass 1 — Critical (반드시 수정)
   프로덕션 장애, 데이터 손실, 보안 취약점을 일으킬 수 있는 문제를 찾는다.

   [Shell Script]
   shellcheck가 잡는 구문 오류(변수 인용 등)는 pre-commit hook에 위임한다.
   review에서는 shellcheck가 잡지 못하는 의미론적 문제에 집중:
   - 명령 주입 가능성 (eval, 검증 없는 사용자 입력)
   - rm -rf에 변수 사용 (빈 변수 시 루트 삭제 위험)
   - 경로 하드코딩 (/data/data/com.termux 등 — $PREFIX 사용 필수)
   - A&&B||C 패턴 (if/then/else로 전환 필요)
   - 파일 동기화 누락 (post-setup.sh, glibc-compat.js 등)

   [Kotlin/Android]
   - android.util.Log 직접 사용 (AppLogger 사용 필수)
   - GlobalScope/Dispatchers 직접 사용
   - 하드코딩된 시크릿, API 키
   - 널 안전성 위반 (!! 연산자 남용)

   [React/TypeScript]
   - XSS 취약점 (dangerouslySetInnerHTML 등)
   - 타입 에러 (any 남용, 타입 단언 남용)
   - 번역 키 누락 (i18n 미적용 하드코딩 문자열)

   [공통]
   - 시크릿/자격증명 노출
   - 무한 루프 가능성
   - 에러 핸들링 누락 (외부 API 호출, 파일 I/O)

   → Critical 이슈 목록 작성 (심각도: CRITICAL)

Step 3. Pass 2 — Informational (참고)
   수정을 강제하지 않고 개선 제안만 한다.

   - 코드 중복 (3줄 이상 동일 패턴)
   - 매직 넘버/매직 스트링
   - 불필요한 복잡성
   - 네이밍 개선 여지
   - 성능 개선 가능성
   - 버전 동기화 누락 (OA_VERSION 4개 파일 — check-version-sync hook과 중복이나 리뷰 시 재확인)
   - 문서 현행화 필요 여부 (doc-map.md 참조)
   - CHANGELOG 업데이트 필요 여부

   → Informational 이슈 목록 작성 (심각도: INFO)

Step 4. Fix-First 적용
   Pass 1에서 발견된 이슈 중 기계적으로 수정 가능한 것을 분류:

   [자동 수정 가능]
   - 변수 인용 누락 → "$VAR" 추가
   - android.util.Log → AppLogger 치환
   - 파일 동기화 누락 → 복사
   - OA_VERSION 불일치 → 동기화
   - A&&B||C → if/then/else 전환

   [관리자 판단 필요]
   - 아키텍처 변경이 필요한 경우
   - 비즈니스 로직 관련 판단
   - 기능 추가/제거 결정

   → 자동 수정 항목을 관리자에게 보여주고 승인 요청
   → 승인 시 수정 적용

Step 5. 리뷰 보고서
   아래 형식으로 보고:

   ## 리뷰 결과

   **변경 요약**: {파일 수}개 파일, +{추가} -{삭제} 라인

   ### Critical ({개수})
   - [ ] {파일:라인} — {설명}

   ### Informational ({개수})
   - {파일:라인} — {설명}

   ### Fix-First
   - 자동 수정 {N}건 (승인 대기 / 적용 완료)

   ### 판정
   - PASS: Critical 0건
   - WARN: Critical 있으나 수정 완료
   - FAIL: 미해결 Critical 있음
```

## 주의사항

- **Fix-First는 보수적으로**: 확실한 것만 자동 수정 제안. 애매하면 Informational로 분류.
- **변경분만 리뷰**: 주변 코드의 기존 문제는 지적하지 않는다. 변경된 라인과 직접 관련된 것만.
- **shellcheck 연계**: Shell Script 변경이 있으면 shellcheck 결과도 참고한다 (hook이 자동 실행).
- **verify 스킬과의 관계**: review는 코드 품질에 집중, verify는 설치/업데이트 플로우 무결성에 집중. 배포 전에는 둘 다 수행.

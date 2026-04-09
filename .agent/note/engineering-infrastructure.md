# 엔지니어링 인프라 — 코드 품질 & 개발 환경 표준

> openclaw-android 프로젝트의 엔지니어링 인프라 도입 계획.
> 각 설정 파일의 상세 내용은 프로젝트 루트의 실제 파일을 참조.
> 최종 수정일: 2026-03-10

---

## 1. 프로젝트 특성

| 항목 | 내용 |
|------|------|
| 프로젝트 | openclaw-android |
| 기술 스택 | Shell Script (bash) + Kotlin/Android |
| 패키지 | `com.openclaw.android` |
| 브랜치 | `main` 단일 브랜치 |
| 커밋 스타일 | 영문, imperative, prefix 없음 (예: "Fix update script syntax error") |
| 레포 구조 | private (`origin`) + public (`public`) 이중 레포 |
| Java | JDK 21 |
| Gradle | 9.3.1, AGP 8.13.1, Kotlin 2.2.21, compileSdk 36 |
| NDK | 28.0.13004108 |

---

## 2. 현재 적용 현황

| # | 항목 | 상태 | 비고 |
|---|------|------|------|
| 1 | `.gitignore` | ✅ 적용 | Android/Gradle/Kotlin/IDE 패턴 포함 |
| 2 | `.gitattributes` | ✅ 적용 | 전체 파일타입 LF 강제 + 바이너리 지정 |
| 3 | `.github/workflows/android-build.yml` | ✅ 있음 | www 빌드 + APK 빌드 + 릴리스 |
| 4 | `.editorconfig` | ✅ 적용 | Kotlin/Shell/XML/TS 설정 포함 |
| 5 | `.coderabbit.yaml` | ✅ 적용 | Kotlin/Android 리뷰 규칙, main 브랜치 대상 |
| 6 | `.markdownlint-cli2.yaml` | ✅ 적용 | ZeroClaw 준용, build/dist 제외 |
| 7 | `detekt.yml` | ✅ 적용 | Kotlin 정적 분석 (detekt 1.23.8) |
| 8 | ktlint | ✅ 적용 | Kotlin 포매팅 (ktlint-gradle 14.1.0) |
| 9 | `.githooks/pre-commit` | ✅ 적용 | ktlint + detekt 자동 실행 |
| 10 | `.github/dependabot.yml` | ✅ 적용 | Gradle + GitHub Actions + npm |
| 11 | `SECURITY.md` | ✅ 적용 | ZeroClaw 준용, Termux/glibc 보안 아키텍처 |
| 12 | `CONTRIBUTING.md` | ✅ 적용 | ZeroClaw 준용, 단일 main 브랜치 반영 |
| 13 | `CODE_OF_CONDUCT.md` | ✅ 적용 | Contributor Covenant 2.1 |
| 14 | `CHANGELOG.md` | ✅ 적용 | v1.0.0 ~ v1.0.6 이력 |

---

## 3. 커밋 & 브랜치 컨벤션

### 3-1. 커밋 메시지

영문, imperative 스타일, **prefix 없음**.

```
<subject>

<body (선택)>
```

- 대문자 시작, 마침표 없음, 명령형 현재형
- 50자 이내 (subject)

**예시**:

```
Fix update-core.sh syntax error
Add multi-session terminal tab bar
Upgrade Node.js to v22.22.0 for FTS5 support
```

### 3-2. 브랜치 전략

```
main (단일 브랜치)
```

- 모든 작업은 `main`에서 직접 진행
- private 레포(`origin`)에 push → 배포 시 public 레포(`public`)에 반영
- 숨김파일(`.agent/`, `CLAUDE.md`)은 public에서 자동 제외

### 3-3. 코드 스타일

- **Shell**: POSIX 호환, 4칸 들여쓰기, `scripts/lib.sh` 컨벤션 준수
- **Kotlin**: [공식 코딩 컨벤션](https://kotlinlang.org/docs/coding-conventions.html), 120자, 4칸 들여쓰기
- **XML**: 2칸 들여쓰기
- **TypeScript/React** (www): ESLint 설정 준수

---

## 4. 도입 계획

### Phase 1 — 기본 인프라 (즉시 적용 가능)

코드 변경 없이 설정 파일만 추가하는 항목.

- [x] `.editorconfig` — 에디터 설정 통일 (indent, charset, EOL)
- [x] `.gitignore` 보강 — Android/Gradle/Kotlin/IDE 패턴 추가
- [x] `.gitattributes` 보강 — Kotlin, XML, Gradle 파일 LF 강제, 바이너리 지정
- [x] `.github/dependabot.yml` — Gradle + GitHub Actions + npm 의존성 자동 업데이트

### Phase 2 — 코드 품질 도구

Gradle 플러그인 추가 및 린트 도구 설정.

- [x] `detekt.yml` + Gradle 플러그인 — Kotlin 정적 분석 (detekt 1.23.8)
- [x] ktlint + `.editorconfig` 규칙 — Kotlin 포매팅 (ktlint-gradle 14.1.0)
- [x] `.githooks/pre-commit` — 커밋 전 자동 검사 (ktlint + detekt)
- [x] `.coderabbit.yaml` — AI 코드리뷰 (GitHub PR 연동)
- [x] `.markdownlint-cli2.yaml` — 문서 린트

### Phase 3 — 거버넌스 & 릴리스 (프로덕션 진입 시)

외부 사용자 대응 및 릴리스 관리.

- [x] `SECURITY.md` — 보안 취약점 리포트 정책
- [x] `CONTRIBUTING.md` — 기여 가이드
- [x] `CODE_OF_CONDUCT.md` — 행동 강령
- [x] `CHANGELOG.md` — 릴리스 관리
- [ ] APK 서명 자동화 — release workflow에 서명 + SHA256SUMS 추가
- [ ] ProGuard/R8 최적화 규칙 강화

---

## 5. 주요 설정 참고

### .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.{kt,kts}]
indent_size = 4
max_line_length = 120

[*.{sh,bash}]
indent_size = 4

[*.{xml,json,yaml,yml}]
indent_size = 2

[*.{ts,tsx,js,jsx,css}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### .gitattributes (보강)

```
* text=auto eol=lf
*.sh text eol=lf
*.js text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.h text eol=lf
*.kt text eol=lf
*.kts text eol=lf
*.xml text eol=lf
*.md text eol=lf
*.gradle text eol=lf
*.json text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.properties text eol=lf
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.jar binary
*.so binary
*.apk binary
*.aab binary
*.zip binary
gradlew text eol=lf
gradlew.bat text eol=crlf
```

### .github/dependabot.yml

```yaml
version: 2
updates:
  - package-ecosystem: "gradle"
    directory: "/android"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
    reviewers:
      - "AidanPark"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "ci"
    reviewers:
      - "AidanPark"

  - package-ecosystem: "npm"
    directory: "/android/www"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
    reviewers:
      - "AidanPark"
```

### CI workflow 현황

`android-build.yml`이 이미 존재하며 다음을 수행:
1. www 빌드 (Node.js 22, npm ci, npm run build)
2. APK 빌드 (JDK 21, Gradle assembleDebug)
3. 릴리스 (main push 시 아티팩트 업로드)

ktlint/detekt 단계는 Phase 2에서 CI에 추가.

---

## 6. 관련 문서

- [MEMORY.md](../memory/MEMORY.md) — 프로젝트 상태 및 이력
- [repo-management SKILL](../skills/repo-management/SKILL.md) — 커밋/배포 절차

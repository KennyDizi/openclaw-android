#!/bin/bash
# =============================================================================
# deploy-to-public.sh — private 레포의 코드를 public 레포에 배포
#
# 용도:
#   배포 시 실행. private 레포(origin)의 main 코드를 public 레포에 반영.
#   숨김파일(.agent/, CLAUDE.md)은 자동 제외.
#
# Remote 구조:
#   origin = AidanPark/openclaw-android-private  — 작업 레포
#   public = AidanPark/openclaw-android           — 배포 레포
#
# 상세 흐름:
#   1. git fetch public main
#      → public 레포의 최신 상태를 가져옴
#   2. git checkout -b _deploy_tmp public/main
#      → public 레포의 main을 기준으로 로컬 임시 브랜치 생성
#   3. git rm -rf . && git checkout main -- .
#      → 기존 파일을 전부 제거한 뒤, private main의 파일로 교체
#      → merge를 사용하지 않으므로 충돌이 발생하지 않음
#   4. 숨김파일(.agent/, CLAUDE.md 등) 제거
#   5. git commit -m "커밋 메시지"
#      → 숨김파일이 빠진 코드 변경만 커밋
#   6. git push public HEAD:main
#      → public 레포의 main에 push
#   7. git checkout main && git branch -D _deploy_tmp
#      → private 레포의 main으로 복귀, 임시 브랜치 삭제
#
# 이전 방식(squash merge)은 배포 간 같은 영역을 수정하면 충돌이 발생했음.
# checkout 방식은 merge 로직을 사용하지 않아 충돌 자체가 불가능.
# =============================================================================

set -e

# --- 색상 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 숨김파일 목록 (public 레포 제외 대상) ---
PRIVATE_FILES=(
    ".agent"
    ".claude"
    "CLAUDE.md"
    "doit.md"
)

DEPLOY_BRANCH="_deploy_tmp"

# --- 인자 확인 ---
if [ -z "$1" ]; then
    echo -e "${RED}사용법: $0 \"커밋 메시지\"${NC}"
    echo -e "${RED}예시:   $0 \"Add OpenCode integration\"${NC}"
    exit 1
fi

COMMIT_MSG="$1"

# --- 사전 검증 ---
if [ "$(git branch --show-current)" != "main" ]; then
    echo -e "${RED}오류: main 브랜치에서 실행하세요. (현재: $(git branch --show-current))${NC}"
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${RED}오류: 커밋되지 않은 변경사항이 있습니다. 먼저 커밋하세요.${NC}"
    exit 1
fi

if ! git remote get-url public &>/dev/null; then
    echo -e "${RED}오류: 'public' 리모트가 설정되지 않았습니다.${NC}"
    echo -e "${RED}설정: git remote add public https://github.com/AidanPark/openclaw-android.git${NC}"
    exit 1
fi

echo -e "${GREEN}=== public 레포 배포 시작 ===${NC}"
echo ""

# --- 정리 함수 (EXIT trap) ---
cleanup() {
    local exit_code=$?
    if [ "$(git branch --show-current 2>/dev/null)" != "main" ]; then
        git checkout -f main 2>/dev/null || true
    fi
    git branch -D "$DEPLOY_BRANCH" 2>/dev/null || true
}
trap cleanup EXIT

# --- [1/5] public 리모트 fetch ---
echo -e "${YELLOW}[1/5] public 리모트에서 최신 상태 fetch...${NC}"
git fetch public main
echo ""

# --- [2/5] 임시 브랜치 생성 ---
echo -e "${YELLOW}[2/5] 배포용 임시 브랜치 생성...${NC}"
git branch -D "$DEPLOY_BRANCH" 2>/dev/null || true
git checkout -b "$DEPLOY_BRANCH" public/main
echo ""

# --- [3/5] main에서 파일 동기화 (checkout 방식 — 충돌 없음) ---
echo -e "${YELLOW}[3/5] main 브랜치에서 파일 동기화...${NC}"

# public의 기존 파일을 전부 제거
git rm -rf . > /dev/null 2>&1 || true

# private main의 파일로 교체
git checkout main -- .

# 숨김파일 제거
for f in "${PRIVATE_FILES[@]}"; do
    git rm -rf "$f" 2>/dev/null || true
    rm -rf "$f" 2>/dev/null || true
done
echo ""

# --- [4/5] 변경사항 확인 및 커밋 ---
echo -e "${YELLOW}[4/5] 변경사항 확인 및 커밋...${NC}"
if git diff --cached --quiet; then
    echo -e "${YELLOW}배포할 코드 변경사항이 없습니다.${NC}"
    echo ""
    exit 0
fi

echo -e "${YELLOW}배포될 변경사항:${NC}"
git diff --cached --stat
echo ""

git commit -m "$COMMIT_MSG"
echo ""

# --- [5/5] public 레포에 push ---
echo -e "${YELLOW}[5/5] public 레포에 push...${NC}"
git push public HEAD:main
echo ""

echo -e "${GREEN}=== 배포 완료! ===${NC}"
echo -e "${GREEN}  - public 레포(openclaw-android)의 main에 코드가 반영되었습니다${NC}"

#!/bin/bash
# ============================================================
# 🧰 Telemetry Platform Demo - Environment Verification Script
# For Intel Mac local setup (Docker Desktop)
# ============================================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
  local cmd=$1
  local name=$2
  if command -v "$cmd" >/dev/null 2>&1; then
    local version=$($cmd --version 2>/dev/null | head -n 1)
    echo -e "${GREEN}✅ $name found:${NC} ${version:-OK}"
  else
    echo -e "${RED}❌ $name not found${NC}"
  fi
}

echo "------------------------------------------------------------"
echo "🔍 Telemetry Platform Demo - Environment Check"
echo "------------------------------------------------------------"

# Core tools
check java "Java (JDK)"
check gradle "Gradle"
check git "Git"
check docker "Docker"
check kind "Kind (Kubernetes)"
check kubectl "kubectl"
check helm "Helm"
check python3 "Python3"
check mkdocs "MkDocs"

# Docker Compose check (Docker Desktop CLI integration)
echo
if docker compose version >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Docker Compose found (integrated with Docker Desktop)${NC}"
else
  echo -e "${RED}❌ Docker Compose not available${NC}"
fi

# Infrastructure containers
echo
echo "------------------------------------------------------------"
echo "🧱 Infrastructure Containers Check"
echo "------------------------------------------------------------"

for svc in oracle redis kafka; do
  if docker ps --format '{{.Names}}' | grep -q "$svc"; then
    echo -e "${GREEN}✅ $svc container is running${NC}"
  else
    echo -e "${YELLOW}⚠️  $svc container not found or not running${NC}"
  fi
done

# Gradle wrapper test
echo
echo "------------------------------------------------------------"
echo "📦 Project Gradle Wrapper Check"
echo "------------------------------------------------------------"

if [ -f "./gradlew" ]; then
  ./gradlew -q projects >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Gradle wrapper works correctly${NC}"
  else
    echo -e "${RED}❌ Gradle wrapper failed to run${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Gradle wrapper (./gradlew) not found in this directory${NC}"
fi

echo
echo "------------------------------------------------------------"
echo "✅ Verification Complete"
echo "------------------------------------------------------------"
echo -e "Review any ${RED}❌ Missing${NC} or ${YELLOW}⚠️  Warning${NC} items above."

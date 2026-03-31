#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# DANGER ZONE — Full Reset Script
# Stops all containers and DELETES all data (emails, logs, workflows)
# Only run this if you want to start completely fresh.
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}══════════════════════════════════════════════════════${NC}"
echo -e "${RED}  WARNING: This will DELETE ALL EMAIL DATA & WORKFLOWS  ${NC}"
echo -e "${RED}══════════════════════════════════════════════════════${NC}"
echo ""
read -p "Type 'DELETE ALL' to confirm: " CONFIRM

if [[ "$CONFIRM" != "DELETE ALL" ]]; then
  echo "Aborted. No changes made."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
docker compose down -v --remove-orphans 2>/dev/null || true
echo -e "${YELLOW}✓ All containers stopped and volumes deleted.${NC}"
echo "To restart fresh: ./scripts/setup.sh"

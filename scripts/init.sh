#!/bin/bash
# ============================================================
# init.sh — Auto-seed Neo4j if the database is empty
# Called by the neo4j-init container on first startup.
#
# Logic:
#   1. Wait for Neo4j bolt to be reachable
#   2. Check if any :Component nodes exist
#   3. If empty → run migration.cypher + stability_metrics.cypher
#   4. If already seeded → skip, exit 0
# ============================================================

set -e

NEO4J_USER="${NEO4J_USER:-neo4j}"
NEO4J_PASS="${NEO4J_PASS:-studentportal123}"
NEO4J_HOST="${NEO4J_HOST:-neo4j}"
NEO4J_BOLT_PORT="${NEO4J_BOLT_PORT:-7687}"
BOLT="bolt://${NEO4J_HOST}:${NEO4J_BOLT_PORT}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Step 1: wait for bolt ----
echo "⏳ Waiting for Neo4j at ${BOLT} ..."
MAX_RETRIES=30
RETRY=0
until cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" "RETURN 1" >/dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "❌ Neo4j did not become available after ${MAX_RETRIES} attempts. Exiting."
        exit 1
    fi
    echo "   ...retry ${RETRY}/${MAX_RETRIES}"
    sleep 3
done
echo "✅ Neo4j is reachable."

# ---- Step 2: check if already seeded ----
NODE_COUNT=$(cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" \
    "MATCH (c:Component) RETURN count(c) AS cnt" 2>/dev/null | tail -1 | tr -d ' "')

echo "📊 Existing Component nodes: ${NODE_COUNT}"

if [ "$NODE_COUNT" != "0" ] && [ -n "$NODE_COUNT" ]; then
    echo "✅ Database already seeded (${NODE_COUNT} components). Skipping migration."
    exit 0
fi

# ---- Step 3: clean existing data (safety) ----
echo ""
echo "🗑️  Cleaning database..."
cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" "MATCH (n) DETACH DELETE n;"
echo "✅ Database cleaned."

# ---- Step 4: run migration (CREATE nodes + relationships) ----
echo ""
echo "🔧 Running migration..."
cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" < "${SCRIPT_DIR}/migration.cypher"
echo "✅ Migration complete."

# ---- Step 5: verify ----
echo ""
echo "🔍 Verification:"
cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" \
    "MATCH (n:Component) RETURN n.name AS Component, n.layer AS Layer ORDER BY n.layer, n.name;"

# ---- Step 6: run stability metrics ----
echo ""
echo "📊 Running stability metrics query..."
cypher-shell -a "$BOLT" -u "$NEO4J_USER" -p "$NEO4J_PASS" < "${SCRIPT_DIR}/stability_metrics.cypher"

# ---- Done ----
echo ""
echo "============================================"
echo "✅ All done! Neo4j is seeded and ready."
echo "   Browser:  http://localhost:7474"
echo "   Bolt:     bolt://localhost:7687"
echo "   User:     ${NEO4J_USER}"
echo "   Password: ${NEO4J_PASS}"
echo ""
echo "   Try:  MATCH (n)-[r]->(m) RETURN n, r, m"
echo "============================================"
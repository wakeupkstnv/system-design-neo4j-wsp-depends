# Global Student Portal — Dependency Graph & Stability Metrics

## Overview

This project models the **Global Student Portal** architecture as a dependency graph in **Neo4j** (graph database) and computes **stability metrics** based on Robert C. Martin's *Clean Architecture* (Chapter 14: Component Coupling).

### Architecture Components (from diagram)

The system consists of 17 components across 7 layers:

```
┌─────────────────────────────────────────────────────────────────┐
│  FRONTEND        UI (rl)                                        │
├─────────────────────────────────────────────────────────────────┤
│  INFRASTRUCTURE  Proxy  ←→  Traefik                             │
├─────────────────────────────────────────────────────────────────┤
│  GATEWAY         Gateway                                        │
├─────────────────────────────────────────────────────────────────┤
│  BACKEND         Auth API │ Registration API │ Profile API       │
│                  Grade/Schedule │ Input Data                     │
├─────────────────────────────────────────────────────────────────┤
│  ETL             S1 List ETL │ S2 List ETL                      │
├─────────────────────────────────────────────────────────────────┤
│  DATA            Redis Cluster │ PgBouncer │ PG Cluster         │
├─────────────────────────────────────────────────────────────────┤
│  MESSAGING       Kafka + Kafka Connect                          │
├─────────────────────────────────────────────────────────────────┤
│  STORAGE         S3 Service │ S3 Cluster                        │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- (Optional) Python 3 for local metric computation

### 1. Start Neo4j + Auto-Seed

```bash
docker compose up -d
```

That's it! Two containers start:

| Container | Purpose |
|-----------|---------|
| `gsp-neo4j` | Neo4j database (stays running) |
| `gsp-neo4j-init` | Checks if DB is empty → runs migration → exits |

The init container automatically:
- Waits for Neo4j to pass its healthcheck
- Checks if any `:Component` nodes exist
- If the database is empty — runs `migration.cypher` (17 nodes, 23 edges)
- Runs `stability_metrics.cypher` and prints results
- Exits with code 0 (does nothing on subsequent `docker compose up`)

Check progress:

```bash
docker compose logs -f neo4j-init   # watch migration output
docker compose ps                   # neo4j = healthy, neo4j-init = exited (0)
```

### 2. Open Neo4j Browser

Navigate to **http://localhost:7474** and log in:

- Username: `neo4j`
- Password: `studentportal123`

### 4. Visualize the Graph

In Neo4j Browser, run:

```cypher
MATCH (n)-[r]->(m) RETURN n, r, m
```

### 5. Compute Stability Metrics

**Option A — In Neo4j Browser:**

Copy and paste the contents of `scripts/stability_metrics.cypher`.

**Option B — Via command line:**

```bash
cat scripts/stability_metrics.cypher | docker exec -i gsp-neo4j cypher-shell -u neo4j -p studentportal123
```

**Option C — Local Python script (no Neo4j required):**

```bash
python3 scripts/compute_metrics.py
```

Results are saved to `docs/stability_metrics.md`.

## Stability Metrics

From Robert C. Martin's *Clean Architecture*:

| Metric | Formula | Description |
|--------|---------|-------------|
| **Fan-in (Ca)** | Count of incoming `DEPENDS_ON` edges | How many components depend on this one |
| **Fan-out (Ce)** | Count of outgoing `DEPENDS_ON` edges | How many components this one depends on |
| **Instability (I)** | `Ce / (Ca + Ce)` | 0 = maximally stable, 1 = maximally unstable |

### Key Findings

| Component | Fan-in | Fan-out | I | Status |
|-----------|:------:|:-------:|:---:|--------|
| UI (rl) | 0 | 2 | 1.000 | Maximally unstable (expected — top of call chain) |
| Gateway | 2 | 5 | 0.714 | High fan-out — routes to many services |
| PgBouncer | 4 | 1 | 0.200 | Stable — many services depend on it |
| PG Cluster | 3 | 0 | 0.000 | Maximally stable (leaf node) |
| Redis Cluster | 1 | 0 | 0.000 | Maximally stable (leaf node) |
| S3 Cluster | 2 | 0 | 0.000 | Maximally stable (leaf node) |


## Project Structure

```
.
├── docker-compose.yml              # Neo4j container setup
├── README.md                       # This file
└── scripts/
    ├── migration.cypher            # Creates nodes & relationships in Neo4j
    ├── stability_metrics.cypher    # Cypher query for stability metrics
    ├── init.sh            
    └── compute_metrics.py        
```

## Cypher Queries Reference

### Create a component

```cypher
CREATE (:Component {name: "Auth API", layer: "backend", description: "Authentication service"})
```

### Create a dependency

```cypher
MATCH (a:Component {name: "Gateway"}), (b:Component {name: "Auth API"})
CREATE (a)-[:DEPENDS_ON {type: "token"}]->(b)
```

### Stability metrics query

```cypher
MATCH (c:Component)
OPTIONAL MATCH (other)-[:DEPENDS_ON]->(c)
WITH c, COUNT(DISTINCT other) AS fan_in
OPTIONAL MATCH (c)-[:DEPENDS_ON]->(dep)
WITH c, fan_in, COUNT(DISTINCT dep) AS fan_out
RETURN
    c.name AS Component,
    c.layer AS Layer,
    fan_in AS Fan_In,
    fan_out AS Fan_Out,
    CASE WHEN (fan_in + fan_out) = 0 THEN 0.0
         ELSE round(toFloat(fan_out) / (fan_in + fan_out) * 1000) / 1000
    END AS Instability
ORDER BY Instability DESC, c.name;
```

### Show full graph

```cypher
MATCH (n)-[r]->(m) RETURN n, r, m
```

### Find most depended-upon components

```cypher
MATCH (other)-[:DEPENDS_ON]->(c:Component)
RETURN c.name, COUNT(other) AS dependents
ORDER BY dependents DESC
```

## Teardown

```bash
docker compose down -v   # removes containers and volumes
```

## References

- Martin, R.C. *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Chapter 14: Component Coupling.
- [Neo4j Documentation](https://neo4j.com/docs/)
- [Cypher Query Language](https://neo4j.com/docs/cypher-manual/current/)

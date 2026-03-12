// ============================================================
// Global Student Portal — Dependency Graph Migration
// Based on the architecture diagram provided
// ============================================================
// Run: cat scripts/migration.cypher | cypher-shell -u neo4j -p studentportal123
// Or paste into Neo4j Browser at http://localhost:7474
// ============================================================

CREATE (ui:Component {name: "UI (rl)", layer: "frontend", description: "Frontend client application (React/Vue)"})
CREATE (proxy:Component {name: "Proxy", layer: "infrastructure", description: "Reverse proxy layer between UI and gateway"})
CREATE (traefik:Component {name: "Traefik", layer: "infrastructure", description: "Edge router / load balancer"})
CREATE (gateway:Component {name: "Gateway", layer: "gateway", description: "API Gateway — routes requests to backend services"})
CREATE (authApi:Component {name: "Auth API", layer: "backend", description: "Authentication service — issues and validates tokens"})
CREATE (regApi:Component {name: "Registration API", layer: "backend", description: "Student registration service"})
CREATE (profileApi:Component {name: "Profile API", layer: "backend", description: "User profile management service"})
CREATE (gradeSchedule:Component {name: "Grade / Schedule", layer: "backend", description: "Grades and schedule management service"})
CREATE (inputData:Component {name: "Input Data", layer: "backend", description: "Data ingestion / input module for Registration API"})
CREATE (s1Etl:Component {name: "S1 List ETL", layer: "etl", description: "ETL pipeline — student list source 1"})
CREATE (s2Etl:Component {name: "S2 List ETL", layer: "etl", description: "ETL pipeline — student list source 2"})
CREATE (redis:Component {name: "Redis Cluster", layer: "data", description: "In-memory cache for session tokens"})
CREATE (pgbouncer:Component {name: "PgBouncer", layer: "data", description: "PostgreSQL connection pooler"})
CREATE (pgCluster:Component {name: "PG Cluster", layer: "data", description: "PostgreSQL database cluster"})
CREATE (kafka:Component {name: "Kafka + Kafka Connect", layer: "messaging", description: "Event streaming platform"})
CREATE (s3Service:Component {name: "S3 Service", layer: "storage", description: "Object storage service"})
CREATE (s3Cluster:Component {name: "S3 Cluster", layer: "storage", description: "S3-compatible object storage cluster"})

// --- Step 3: Create dependency relationships ---
// Direction: (A)-[:DEPENDS_ON]->(B) means A depends on B (A calls/uses B)

// UI -> Proxy (socket connection)
CREATE (ui)-[:DEPENDS_ON {type: "socket"}]->(proxy)

// UI -> Traefik (HTTP traffic)
CREATE (ui)-[:DEPENDS_ON {type: "http"}]->(traefik)

// Proxy -> Gateway
CREATE (proxy)-[:DEPENDS_ON {type: "socket"}]->(gateway)

// Gateway -> Auth API (token validation)
CREATE (gateway)-[:DEPENDS_ON {type: "token"}]->(authApi)

// Gateway -> Registration API (token)
CREATE (gateway)-[:DEPENDS_ON {type: "token"}]->(regApi)

// Gateway -> Profile API (token)
CREATE (gateway)-[:DEPENDS_ON {type: "token"}]->(profileApi)

// Gateway -> Grade/Schedule (token)
CREATE (gateway)-[:DEPENDS_ON {type: "token"}]->(gradeSchedule)

// Gateway -> Redis Cluster (session token)
CREATE (gateway)-[:DEPENDS_ON {type: "session_token"}]->(redis)

// Registration API -> Input Data (pull)
CREATE (regApi)-[:DEPENDS_ON {type: "data"}]->(inputData)

// Input Data -> S1 List ETL (pull)
CREATE (inputData)-[:DEPENDS_ON {type: "pull"}]->(s1Etl)

// Input Data -> S2 List ETL (pull)
CREATE (inputData)-[:DEPENDS_ON {type: "pull"}]->(s2Etl)

// Registration API -> PgBouncer (DB queries)
CREATE (regApi)-[:DEPENDS_ON {type: "sql"}]->(pgbouncer)

// Auth API -> PgBouncer (DB queries)
CREATE (authApi)-[:DEPENDS_ON {type: "sql"}]->(pgbouncer)

// Profile API -> PgBouncer (DB queries)
CREATE (profileApi)-[:DEPENDS_ON {type: "sql"}]->(pgbouncer)

// Grade/Schedule -> PgBouncer (DB queries)
CREATE (gradeSchedule)-[:DEPENDS_ON {type: "sql"}]->(pgbouncer)

// PgBouncer -> PG Cluster (pooled connections)
CREATE (pgbouncer)-[:DEPENDS_ON {type: "sql"}]->(pgCluster)

// S1 List ETL -> PG Cluster (write)
CREATE (s1Etl)-[:DEPENDS_ON {type: "write"}]->(pgCluster)

// S2 List ETL -> PG Cluster (write)
CREATE (s2Etl)-[:DEPENDS_ON {type: "write"}]->(pgCluster)

// Profile API -> Kafka (event publishing)
CREATE (profileApi)-[:DEPENDS_ON {type: "event"}]->(kafka)

// Kafka -> S3 Service (data sink)
CREATE (kafka)-[:DEPENDS_ON {type: "sink"}]->(s3Service)

// S3 Service -> S3 Cluster (object storage)
CREATE (s3Service)-[:DEPENDS_ON {type: "storage"}]->(s3Cluster)

// Traefik -> S3 Cluster (static assets / direct access)
CREATE (traefik)-[:DEPENDS_ON {type: "http"}]->(s3Cluster)

// Traefik -> Gateway (routes API traffic)
CREATE (traefik)-[:DEPENDS_ON {type: "http"}]->(gateway)

// --- Done ---
// To verify, run separately:
//   MATCH (n:Component) RETURN n.name AS Component, n.layer AS Layer ORDER BY n.layer, n.name;
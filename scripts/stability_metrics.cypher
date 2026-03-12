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
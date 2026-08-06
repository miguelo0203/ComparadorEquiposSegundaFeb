# ==============================================================================
# FASE 4: MOTOR DE CLUSTERING Y ARQUETIPOS TÁCTICOS (MACHINE LEARNING NO SUPERVISADO)
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)

set.seed(42)

cat("=================================================================\n")
cat("      FASE 4: MOTOR DE CLUSTERING Y ARQUETIPOS (K-MEANS ENGINE)  \n")
cat("=================================================================\n\n")

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)
dbExecute(con, "SET search_path TO segunda_feb_pro, public;")

# ------------------------------------------------------------------------------
# 1. DDL: TABLA PLAYER_ARCHETYPES EN POSTGRESQL (IDEMPOTENTE)
# ------------------------------------------------------------------------------
cat("[1/4] Creando tabla segunda_feb_pro.player_archetypes...\n")

ddl_table <- "
CREATE TABLE IF NOT EXISTS segunda_feb_pro.player_archetypes (
    id_jugador INT NOT NULL,
    cluster_id INT NOT NULL,
    nombre_arquetipo VARCHAR(100) NOT NULL,
    descripcion_perfil TEXT NOT NULL,
    altura_cm NUMERIC(5,1),
    ppg_per40 NUMERIC(5,2) NOT NULL,
    rpg_per40 NUMERIC(5,2) NOT NULL,
    apg_per40 NUMERIC(5,2) NOT NULL,
    ts_pct NUMERIC(5,2) NOT NULL,
    usg_pct NUMERIC(5,2) NOT NULL,
    t3_ratio NUMERIC(5,2) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_player_archetypes PRIMARY KEY (id_jugador),
    CONSTRAINT fk_pa_jugador FOREIGN KEY (id_jugador) REFERENCES segunda_feb_pro.jugadores(id_jugador) ON DELETE CASCADE
);
"
dbExecute(con, ddl_table)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_pa_cluster ON segunda_feb_pro.player_archetypes(cluster_id);")

cat("  -> Tabla player_archetypes creada e indexada.\n")

# ------------------------------------------------------------------------------
# 2. CONSOLIDACIÓN DE FEATURES POR JUGADOR Y NORMALIZACIÓN
# ------------------------------------------------------------------------------
cat("[2/4] Consolidando vector de características de temporada...\n")

df_jugadores_season <- dbGetQuery(con, "
  SELECT 
    j.id_jugador,
    j.nombre_completo,
    COALESCE(j.puesto_posicion, 'Sin Posición') AS puesto_posicion,
    j.altura_cm,
    COUNT(bs.id_partido) AS partidos_jugados,
    ROUND(AVG(bs.minutos_decimal)::numeric, 2) AS min_pg,
    ROUND(AVG(pas.puntos_per40)::numeric, 2) AS ppg_per40,
    ROUND(AVG(pas.rebotes_per40)::numeric, 2) AS rpg_per40,
    ROUND(AVG(pas.asistencias_per40)::numeric, 2) AS apg_per40,
    ROUND(AVG(pas.ts_pct)::numeric, 2) AS ts_pct,
    ROUND(AVG(pas.usg_pct)::numeric, 2) AS usg_pct,
    SUM(bs.t2_intentados) AS t2i,
    SUM(bs.t3_intentados) AS t3i
  FROM segunda_feb_pro.jugadores j
  JOIN segunda_feb_pro.player_advanced_stats pas ON j.id_jugador = pas.id_jugador
  JOIN segunda_feb_pro.box_scores_raw bs ON pas.id_partido = bs.id_partido AND pas.id_jugador = bs.id_jugador
  WHERE pas.cumple_umbral = TRUE
  GROUP BY j.id_jugador, j.nombre_completo, j.puesto_posicion, j.altura_cm;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric)) %>%
  mutate(
    t3_ratio = if_else((t2i + t3i) > 0, round((t3i / (t2i + t3i)) * 100, 2), 0)
  )

# Imputación de altura para el vector de clustering si falta
altura_mediana_pos <- df_jugadores_season %>%
  group_by(puesto_posicion) %>%
  summarise(mediana_h = median(altura_cm, na.rm = TRUE), .groups = "drop")

df_clustering_data <- df_jugadores_season %>%
  left_join(altura_mediana_pos, by = "puesto_posicion") %>%
  mutate(
    altura_clean = if_else(is.na(altura_cm), if_else(is.na(mediana_h), 195, mediana_h), as.numeric(altura_cm))
  )

cat(sprintf("  -> Muestra del núcleo duro (Cumple Umbral): %d jugadores.\n", nrow(df_clustering_data)))

# ------------------------------------------------------------------------------
# 3. K-MEANS CLUSTERING (K = 6 ARQUETIPOS TÁCTICOS)
# ------------------------------------------------------------------------------
cat("[3/4] Ejecutando K-Means Clustering (K = 6 Arquetipos Tácticos)...\n")

features_matrix <- df_clustering_data %>%
  select(altura_clean, ppg_per40, rpg_per40, apg_per40, ts_pct, usg_pct, t3_ratio)

scaled_features <- scale(features_matrix)

km_model <- kmeans(scaled_features, centers = 6, nstart = 25)
df_clustering_data$cluster_id <- km_model$cluster

# Centroides no escalados
centroides_unscaled <- df_clustering_data %>%
  group_by(cluster_id) %>%
  summarise(
    n_jugadores = n(),
    altura_med = round(mean(altura_clean), 1),
    ppg40_med   = round(mean(ppg_per40), 1),
    rpg40_med   = round(mean(rpg_per40), 1),
    apg40_med   = round(mean(apg_per40), 1),
    ts_med      = round(mean(ts_pct), 1),
    usg_med     = round(mean(usg_pct), 1),
    t3_ratio_med= round(mean(t3_ratio), 1),
    .groups = "drop"
  )

cat("\nCentroides de los 6 Clústeres (Métricas Promedio No Escaladas):\n")
print(as.data.frame(centroides_unscaled), row.names = FALSE)

# Definición del diccionario táctico basado en la huella exacta de cada centroide
mapa_tactico <- list(
  "1" = list(
    nombre = "Rim Protector / Interior Físico",
    desc = "Pívot / Interior físico con alta tasa de rebotes por 40 min (10.5) y juego exclusivo en zona interior (10.1% triples)."
  ),
  "2" = list(
    nombre = "Point Guard / Director Creador",
    desc = "Base organizador especializado en generación de juego (6.1 asistencias/40) y volumen de tiro exterior."
  ),
  "3" = list(
    nombre = "3&D Wing / Alero Espaciador",
    desc = "Alero con buen equilibrio defensivo-reboteador (6.8 rebotes/40) y alta selección de tiro lejano (47.6% triples)."
  ),
  "4" = list(
    nombre = "Off-Ball Specialist / Especialista Catch & Shoot",
    desc = "Especialista exterior con el mayor volumen de tiros lejanos (63.1% de triples) y bajo volumen de uso."
  ),
  "5" = list(
    nombre = "Slashing Scorer / Percutor Anotador Primario",
    desc = "Anotador exterior dominante con la mayor tasa de uso (25.2% USG) y 19.4 puntos por 40 minutos."
  ),
  "6" = list(
    nombre = "Stretch Big / Pívot Abierto Físico",
    desc = "Pívot de gran envergadura (203.9 cm), alta eficiencia interior (15.1 pts, 9.0 reb/40) y amenaza lejana (27.0% triples)."
  )
)

df_clustering_data <- df_clustering_data %>%
  rowwise() %>%
  mutate(
    nombre_arquetipo = mapa_tactico[[as.character(cluster_id)]]$nombre,
    descripcion_perfil = mapa_tactico[[as.character(cluster_id)]]$desc
  ) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 4. PERSISTENCIA TRANSACCIONAL EN POSTGRESQL (UPSERT)
# ------------------------------------------------------------------------------
cat("\nVolcando asignaciones de arquetipos a segunda_feb_pro.player_archetypes...\n")

sql_upsert <- "
INSERT INTO segunda_feb_pro.player_archetypes (
  id_jugador, cluster_id, nombre_arquetipo, descripcion_perfil,
  altura_cm, ppg_per40, rpg_per40, apg_per40, ts_pct, usg_pct, t3_ratio
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
ON CONFLICT (id_jugador) DO UPDATE SET
  cluster_id = EXCLUDED.cluster_id,
  nombre_arquetipo = EXCLUDED.nombre_arquetipo,
  descripcion_perfil = EXCLUDED.descripcion_perfil,
  altura_cm = EXCLUDED.altura_cm,
  ppg_per40 = EXCLUDED.ppg_per40,
  rpg_per40 = EXCLUDED.rpg_per40,
  apg_per40 = EXCLUDED.apg_per40,
  ts_pct = EXCLUDED.ts_pct,
  usg_pct = EXCLUDED.usg_pct,
  t3_ratio = EXCLUDED.t3_ratio,
  creado_en = CURRENT_TIMESTAMP;
"

dbWithTransaction(con, {
  for (i in 1:nrow(df_clustering_data)) {
    r <- df_clustering_data[i, ]
    dbExecute(con, sql_upsert, params = list(
      r$id_jugador, r$cluster_id, r$nombre_arquetipo, r$descripcion_perfil,
      if(is.na(r$altura_cm)) NA else as.numeric(r$altura_cm),
      r$ppg_per40, r$rpg_per40, r$apg_per40, r$ts_pct, r$usg_pct, r$t3_ratio
    ))
  }
})

cat("  -> Arquetipos guardados correctamente en base de datos.\n")

# ------------------------------------------------------------------------------
# 5. VALIDACIÓN Y SANITY CHECK SQL
# ------------------------------------------------------------------------------
cat("\n[4/4] Consulta SQL de Validación: Muestra representativa de 2 jugadores por Arquetipo:\n")

df_sample_archetypes <- dbGetQuery(con, "
  WITH ranked_players AS (
    SELECT 
      pa.cluster_id,
      pa.nombre_arquetipo,
      j.nombre_completo AS jugador,
      COALESCE(j.puesto_posicion, 'Sin Posición') AS posicion_nominal,
      pa.altura_cm,
      pa.ppg_per40,
      pa.rpg_per40,
      pa.apg_per40,
      pa.t3_ratio,
      ROW_NUMBER() OVER (PARTITION BY pa.cluster_id ORDER BY pa.ppg_per40 DESC) AS rk
    FROM segunda_feb_pro.player_archetypes pa
    JOIN segunda_feb_pro.jugadores j ON pa.id_jugador = j.id_jugador
  )
  SELECT 
    cluster_id AS cid,
    nombre_arquetipo AS arquetipo_funcional,
    jugador,
    posicion_nominal AS pos_original,
    altura_cm AS alt,
    ppg_per40 AS pts40,
    rpg_per40 AS reb40,
    apg_per40 AS ast40,
    t3_ratio AS pct_t3_vol
  FROM ranked_players
  WHERE rk <= 2
  ORDER BY cluster_id, rk;
")

print(as.data.frame(df_sample_archetypes), row.names = FALSE)

dbDisconnect(con)

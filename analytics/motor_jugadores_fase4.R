# ==============================================================================
# FASE 4: MOTOR ANALÍTICO INDIVIDUAL (PLAYER SCOUTING ENGINE & ADVANCED STATS)
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)

cat("=================================================================\n")
cat("      FASE 4: MOTOR ANALÍTICO INDIVIDUAL (PLAYER SCOUTING ENGINE)\n")
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
# 1. DDL: TABLA PLAYER_ADVANCED_STATS EN POSTGRESQL (IDEMPOTENTE)
# ------------------------------------------------------------------------------
cat("[1/4] Creando tabla segunda_feb_pro.player_advanced_stats...\n")

ddl_table <- "
CREATE TABLE IF NOT EXISTS segunda_feb_pro.player_advanced_stats (
    id_partido INT NOT NULL,
    id_jugador INT NOT NULL,
    id_equipo INT NOT NULL,
    minutos_decimal NUMERIC(5,2) NOT NULL,
    puntos INT NOT NULL,
    valoracion INT NOT NULL,
    ts_pct NUMERIC(5,2) NOT NULL,
    efg_pct NUMERIC(5,2) NOT NULL,
    usg_pct NUMERIC(5,2) NOT NULL,
    puntos_per40 NUMERIC(5,2) NOT NULL,
    rebotes_per40 NUMERIC(5,2) NOT NULL,
    asistencias_per40 NUMERIC(5,2) NOT NULL,
    valoracion_per40 NUMERIC(5,2) NOT NULL,
    cumple_umbral BOOLEAN NOT NULL DEFAULT TRUE,
    pctil_valoracion NUMERIC(5,2) NOT NULL,
    pctil_ts_pct NUMERIC(5,2) NOT NULL,
    pctil_puntos NUMERIC(5,2) NOT NULL,
    pctil_rebotes NUMERIC(5,2) NOT NULL,
    pctil_asistencias NUMERIC(5,2) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_player_advanced_stats PRIMARY KEY (id_partido, id_jugador),
    CONSTRAINT fk_pas_partido FOREIGN KEY (id_partido) REFERENCES segunda_feb_pro.partidos(id_partido) ON DELETE CASCADE,
    CONSTRAINT fk_pas_jugador FOREIGN KEY (id_jugador) REFERENCES segunda_feb_pro.jugadores(id_jugador) ON DELETE CASCADE,
    CONSTRAINT fk_pas_equipo FOREIGN KEY (id_equipo) REFERENCES segunda_feb_pro.equipos(id_equipo) ON DELETE CASCADE
);
"
dbExecute(con, ddl_table)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_pas_jugador ON segunda_feb_pro.player_advanced_stats(id_jugador);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_pas_partido ON segunda_feb_pro.player_advanced_stats(id_partido);")

cat("  -> Tabla player_advanced_stats creada e indexada.\n")

# ------------------------------------------------------------------------------
# 2. CÁLCULO DE MÉTRICAS AVANZADAS POR PARTIDO Y JUGADOR
# ------------------------------------------------------------------------------
cat("[2/4] Calculando TS%, eFG%, USG%, Per-40 y Percentiles Posicionales...\n")

# A. Identificar jugadores que cumplen el umbral de muestra de la temporada (>=10 min/G y >=5 PJ)
df_umbral <- dbGetQuery(con, "
  SELECT 
    id_jugador,
    COUNT(id_partido) AS total_partidos,
    AVG(minutos_decimal) AS avg_minutos
  FROM segunda_feb_pro.box_scores_raw
  GROUP BY id_jugador;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric)) %>%
  mutate(cumple_umbral = (total_partidos >= 5) & (avg_minutos >= 10.0))

# B. Cargar box scores individuales con puesto_posicion y estadísticas de equipo
df_indiv <- dbGetQuery(con, "
  SELECT 
    bs.id_partido,
    bs.id_jugador,
    bs.id_equipo,
    COALESCE(j.puesto_posicion, 'Sin Posición') AS puesto_posicion,
    bs.minutos_decimal,
    bs.puntos,
    bs.valoracion,
    bs.rebotes_totales AS rebotes,
    bs.asistencias,
    bs.t2_anotados AS t2a, bs.t2_intentados AS t2i,
    bs.t3_anotados AS t3a, bs.t3_intentados AS t3i,
    bs.tl_anotados AS tla, bs.tl_intentados AS tli,
    bs.perdidas AS tov
  FROM segunda_feb_pro.box_scores_raw bs
  JOIN segunda_feb_pro.jugadores j ON bs.id_jugador = j.id_jugador;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# C. Agregados colectivos por equipo-partido para el cálculo de USG%
df_team_agg <- df_indiv %>%
  group_by(id_partido, id_equipo) %>%
  summarise(
    team_fga = sum(t2i + t3i),
    team_fta = sum(tli),
    team_tov = sum(tov),
    team_min = sum(minutos_decimal),
    .groups = "drop"
  )

# D. Ensamblar y calcular métricas individuales
df_calc <- df_indiv %>%
  inner_join(df_team_agg, by = c("id_partido", "id_equipo")) %>%
  left_join(df_umbral %>% select(id_jugador, cumple_umbral), by = "id_jugador") %>%
  mutate(
    cumple_umbral = if_else(is.na(cumple_umbral), FALSE, cumple_umbral),
    fga = t2i + t3i,
    fgm = t2a + t3a,
    
    # True Shooting %: PTS / (2 * (FGA + 0.44 * FTA)) * 100
    ts_pct = if_else((2 * (fga + 0.44 * tli)) > 0, (puntos / (2 * (fga + 0.44 * tli))) * 100, 0),
    
    # Effective Field Goal %: (FGM + 0.5 * 3PM) / FGA * 100
    efg_pct = if_else(fga > 0, ((fgm + 0.5 * t3a) / fga) * 100, 0),
    
    # Usage Rate %: 100 * ((FGA + 0.44 * FTA + TOV) * (Team_Min / 5)) / (Minutos * (Team_FGA + 0.44 * Team_FTA + Team_TOV))
    usg_pct = if_else(
      minutos_decimal > 0 & (team_fga + 0.44 * team_fta + team_tov) > 0,
      100 * ((fga + 0.44 * tli + tov) * (team_min / 5)) / (minutos_decimal * (team_fga + 0.44 * team_fta + team_tov)),
      0
    ),
    
    # Producción Per-40 Minutos
    puntos_per40 = if_else(minutos_decimal > 0, (puntos / minutos_decimal) * 40, 0),
    rebotes_per40 = if_else(minutos_decimal > 0, (rebotes / minutos_decimal) * 40, 0),
    asistencias_per40 = if_else(minutos_decimal > 0, (asistencias / minutos_decimal) * 40, 0),
    valoracion_per40 = if_else(minutos_decimal > 0, (valoracion / minutos_decimal) * 40, 0)
  )

# E. Cálculo de Estadística Robusta (Mediana y MAD) y Rangos Percentilares (0-100) por Posición Nominal
df_final <- df_calc %>%
  group_by(puesto_posicion) %>%
  mutate(
    pctil_valoracion = round(percent_rank(valoracion) * 100, 2),
    pctil_ts_pct     = round(percent_rank(ts_pct) * 100, 2),
    pctil_puntos     = round(percent_rank(puntos) * 100, 2),
    pctil_rebotes    = round(percent_rank(rebotes) * 100, 2),
    pctil_asistencias= round(percent_rank(asistencias) * 100, 2)
  ) %>%
  ungroup()

cat(sprintf("  -> %d registros individuales avanzados procesados.\n", nrow(df_final)))

# Summary report of robust statistics (Mediana & MAD) per position
df_robust_summary <- df_calc %>%
  filter(cumple_umbral == TRUE, puesto_posicion != 'Sin Posición') %>%
  group_by(puesto_posicion) %>%
  summarise(
    n_muestra = n(),
    mediana_val = median(valoracion),
    mad_val = mad(valoracion),
    mediana_ts = round(median(ts_pct), 1),
    mad_ts = round(mad(ts_pct), 1),
    mediana_pts40 = round(median(puntos_per40), 1),
    mad_pts40 = round(mad(puntos_per40), 1),
    .groups = "drop"
  )

cat("\nResumen de Estadística Robusta por Posición (Mediana & MAD):\n")
print(as.data.frame(df_robust_summary), row.names = FALSE)

# ------------------------------------------------------------------------------
# 3. PERSISTENCIA EN POSTGRESQL (TRANSACCIONAL UPSERT)
# ------------------------------------------------------------------------------
cat("\n[3/4] Volcando datos a segunda_feb_pro.player_advanced_stats via UPSERT...\n")

sql_upsert <- "
INSERT INTO segunda_feb_pro.player_advanced_stats (
  id_partido, id_jugador, id_equipo, minutos_decimal, puntos, valoracion,
  ts_pct, efg_pct, usg_pct, puntos_per40, rebotes_per40, asistencias_per40, valoracion_per40,
  cumple_umbral, pctil_valoracion, pctil_ts_pct, pctil_puntos, pctil_rebotes, pctil_asistencias
) VALUES (
  $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
)
ON CONFLICT (id_partido, id_jugador) DO UPDATE SET
  id_equipo = EXCLUDED.id_equipo,
  minutos_decimal = EXCLUDED.minutos_decimal,
  puntos = EXCLUDED.puntos,
  valoracion = EXCLUDED.valoracion,
  ts_pct = EXCLUDED.ts_pct,
  efg_pct = EXCLUDED.efg_pct,
  usg_pct = EXCLUDED.usg_pct,
  puntos_per40 = EXCLUDED.puntos_per40,
  rebotes_per40 = EXCLUDED.rebotes_per40,
  asistencias_per40 = EXCLUDED.asistencias_per40,
  valoracion_per40 = EXCLUDED.valoracion_per40,
  cumple_umbral = EXCLUDED.cumple_umbral,
  pctil_valoracion = EXCLUDED.pctil_valoracion,
  pctil_ts_pct = EXCLUDED.pctil_ts_pct,
  pctil_puntos = EXCLUDED.pctil_puntos,
  pctil_rebotes = EXCLUDED.pctil_rebotes,
  pctil_asistencias = EXCLUDED.pctil_asistencias,
  creado_en = CURRENT_TIMESTAMP;
"

dbWithTransaction(con, {
  for (i in 1:nrow(df_final)) {
    r <- df_final[i, ]
    dbExecute(con, sql_upsert, params = list(
      r$id_partido, r$id_jugador, r$id_equipo, round(r$minutos_decimal, 2), r$puntos, r$valoracion,
      round(r$ts_pct, 2), round(r$efg_pct, 2), round(r$usg_pct, 2),
      round(r$puntos_per40, 2), round(r$rebotes_per40, 2), round(r$asistencias_per40, 2), round(r$valoracion_per40, 2),
      r$cumple_umbral, round(r$pctil_valoracion, 2), round(r$pctil_ts_pct, 2),
      round(r$pctil_puntos, 2), round(r$pctil_rebotes, 2), round(r$pctil_asistencias, 2)
    ))
  }
})

cat("  -> Persistencia completada con éxito.\n")

# ------------------------------------------------------------------------------
# 4. VALIDACIÓN Y SANITY CHECK SQL
# ------------------------------------------------------------------------------
cat("\n[4/4] Validación y Sanity Check SQL sobre player_advanced_stats...\n")

df_sample <- dbGetQuery(con, "
  SELECT 
    pas.id_partido,
    j.nombre_completo AS jugador,
    COALESCE(j.puesto_posicion, 'Sin Posición') AS posicion,
    pas.minutos_decimal AS min,
    pas.puntos AS pts,
    pas.ts_pct,
    pas.valoracion_per40 AS val_per40,
    pas.pctil_valoracion AS pctil_val,
    pas.pctil_ts_pct AS pctil_ts
  FROM segunda_feb_pro.player_advanced_stats pas
  JOIN segunda_feb_pro.jugadores j ON pas.id_jugador = j.id_jugador
  WHERE pas.cumple_umbral = TRUE AND pas.minutos_decimal >= 20
  ORDER BY pas.valoracion_per40 DESC
  LIMIT 5;
")

cat("\nMuestra de 5 Registros de Validación (Jugadores Destacados con >= 20 min):\n")
print(as.data.frame(df_sample), row.names = FALSE)

dbDisconnect(con)

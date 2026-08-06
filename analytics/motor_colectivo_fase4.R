# ==============================================================================
# FASE 4: MOTOR ANALÍTICO COLECTIVO (TEAM MATCHUP ENGINE & FOUR FACTORS)
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)

cat("=================================================================\n")
cat("      FASE 4: MOTOR ANALÍTICO COLECTIVO (DEAN OLIVER FOUR FACTORS)\n")
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
# 1. DDL: TABLA TEAM_ADVANCED_STATS EN POSTGRESQL
# ------------------------------------------------------------------------------
cat("[1/4] Creando tabla segunda_feb_pro.team_advanced_stats (Idempotente)...\n")

ddl_table <- "
CREATE TABLE IF NOT EXISTS segunda_feb_pro.team_advanced_stats (
    id_partido INT NOT NULL,
    id_equipo INT NOT NULL,
    id_equipo_rival INT NOT NULL,
    es_local BOOLEAN NOT NULL,
    puntos_favor INT NOT NULL,
    puntos_contra INT NOT NULL,
    posesiones NUMERIC(6,2) NOT NULL,
    posesiones_rival NUMERIC(6,2) NOT NULL,
    pace NUMERIC(6,2) NOT NULL,
    ortg NUMERIC(6,2) NOT NULL,
    drtg NUMERIC(6,2) NOT NULL,
    net_rating NUMERIC(6,2) NOT NULL,
    efg_pct NUMERIC(5,2) NOT NULL,
    tov_pct NUMERIC(5,2) NOT NULL,
    oreb_pct NUMERIC(5,2) NOT NULL,
    dreb_pct NUMERIC(5,2) NOT NULL,
    ft_rate NUMERIC(5,2) NOT NULL,
    efg_pct_oponente NUMERIC(5,2) NOT NULL,
    tov_pct_oponente NUMERIC(5,2) NOT NULL,
    oreb_pct_oponente NUMERIC(5,2) NOT NULL,
    ft_rate_oponente NUMERIC(5,2) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_team_advanced_stats PRIMARY KEY (id_partido, id_equipo),
    CONSTRAINT fk_tas_partido FOREIGN KEY (id_partido) REFERENCES segunda_feb_pro.partidos(id_partido) ON DELETE CASCADE,
    CONSTRAINT fk_tas_equipo FOREIGN KEY (id_equipo) REFERENCES segunda_feb_pro.equipos(id_equipo) ON DELETE CASCADE,
    CONSTRAINT fk_tas_rival FOREIGN KEY (id_equipo_rival) REFERENCES segunda_feb_pro.equipos(id_equipo) ON DELETE CASCADE
);
"
dbExecute(con, ddl_table)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_tas_equipo ON segunda_feb_pro.team_advanced_stats(id_equipo);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_tas_partido ON segunda_feb_pro.team_advanced_stats(id_partido);")

cat("  -> Tabla team_advanced_stats lista e indexada.\n")

# ------------------------------------------------------------------------------
# 2. EXTRACCIÓN Y CÁLCULO DE MÉTRICAS AVANZADAS
# ------------------------------------------------------------------------------
cat("[2/4] Extrayendo estadísticas colectivas y calculando Four Factors...\n")

df_raw <- dbGetQuery(con, "
  SELECT 
    bs.id_partido,
    bs.id_equipo,
    SUM(bs.puntos) AS pts,
    SUM(bs.t2_anotados) AS t2a,
    SUM(bs.t2_intentados) AS t2i,
    SUM(bs.t3_anotados) AS t3a,
    SUM(bs.t3_intentados) AS t3i,
    SUM(bs.tl_anotados) AS tla,
    SUM(bs.tl_intentados) AS tli,
    SUM(bs.rebotes_ofensivos) AS oreb,
    SUM(bs.rebotes_defensivos) AS dreb,
    SUM(bs.rebotes_totales) AS treb,
    SUM(bs.asistencias) AS ast,
    SUM(bs.perdidas) AS tov,
    SUM(bs.recuperaciones) AS stl,
    SUM(bs.tapones) AS blk,
    SUM(bs.faltas_cometidas) AS pf
  FROM segunda_feb_pro.box_scores_raw bs
  GROUP BY bs.id_partido, bs.id_equipo;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# Obtener los pares de partido para cruzar con el rival y condición de localía
df_partidos <- dbGetQuery(con, "
  SELECT id_partido, id_equipo_local, id_equipo_visitante
  FROM segunda_feb_pro.partidos;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# Unir con el rival en cada encuentro
df_equipo_match <- bind_rows(
  df_partidos %>% select(id_partido, id_equipo = id_equipo_local, id_equipo_rival = id_equipo_visitante) %>% mutate(es_local = TRUE),
  df_partidos %>% select(id_partido, id_equipo = id_equipo_visitante, id_equipo_rival = id_equipo_local) %>% mutate(es_local = FALSE)
)

df_joint <- df_equipo_match %>%
  inner_join(df_raw, by = c("id_partido", "id_equipo")) %>%
  inner_join(
    df_raw, 
    by = c("id_partido" = "id_partido", "id_equipo_rival" = "id_equipo"),
    suffix = c("", "_opp")
  )

# Cálculo formal de Four Factors y Métricas Colectivas
df_advanced <- df_joint %>%
  mutate(
    fga = t2i + t3i,
    fgm = t2a + t3a,
    fga_opp = t2i_opp + t3i_opp,
    fgm_opp = t2a_opp + t3a_opp,
    
    # 1. Posesiones (Dean Oliver Formula: FGA + 0.44 * FTA + TOV - OREB)
    poss = fga + 0.44 * tli + tov - oreb,
    poss_opp = fga_opp + 0.44 * tli_opp + tov_opp - oreb_opp,
    pace = (poss + poss_opp) / 2,
    
    # 2. Four Factors Ofensivos
    efg_pct = if_else(fga > 0, ((fgm + 0.5 * t3a) / fga) * 100, 0),
    tov_pct = if_else((fga + 0.44 * tli + tov) > 0, (tov / (fga + 0.44 * tli + tov)) * 100, 0),
    oreb_pct = if_else((oreb + dreb_opp) > 0, (oreb / (oreb + dreb_opp)) * 100, 0),
    dreb_pct = if_else((dreb + oreb_opp) > 0, (dreb / (dreb + oreb_opp)) * 100, 0),
    ft_rate = if_else(fga > 0, (tli / fga) * 100, 0),
    
    # Four Factors Defensivos (Oponente)
    efg_pct_opp = if_else(fga_opp > 0, ((fgm_opp + 0.5 * t3a_opp) / fga_opp) * 100, 0),
    tov_pct_opp = if_else((fga_opp + 0.44 * tli_opp + tov_opp) > 0, (tov_opp / (fga_opp + 0.44 * tli_opp + tov_opp)) * 100, 0),
    oreb_pct_opp = if_else((oreb_opp + dreb) > 0, (oreb_opp / (oreb_opp + dreb)) * 100, 0),
    ft_rate_opp = if_else(fga_opp > 0, (tli_opp / fga_opp) * 100, 0),
    
    # 3. Eficiencias Ajustadas
    ortg = if_else(poss > 0, (pts / poss) * 100, 0),
    drtg = if_else(poss_opp > 0, (pts_opp / poss_opp) * 100, 0),
    net_rating = ortg - drtg
  ) %>%
  select(
    id_partido, id_equipo, id_equipo_rival, es_local,
    puntos_favor = pts, puntos_contra = pts_opp,
    posesiones = poss, posesiones_rival = poss_opp, pace,
    ortg, drtg, net_rating,
    efg_pct, tov_pct, oreb_pct, dreb_pct, ft_rate,
    efg_pct_oponente = efg_pct_opp,
    tov_pct_oponente = tov_pct_opp,
    oreb_pct_oponente = oreb_pct_opp,
    ft_rate_oponente = ft_rate_opp
  )

cat(sprintf("  -> %d registros calculados correctamente.\n", nrow(df_advanced)))

# ------------------------------------------------------------------------------
# 3. PERSISTENCIA TRANSACCIONAL EN POSTGRESQL (UPSERT)
# ------------------------------------------------------------------------------
cat("[3/4] Volcando registros a segunda_feb_pro.team_advanced_stats via UPSERT...\n")

sql_upsert <- "
INSERT INTO segunda_feb_pro.team_advanced_stats (
  id_partido, id_equipo, id_equipo_rival, es_local, puntos_favor, puntos_contra,
  posesiones, posesiones_rival, pace, ortg, drtg, net_rating,
  efg_pct, tov_pct, oreb_pct, dreb_pct, ft_rate,
  efg_pct_oponente, tov_pct_oponente, oreb_pct_oponente, ft_rate_oponente
) VALUES (
  $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21
)
ON CONFLICT (id_partido, id_equipo) DO UPDATE SET
  id_equipo_rival = EXCLUDED.id_equipo_rival,
  es_local = EXCLUDED.es_local,
  puntos_favor = EXCLUDED.puntos_favor,
  puntos_contra = EXCLUDED.puntos_contra,
  posesiones = EXCLUDED.posesiones,
  posesiones_rival = EXCLUDED.posesiones_rival,
  pace = EXCLUDED.pace,
  ortg = EXCLUDED.ortg,
  drtg = EXCLUDED.drtg,
  net_rating = EXCLUDED.net_rating,
  efg_pct = EXCLUDED.efg_pct,
  tov_pct = EXCLUDED.tov_pct,
  oreb_pct = EXCLUDED.oreb_pct,
  dreb_pct = EXCLUDED.dreb_pct,
  ft_rate = EXCLUDED.ft_rate,
  efg_pct_oponente = EXCLUDED.efg_pct_oponente,
  tov_pct_oponente = EXCLUDED.tov_pct_oponente,
  oreb_pct_oponente = EXCLUDED.oreb_pct_oponente,
  ft_rate_oponente = EXCLUDED.ft_rate_oponente,
  creado_en = CURRENT_TIMESTAMP;
"

dbWithTransaction(con, {
  for (i in 1:nrow(df_advanced)) {
    r <- df_advanced[i, ]
    dbExecute(con, sql_upsert, params = list(
      r$id_partido, r$id_equipo, r$id_equipo_rival, r$es_local, r$puntos_favor, r$puntos_contra,
      round(r$posesiones, 2), round(r$posesiones_rival, 2), round(r$pace, 2),
      round(r$ortg, 2), round(r$drtg, 2), round(r$net_rating, 2),
      round(r$efg_pct, 2), round(r$tov_pct, 2), round(r$oreb_pct, 2), round(r$dreb_pct, 2), round(r$ft_rate, 2),
      round(r$efg_pct_oponente, 2), round(r$tov_pct_oponente, 2), round(r$oreb_pct_oponente, 2), round(r$ft_rate_oponente, 2)
    ))
  }
})

cat("  -> Persistencia completada con éxito.\n")

# ------------------------------------------------------------------------------
# 4. VALIDACIÓN Y SANITY CHECK SQL
# ------------------------------------------------------------------------------
cat("\n[4/4] Validación y Sanity Check SQL sobre team_advanced_stats...\n")

df_sample <- dbGetQuery(con, "
  SELECT 
    tas.id_partido,
    e.nombre_oficial AS equipo,
    er.nombre_oficial AS rival,
    tas.es_local,
    tas.puntos_favor AS pts,
    tas.puntos_contra AS pts_opp,
    tas.pace,
    tas.ortg,
    tas.drtg,
    tas.net_rating AS net_rtg,
    tas.efg_pct,
    tas.tov_pct,
    tas.oreb_pct,
    tas.ft_rate
  FROM segunda_feb_pro.team_advanced_stats tas
  JOIN segunda_feb_pro.equipos e ON tas.id_equipo = e.id_equipo
  JOIN segunda_feb_pro.equipos er ON tas.id_equipo_rival = er.id_equipo
  ORDER BY tas.id_partido DESC, tas.es_local DESC
  LIMIT 5;
")

cat("\nMuestra de 5 Registros de Validación:\n")
print(as.data.frame(df_sample), row.names = FALSE)

# Estadísticos globales para validar rangos biológicos
df_stats_global <- dbGetQuery(con, "
  SELECT 
    COUNT(*) AS total_registros,
    ROUND(MIN(pace), 2) AS min_pace,
    ROUND(AVG(pace), 2) AS avg_pace,
    ROUND(MAX(pace), 2) AS max_pace,
    ROUND(MIN(ortg), 2) AS min_ortg,
    ROUND(AVG(ortg), 2) AS avg_ortg,
    ROUND(MAX(ortg), 2) AS max_ortg,
    ROUND(AVG(efg_pct), 2) AS avg_efg_pct,
    ROUND(AVG(tov_pct), 2) AS avg_tov_pct,
    ROUND(AVG(oreb_pct), 2) AS avg_oreb_pct
  FROM segunda_feb_pro.team_advanced_stats;
")

cat("\nResumen Estadístico Global de Validación:\n")
print(as.data.frame(df_stats_global), row.names = FALSE)

dbDisconnect(con)

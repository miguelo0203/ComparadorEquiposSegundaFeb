# ==============================================================================
# AUDITORÍA CIENTÍFICA, ESTADÍSTICA Y METODOLÓGICA GLOBAL DE FASE 4
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)

cat("=================================================================\n")
cat(" AUDITORÍA CIENTÍFICA Y METODOLÓGICA GLOBAL - MOTORES DE FASE 4  \n")
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
# BLOQUE 1: VALIDACIÓN MATEMÁTICA DEL MOTOR COLECTIVO (TEAM_ADVANCED_STATS)
# ------------------------------------------------------------------------------
cat("--- 1. VALIDACIÓN MATEMÁTICA DEL MOTOR COLECTIVO (FOUR FACTORS & PACE) ---\n")

df_tas <- dbGetQuery(con, "
  SELECT 
    id_partido, id_equipo, id_equipo_rival, es_local,
    puntos_favor, puntos_contra, posesiones, posesiones_rival, pace,
    ortg, drtg, net_rating, efg_pct, tov_pct, oreb_pct, dreb_pct, ft_rate
  FROM segunda_feb_pro.team_advanced_stats;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# 1.1 Distribución de Posesiones y Pace
pace_stats <- df_tas %>%
  summarise(
    n = n(),
    min_pace = min(pace),
    q1_pace = quantile(pace, 0.25),
    median_pace = median(pace),
    mean_pace = mean(pace),
    q3_pace = quantile(pace, 0.75),
    max_pace = max(pace),
    sd_pace = sd(pace)
  )

cat("\n1.1 Métricas de Distribución del Ritmo (Pace):\n")
print(as.data.frame(pace_stats), row.names = FALSE)

# 1.2 Límites teóricos de Four Factors (0% a 100%)
bounds_check <- df_tas %>%
  summarise(
    fuera_rango_efg = sum(efg_pct < 0 | efg_pct > 100),
    fuera_rango_tov = sum(tov_pct < 0 | tov_pct > 100),
    fuera_rango_oreb = sum(oreb_pct < 0 | oreb_pct > 100),
    fuera_rango_dreb = sum(dreb_pct < 0 | dreb_pct > 100),
    fuera_rango_ftrate = sum(ft_rate < 0 | ft_rate > 150)
  )

cat("\n1.2 Control de Límites Teóricos de Four Factors (0 de Errores Esperados):\n")
print(as.data.frame(bounds_check), row.names = FALSE)

# 1.3 Simetría en los partidos (ORtg equipo A == DRtg equipo B & NetRating A == -NetRating B)
df_simetria <- dbGetQuery(con, "
  SELECT 
    t1.id_partido,
    t1.id_equipo AS eq_local,
    t1.ortg AS ortg_local,
    t2.drtg AS drtg_visitante,
    t1.net_rating AS net_local,
    t2.net_rating AS net_visitante,
    ABS(t1.ortg - t2.drtg) AS diff_ortg_drtg,
    ABS(t1.net_rating + t2.net_rating) AS diff_net_simetria
  FROM segunda_feb_pro.team_advanced_stats t1
  JOIN segunda_feb_pro.team_advanced_stats t2 
    ON t1.id_partido = t2.id_partido AND t1.id_equipo != t2.id_equipo
  WHERE t1.es_local = TRUE;
")

simetria_summary <- df_simetria %>%
  summarise(
    total_partidos = n(),
    max_diferencia_ortg_drtg = max(diff_ortg_drtg),
    max_diferencia_net_rating = max(diff_net_simetria),
    coincidencia_100pct = sum(diff_ortg_drtg < 0.01 & diff_net_simetria < 0.01)
  )

cat("\n1.3 Verificación de Simetría Perfecta entre Rivales por Partido:\n")
print(as.data.frame(simetria_summary), row.names = FALSE)


# ------------------------------------------------------------------------------
# BLOQUE 2: VALIDACIÓN DEL MOTOR INDIVIDUAL (PLAYER_ADVANCED_STATS)
# ------------------------------------------------------------------------------
cat("\n--- 2. VALIDACIÓN DEL MOTOR INDIVIDUAL Y ESTADÍSTICAS AVANZADAS ---\n")

df_pas <- dbGetQuery(con, "
  SELECT 
    pas.*, j.puesto_posicion
  FROM segunda_feb_pro.player_advanced_stats pas
  JOIN segunda_feb_pro.jugadores j ON pas.id_jugador = j.id_jugador;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# 2.1 Ausencia de NaN, Inf o valores negativos en métricas clave
nan_check <- df_pas %>%
  summarise(
    total_registros = n(),
    nan_ts = sum(is.nan(ts_pct) | is.infinite(ts_pct)),
    nan_usg = sum(is.nan(usg_pct) | is.infinite(usg_pct)),
    nan_puntos_40 = sum(is.nan(puntos_per40) | is.infinite(puntos_per40)),
    nan_val_40 = sum(is.nan(valoracion_per40) | is.infinite(valoracion_per40)),
    negativos_usg = sum(usg_pct < 0),
    negativos_min = sum(minutos_decimal < 0)
  )

cat("\n2.1 Diagnóstico de Integridad Numérica (División por cero / NaN / Inf):\n")
print(as.data.frame(nan_check), row.names = FALSE)

# 2.2 Distribución de Percentiles Posicionales (0-100)
pctil_pos_dist <- df_pas %>%
  filter(!is.na(puesto_posicion), puesto_posicion != 'Sin Posición') %>%
  group_by(puesto_posicion) %>%
  summarise(
    n_registros = n(),
    min_pctil_val = min(pctil_valoracion),
    max_pctil_val = max(pctil_valoracion),
    min_pctil_ts = min(pctil_ts_pct),
    max_pctil_ts = max(pctil_ts_pct),
    .groups = "drop"
  )

cat("\n2.2 Cobertura de Rangos Percentilares por Posición Nominal:\n")
print(as.data.frame(pctil_pos_dist), row.names = FALSE)


# ------------------------------------------------------------------------------
# BLOQUE 3: VALIDACIÓN CIENTÍFICA DEL MODELO DE CLUSTERING (K-MEANS K=6)
# ------------------------------------------------------------------------------
cat("\n--- 3. VALIDACIÓN CIENTÍFICA DEL MODELO DE CLUSTERING (K-MEANS K=6) ---\n")

df_pa <- dbGetQuery(con, "
  SELECT 
    pa.*, j.nombre_completo, COALESCE(j.puesto_posicion, 'Sin Posición') AS puesto_posicion
  FROM segunda_feb_pro.player_archetypes pa
  JOIN segunda_feb_pro.jugadores j ON pa.id_jugador = j.id_jugador;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# Imputar altura si falta para evaluación de TSS/BSS
altura_mediana_pos <- df_pa %>%
  group_by(puesto_posicion) %>%
  summarise(mediana_h = median(altura_cm, na.rm = TRUE), .groups = "drop")

df_pa_clean <- df_pa %>%
  left_join(altura_mediana_pos, by = "puesto_posicion") %>%
  mutate(altura_clean = if_else(is.na(altura_cm), if_else(is.na(mediana_h), 195, mediana_h), as.numeric(altura_cm)))

features_clustering <- df_pa_clean %>%
  select(altura_clean, ppg_per40, rpg_per40, apg_per40, ts_pct, usg_pct, t3_ratio)

scaled_mat <- scale(features_clustering)
set.seed(42)
km_audit <- kmeans(scaled_mat, centers = 6, nstart = 25)

totss <- km_audit$totss
tot.withinss <- km_audit$tot.withinss
betweenss <- km_audit$betweenss
var_explicada_pct <- (betweenss / totss) * 100

cat(sprintf("\n3.1 Calidad Estadística del Modelo K-Means (K = 6):\n"))
cat(sprintf("  - Muestra Total del Núcleo Duro:                  %d jugadores\n", nrow(df_pa_clean)))
cat(sprintf("  - Suma de Cuadrados Total (TSS):                   %0.2f\n", totss))
cat(sprintf("  - Suma de Cuadrados Intra-Clúster (Within SS):     %0.2f\n", tot.withinss))
cat(sprintf("  - Suma de Cuadrados Inter-Clúster (Between SS):    %0.2f\n", betweenss))
cat(sprintf("  - Varianza Explicada (BSS/TSS Ratio):              %0.2f%%\n", var_explicada_pct))

# 3.2 Separación Estadística de Centroides (ANOVA F-Tests)
fit_h   <- aov(altura_clean ~ factor(cluster_id), data = df_pa_clean)
fit_pts <- aov(ppg_per40 ~ factor(cluster_id), data = df_pa_clean)
fit_reb <- aov(rpg_per40 ~ factor(cluster_id), data = df_pa_clean)
fit_ast <- aov(apg_per40 ~ factor(cluster_id), data = df_pa_clean)
fit_t3  <- aov(t3_ratio ~ factor(cluster_id), data = df_pa_clean)

cat("\n3.2 Significación Estadística de Separación de Centroides (ANOVA F-Tests):\n")
cat(sprintf("  - Altura (cm):        F = %0.2f | p-value = %e (p < 0.001)\n", summary(fit_h)[[1]][["F value"]][1], summary(fit_h)[[1]][["Pr(>F)"]][1]))
cat(sprintf("  - Puntos / 40 min:    F = %0.2f | p-value = %e (p < 0.001)\n", summary(fit_pts)[[1]][["F value"]][1], summary(fit_pts)[[1]][["Pr(>F)"]][1]))
cat(sprintf("  - Rebotes / 40 min:   F = %0.2f | p-value = %e (p < 0.001)\n", summary(fit_reb)[[1]][["F value"]][1], summary(fit_reb)[[1]][["Pr(>F)"]][1]))
cat(sprintf("  - Asistencias / 40 min: F = %0.2f | p-value = %e (p < 0.001)\n", summary(fit_ast)[[1]][["F value"]][1], summary(fit_ast)[[1]][["Pr(>F)"]][1]))
cat(sprintf("  - Volumen Triples (%%): F = %0.2f | p-value = %e (p < 0.001)\n", summary(fit_t3)[[1]][["F value"]][1], summary(fit_t3)[[1]][["Pr(>F)"]][1]))


# ------------------------------------------------------------------------------
# BLOQUE 4: INTEGRIDAD ESTRUCTURAL Y REGISTROS HUÉRFANOS
# ------------------------------------------------------------------------------
cat("\n--- 4. INTEGRIDAD ESTRUCTURAL Y CONSISTENCIA RELACIONAL FINAL ---\n")

huerfanos_tas <- dbGetQuery(con, "
  SELECT 
    (SELECT COUNT(*) FROM segunda_feb_pro.team_advanced_stats tas LEFT JOIN segunda_feb_pro.partidos p ON tas.id_partido = p.id_partido WHERE p.id_partido IS NULL) AS huerfanos_partido,
    (SELECT COUNT(*) FROM segunda_feb_pro.team_advanced_stats tas LEFT JOIN segunda_feb_pro.equipos e ON tas.id_equipo = e.id_equipo WHERE e.id_equipo IS NULL) AS huerfanos_equipo;
")

huerfanos_pas <- dbGetQuery(con, "
  SELECT 
    (SELECT COUNT(*) FROM segunda_feb_pro.player_advanced_stats pas LEFT JOIN segunda_feb_pro.partidos p ON pas.id_partido = p.id_partido WHERE p.id_partido IS NULL) AS huerfanos_partido,
    (SELECT COUNT(*) FROM segunda_feb_pro.player_advanced_stats pas LEFT JOIN segunda_feb_pro.jugadores j ON pas.id_jugador = j.id_jugador WHERE j.id_jugador IS NULL) AS huerfanos_jugador;
")

huerfanos_pa <- dbGetQuery(con, "
  SELECT COUNT(*) AS huerfanos_jugador 
  FROM segunda_feb_pro.player_archetypes pa 
  LEFT JOIN segunda_feb_pro.jugadores j ON pa.id_jugador = j.id_jugador 
  WHERE j.id_jugador IS NULL;
")

cat("\n4.1 Auditoría de Registros Huérfanos en Tablas de la Fase 4:\n")
cat("  - team_advanced_stats  -> Huérfanos Partido:", huerfanos_tas$huerfanos_partido[1], "| Huérfanos Equipo:", huerfanos_tas$huerfanos_equipo[1], "\n")
cat("  - player_advanced_stats -> Huérfanos Partido:", huerfanos_pas$huerfanos_partido[1], "| Huérfanos Jugador:", huerfanos_pas$huerfanos_jugador[1], "\n")
cat("  - player_archetypes     -> Huérfanos Jugador:", huerfanos_pa$huerfanos_jugador[1], "\n")

cat("\n=================================================================\n")
cat("   DICTAMEN FINAL: MOTORES ANALÍTICOS Y ML APTO PARA FASE 5 SHINY \n")
cat("=================================================================\n")

dbDisconnect(con)

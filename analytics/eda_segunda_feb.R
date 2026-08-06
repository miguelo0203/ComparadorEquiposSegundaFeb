# ==============================================================================
# FASE 3: ANÁLISIS EXPLORATORIO DE DATOS (EDA) Y FACTORES DE ÉXITO EN SEGUNDA FEB
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

cat("=================================================================\n")
cat("      FASE 3: ANÁLISIS EXPLORATORIO DE DATOS (SEGUNDA FEB PRO)   \n")
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
# BLOQUE 1: FACTORES DE VICTORIA A NIVEL COLECTIVO (CORRELACIÓN DE PEARSON)
# ------------------------------------------------------------------------------
cat("--- BLOQUE 1: FACTORES DE VICTORIA Y CORRELACIÓN A NIVEL EQUIPO ---\n")

df_partidos_equipo <- dbGetQuery(con, "
  WITH stats_equipo_partido AS (
    SELECT 
      bs.id_partido,
      bs.id_equipo,
      SUM(bs.puntos) AS puntos,
      SUM(bs.asistencias) AS asistencias,
      SUM(bs.perdidas) AS perdidas,
      SUM(bs.recuperaciones) AS recuperaciones,
      SUM(bs.rebotes_ofensivos) AS rebotes_ofensivos,
      SUM(bs.rebotes_defensivos) AS rebotes_defensivos,
      SUM(bs.rebotes_totales) AS rebotes_totales,
      SUM(bs.t2_anotados) AS t2_anotados,
      SUM(bs.t2_intentados) AS t2_intentados,
      SUM(bs.t3_anotados) AS t3_anotados,
      SUM(bs.t3_intentados) AS t3_intentados,
      SUM(bs.tl_anotados) AS tl_anotados,
      SUM(bs.tl_intentados) AS tl_intentados,
      SUM(bs.valoracion) AS valoracion,
      SUM(bs.faltas_cometidas) AS faltas_cometidas,
      SUM(bs.tapones) AS tapones
    FROM segunda_feb_pro.box_scores_raw bs
    GROUP BY bs.id_partido, bs.id_equipo
  )
  SELECT 
    sep.*,
    p.id_equipo_local,
    p.id_equipo_visitante,
    p.puntos_local,
    p.puntos_visitante,
    CASE 
      WHEN sep.id_equipo = p.id_equipo_local AND p.puntos_local > p.puntos_visitante THEN 1
      WHEN sep.id_equipo = p.id_equipo_visitante AND p.puntos_visitante > p.puntos_local THEN 1
      ELSE 0
    END AS victoria,
    CASE 
      WHEN sep.id_equipo = p.id_equipo_local THEN p.puntos_local - p.puntos_visitante
      ELSE p.puntos_visitante - p.puntos_local
    END AS diferencial_puntos
  FROM stats_equipo_partido sep
  JOIN segunda_feb_pro.partidos p ON sep.id_partido = p.id_partido;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

df_factores <- df_partidos_equipo %>%
  mutate(
    pct_t2 = if_else(t2_intentados > 0, (t2_anotados / t2_intentados) * 100, 0),
    pct_t3 = if_else(t3_intentados > 0, (t3_anotados / t3_intentados) * 100, 0),
    pct_tl = if_else(tl_intentados > 0, (tl_anotados / tl_intentados) * 100, 0),
    eFG_pct = if_else((t2_intentados + t3_intentados) > 0, 
                      ((t2_anotados + 1.5 * t3_anotados) / (t2_intentados + t3_intentados)) * 100, 0),
    TS_pct = if_else((2 * (t2_intentados + t3_intentados + 0.44 * tl_intentados)) > 0,
                     (puntos / (2 * (t2_intentados + t3_intentados + 0.44 * tl_intentados))) * 100, 0),
    ratio_ast_to = if_else(perdidas > 0, asistencias / perdidas, asistencias),
    posesiones_est = (t2_intentados + t3_intentados) + 0.44 * tl_intentados + perdidas - rebotes_ofensivos,
    off_rating = if_else(posesiones_est > 0, (puntos / posesiones_est) * 100, 0)
  )

# Matriz de correlación con la variable de victoria
cor_mat <- df_factores %>%
  select(
    victoria, diferencial_puntos, valoracion, off_rating, TS_pct, eFG_pct,
    puntos, pct_t2, pct_t3, pct_tl, asistencias, ratio_ast_to,
    rebotes_defensivos, recuperaciones, rebotes_totales, rebotes_ofensivos,
    tapones, perdidas, faltas_cometidas
  )

cor_victoria <- sapply(cor_mat, function(col) cor(col, cor_mat$victoria, use = "complete.obs"))

df_ranking_cor <- tibble(
  metrica = names(cor_victoria),
  correlacion_pearson = as.numeric(cor_victoria)
) %>%
  filter(metrica != "victoria") %>%
  arrange(desc(abs(correlacion_pearson)))

cat("Ranking de Métricas por Correlación con la Victoria (Pearson r):\n")
print(as.data.frame(df_ranking_cor), row.names = FALSE)


# ------------------------------------------------------------------------------
# BLOQUE 2: ANÁLISIS DEMOGRÁFICO Y POSICIONAL (OUTPUT VS FÍSICO)
# ------------------------------------------------------------------------------
cat("\n--- BLOQUE 2: ANÁLISIS DEMOGRÁFICO Y POSICIONAL (OUTPUT VS FÍSICO) ---\n")

df_jugadores_stats <- dbGetQuery(con, "
  SELECT 
    j.id_jugador,
    j.nombre_completo,
    j.puesto_posicion,
    j.altura_cm,
    COUNT(bs.id_partido) AS partidos_jugados,
    ROUND(AVG(bs.minutos_decimal)::numeric, 2) AS min_por_partido,
    ROUND(SUM(bs.minutos_decimal)::numeric, 2) AS min_totales,
    ROUND(AVG(bs.puntos)::numeric, 2) AS ppg,
    ROUND(AVG(bs.valoracion)::numeric, 2) AS val_pg,
    ROUND(AVG(bs.rebotes_totales)::numeric, 2) AS rpg,
    ROUND(AVG(bs.asistencias)::numeric, 2) AS apg,
    SUM(bs.t2_anotados) AS t2_tot_a, SUM(bs.t2_intentados) AS t2_tot_i,
    SUM(bs.t3_anotados) AS t3_tot_a, SUM(bs.t3_intentados) AS t3_tot_i,
    SUM(bs.tl_anotados) AS tl_tot_a, SUM(bs.tl_intentados) AS tl_tot_i
  FROM segunda_feb_pro.jugadores j
  JOIN segunda_feb_pro.box_scores_raw bs ON j.id_jugador = bs.id_jugador
  GROUP BY j.id_jugador, j.nombre_completo, j.puesto_posicion, j.altura_cm;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric)) %>%
  mutate(
    pct_t2 = if_else(t2_tot_i >= 10, (t2_tot_a / t2_tot_i) * 100, NA_real_),
    pct_t3 = if_else(t3_tot_i >= 10, (t3_tot_a / t3_tot_i) * 100, NA_real_),
    pct_tl = if_else(tl_tot_i >= 10, (tl_tot_a / tl_tot_i) * 100, NA_real_),
    categoria_altura = case_when(
      is.na(altura_cm) ~ "Desconocida",
      altura_cm < 190 ~ "< 190 cm (Exteriores Bajos)",
      altura_cm >= 190 & altura_cm <= 198 ~ "190-198 cm (Exteriores Altos/Aleros)",
      altura_cm > 198 & altura_cm <= 203 ~ "199-203 cm (Ala-Pívots/Interiores)",
      altura_cm > 203 ~ "> 203 cm (Pívots Puros)"
    )
  )

# Resumen estadístico por puesto posicional
resumen_posiciones <- df_jugadores_stats %>%
  filter(!is.na(puesto_posicion), puesto_posicion != "") %>%
  group_by(puesto_posicion) %>%
  summarise(
    n_jugadores = n(),
    altura_media = round(mean(altura_cm, na.rm = TRUE), 1),
    min_pg_medio = round(mean(min_por_partido), 1),
    ppg_medio = round(mean(ppg), 2),
    val_pg_medio = round(mean(val_pg), 2),
    rpg_medio = round(mean(rpg), 2),
    apg_medio = round(mean(apg), 2),
    pct_t2_medio = round(mean(pct_t2, na.rm = TRUE), 1),
    pct_t3_medio = round(mean(pct_t3, na.rm = TRUE), 1)
  ) %>%
  arrange(desc(val_pg_medio))

cat("\nRendimiento Medio por Posición Nominal:\n")
print(as.data.frame(resumen_posiciones), row.names = FALSE)

# Resumen por rangos de altura
resumen_altura <- df_jugadores_stats %>%
  filter(categoria_altura != "Desconocida") %>%
  group_by(categoria_altura) %>%
  summarise(
    n_jugadores = n(),
    ppg_medio = round(mean(ppg), 2),
    val_pg_medio = round(mean(val_pg), 2),
    rpg_medio = round(mean(rpg), 2),
    apg_medio = round(mean(apg), 2),
    pct_t2_medio = round(mean(pct_t2, na.rm = TRUE), 1),
    pct_t3_medio = round(mean(pct_t3, na.rm = TRUE), 1)
  ) %>%
  arrange(categoria_altura)

cat("\nRendimiento Medio por Rangos Físicos de Altura:\n")
print(as.data.frame(resumen_altura), row.names = FALSE)

# Test de significación estadística (ANOVA)
fit_ppg_altura <- aov(ppg ~ categoria_altura, data = df_jugadores_stats %>% filter(categoria_altura != "Desconocida"))
fit_val_altura <- aov(val_pg ~ categoria_altura, data = df_jugadores_stats %>% filter(categoria_altura != "Desconocida"))
fit_t3_altura  <- aov(pct_t3 ~ categoria_altura, data = df_jugadores_stats %>% filter(categoria_altura != "Desconocida", !is.na(pct_t3)))

cat("\nPruebas ANOVA de Significación Estadística por Rango de Altura:\n")
cat("  - Puntos por Partido (PPG): F =", summary(fit_ppg_altura)[[1]][["F value"]][1], 
    ", p-value =", summary(fit_ppg_altura)[[1]][["Pr(>F)"]][1], "\n")
cat("  - Eficiencia (Valoración):  F =", summary(fit_val_altura)[[1]][["F value"]][1], 
    ", p-value =", summary(fit_val_altura)[[1]][["Pr(>F)"]][1], "\n")
cat("  - Acierto Triple (% T3):     F =", summary(fit_t3_altura)[[1]][["F value"]][1], 
    ", p-value =", summary(fit_t3_altura)[[1]][["Pr(>F)"]][1], "\n")


# ------------------------------------------------------------------------------
# BLOQUE 3: DISTRIBUCIÓN DE MINUTOS Y UMBRALES DE MUESTRA
# ------------------------------------------------------------------------------
cat("\n--- BLOQUE 3: DISTRIBUCIÓN DE MINUTOS Y UMBRALES ESTADÍSTICOS ---\n")

dist_minutos <- df_jugadores_stats %>%
  summarise(
    total_jugadores = n(),
    p25_min_pg = quantile(min_por_partido, 0.25),
    mediana_min_pg = median(min_por_partido),
    media_min_pg = mean(min_por_partido),
    p75_min_pg = quantile(min_por_partido, 0.75),
    p90_min_pg = quantile(min_por_partido, 0.90),
    p25_pj = quantile(partidos_jugados, 0.25),
    mediana_pj = median(partidos_jugados),
    media_pj = mean(partidos_jugados),
    p75_pj = quantile(partidos_jugados, 0.75),
    p25_min_tot = quantile(min_totales, 0.25),
    mediana_min_tot = median(min_totales),
    p75_min_tot = quantile(min_totales, 0.75)
  )

cat("Métricas de Distribución de Muestra (Minutos y Partidos):\n")
print(as.data.frame(dist_minutos), row.names = FALSE)

# Proporción de jugadores según umbrales propuestos
u_10m <- df_jugadores_stats %>% filter(min_por_partido >= 10, partidos_jugados >= 5)
u_15m <- df_jugadores_stats %>% filter(min_por_partido >= 15, partidos_jugados >= 8)

cat(sprintf("\nJugadores que superan Umbral Flexible (>= 10 min/partido & >= 5 PJ): %d (%0.1f%% del total)\n",
            nrow(u_10m), (nrow(u_10m)/nrow(df_jugadores_stats))*100))
cat(sprintf("Jugadores que superan Umbral Estricto  (>= 15 min/partido & >= 8 PJ): %d (%0.1f%% del total)\n",
            nrow(u_15m), (nrow(u_15m)/nrow(df_jugadores_stats))*100))

dbDisconnect(con)

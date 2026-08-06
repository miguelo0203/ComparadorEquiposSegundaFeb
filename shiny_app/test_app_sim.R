# ==============================================================================
# TEST DE PREDICCIÓN & SIMULADOR (FASE 7 EN APP.R)
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(pROC)

cat("=================================================================\n")
cat("      TESTING DE SIMULADOR DE PARTIDOS ML (FASE 7 EN SHINY)       \n")
cat("=================================================================\n\n")

get_db_con <- function() {
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname   = "postgres",
    host     = "127.0.0.1",
    port     = 5433,
    user     = "postgres",
    password = ""
  )
  dbExecute(con, "SET search_path TO segunda_feb_pro, public;")
  return(con)
}

con <- get_db_con()
equipos <- dbGetQuery(con, "SELECT id_equipo, nombre_oficial FROM segunda_feb_pro.equipos ORDER BY nombre_oficial;") %>%
  mutate(id_equipo = as.numeric(id_equipo))

id_t1 <- equipos$id_equipo[1] # BIELE ISB
id_t2 <- equipos$id_equipo[2] # BUENO ARENAS ALBACETE BASKET

# 1. Entrenar modelo global
df_train_raw <- dbGetQuery(con, "
  SELECT 
    p.id_partido,
    tas_l.puntos_favor AS pts_l, tas_l.puntos_contra AS pts_v,
    tas_l.pace AS pace_l, tas_l.ortg AS ortg_l, tas_l.drtg AS drtg_l, tas_l.net_rating AS net_l,
    tas_l.efg_pct AS efg_l, tas_l.tov_pct AS tov_l, tas_l.oreb_pct AS oreb_l, tas_l.ft_rate AS ftr_l,
    tas_v.pace AS pace_v, tas_v.ortg AS ortg_v, tas_v.drtg AS drtg_v, tas_v.net_rating AS net_v,
    tas_v.efg_pct AS efg_v, tas_v.tov_pct AS tov_v, tas_v.oreb_pct AS oreb_v, tas_v.ft_rate AS ftr_v
  FROM segunda_feb_pro.partidos p
  JOIN segunda_feb_pro.team_advanced_stats tas_l ON p.id_partido = tas_l.id_partido AND p.id_equipo_local = tas_l.id_equipo
  JOIN segunda_feb_pro.team_advanced_stats tas_v ON p.id_partido = tas_v.id_partido AND p.id_equipo_visitante = tas_v.id_equipo;
") %>% mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric)) %>%
  mutate(
    victoria_real = if_else(pts_l > pts_v, 1, 0),
    diff_net_rating = net_l - net_v,
    diff_efg = efg_l - efg_v,
    diff_tov = tov_l - tov_v,
    diff_oreb = oreb_l - oreb_v,
    diff_ftrate = ftr_l - ftr_v,
    diff_pace = pace_l - pace_v
  )

set.seed(42)
model_glm_global <- glm(
  victoria_real ~ diff_net_rating + diff_efg + diff_tov + diff_oreb + diff_ftrate + diff_pace,
  data = df_train_raw,
  family = binomial
)

# 2. Simular partido entre id_t1 e id_t2
df_loc <- dbGetQuery(con, sprintf("SELECT AVG(pace) AS pace, AVG(net_rating) AS net_l, AVG(efg_pct) AS efg_l, AVG(tov_pct) AS tov_l, AVG(oreb_pct) AS oreb_l, AVG(ft_rate) AS ftr_l FROM segunda_feb_pro.team_advanced_stats WHERE id_equipo = %d;", as.integer(id_t1)))
df_vis <- dbGetQuery(con, sprintf("SELECT AVG(pace) AS pace, AVG(net_rating) AS net_v, AVG(efg_pct) AS efg_v, AVG(tov_pct) AS tov_v, AVG(oreb_pct) AS oreb_v, AVG(ft_rate) AS ftr_v FROM segunda_feb_pro.team_advanced_stats WHERE id_equipo = %d;", as.integer(id_t2)))

df_sim_feat <- tibble(
  diff_net_rating = df_loc$net_l[1] - df_vis$net_v[1],
  diff_efg = df_loc$efg_l[1] - df_vis$efg_v[1],
  diff_tov = df_loc$tov_l[1] - df_vis$tov_v[1],
  diff_oreb = df_loc$oreb_l[1] - df_vis$oreb_v[1],
  diff_ftrate = df_loc$ftr_l[1] - df_vis$ftr_v[1],
  diff_pace = df_loc$pace[1] - df_vis$pace[1]
)

prob_loc <- predict(model_glm_global, newdata = df_sim_feat, type = "response")[1]
prob_vis <- 1 - prob_loc

dbDisconnect(con)

cat(sprintf("Partido Simulado: %s (Local) vs %s (Visitante)\n", equipos$nombre_oficial[1], equipos$nombre_oficial[2]))
cat(sprintf("  -> Probabilidad Local (%s): %0.2f%%\n", equipos$nombre_oficial[1], prob_loc * 100))
cat(sprintf("  -> Probabilidad Visitante (%s): %0.2f%%\n", equipos$nombre_oficial[2], prob_vis * 100))
cat(sprintf("  -> Diferencial Net Rating: %+0.2f\n", df_sim_feat$diff_net_rating[1]))
cat(sprintf("  -> Diferencial eFG%%: %+0.2f%%\n", df_sim_feat$diff_efg[1]))

cat("\n=================================================================\n")
cat("          TEST DE SIMULACIÓN ML EN SHINY COMPLETADO OK          \n")
cat("=================================================================\n")

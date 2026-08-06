# ==============================================================================
# TEST DE PESTAÑA 5: TEAM EXECUTIVE SUMMARY Y SISTEMA EXPERTO
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(plotly)

cat("=================================================================\n")
cat("  TESTING DE TAB 5: TEAM EXECUTIVE SUMMARY & EXPERT SYSTEM RULES  \n")
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

tid <- equipos$id_equipo[1] # BIELE ISB

# 1. HHI
df_pts <- dbGetQuery(con, sprintf("SELECT id_jugador, SUM(puntos) AS total_pts FROM segunda_feb_pro.box_scores_raw WHERE id_equipo = %d GROUP BY id_jugador;", as.integer(tid))) %>%
  mutate(total_pts = as.numeric(total_pts))

tot_team_pts <- sum(df_pts$total_pts)
hhi_val <- if (tot_team_pts > 0) sum((df_pts$total_pts / tot_team_pts)^2) * 100 else 0

# 2. Minutos por Arquetipo
df_arch <- dbGetQuery(con, sprintf("SELECT COALESCE(pa.nombre_arquetipo, 'En Evaluación') AS arquetipo, SUM(bs.minutos_decimal) AS minutos_totales FROM segunda_feb_pro.box_scores_raw bs LEFT JOIN segunda_feb_pro.player_archetypes pa ON bs.id_jugador = pa.id_jugador WHERE bs.id_equipo = %d GROUP BY pa.nombre_arquetipo;", as.integer(tid))) %>%
  mutate(minutos_totales = as.numeric(minutos_totales))

dbDisconnect(con)

cat(sprintf("Equipo Auditado: %s (ID %d)\n", equipos$nombre_oficial[1], tid))
cat(sprintf("  -> Concentración HHI: %0.2f%%\n", hhi_val))
cat(sprintf("  -> Desglose de Arquetipos (Total %d arquetipos activos):\n", nrow(df_arch)))
print(as.data.frame(df_arch), row.names = FALSE)

cat("\n=================================================================\n")
cat("          TEST DE PESTAÑA 5 EXECUTIVE SUMMARY OK                  \n")
cat("=================================================================\n")

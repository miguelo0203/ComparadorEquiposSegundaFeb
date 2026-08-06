# ==============================================================================
# AUDITORÍA Y TEST DE REACTIVIDAD / DDL / DATOS PARA APP.R
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(plotly)
library(DT)

cat("=================================================================\n")
cat("      TESTING Y VALIDACIÓN DE CONECTIVIDAD & QUERIES (APP.R)      \n")
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

# 1. Test Tab 1: Team Matchup Engine
cat("[TEST 1/3] Probando consulta Team Matchup Engine (Tab 1)...\n")
id_t1 <- equipos$id_equipo[1]
id_t2 <- equipos$id_equipo[2]

df_loc <- dbGetQuery(con, sprintf("SELECT AVG(pace) AS pace, AVG(ortg) AS ortg, AVG(drtg) AS drtg, AVG(net_rating) AS net_rating, AVG(efg_pct) AS efg_pct FROM segunda_feb_pro.team_advanced_stats WHERE id_equipo = %d;", as.integer(id_t1)))
cat("  -> Team:", equipos$nombre_oficial[1], "| Pace:", df_loc$pace[1], "| ORtg:", df_loc$ortg[1], "| DRtg:", df_loc$drtg[1], "\n")

# 2. Test Tab 2: Player Scouting & Radar
cat("[TEST 2/3] Probando consulta Player Scouting & Radar (Tab 2)...\n")
df_bio <- dbGetQuery(con, "SELECT j.id_jugador, j.nombre_completo, COALESCE(j.puesto_posicion, 'Sin Posición') AS pos, pa.nombre_arquetipo FROM segunda_feb_pro.jugadores j LEFT JOIN segunda_feb_pro.player_archetypes pa ON j.id_jugador = pa.id_jugador LIMIT 1;")
df_bio <- df_bio %>% mutate(id_jugador = as.numeric(id_jugador))

df_stats <- dbGetQuery(con, sprintf("SELECT AVG(pctil_valoracion) AS val, AVG(pctil_ts_pct) AS ts, AVG(pctil_puntos) AS pts, AVG(pctil_rebotes) AS reb, AVG(pctil_asistencias) AS ast FROM segunda_feb_pro.player_advanced_stats WHERE id_jugador = %d;", as.integer(df_bio$id_jugador[1])))
cat("  -> Jugador:", df_bio$nombre_completo[1], "| Arquetipo:", df_bio$nombre_arquetipo[1], "| Pctil Val:", df_stats$val[1], "\n")

# 3. Test Tab 3: Recruitment Finder
cat("[TEST 3/3] Probando consulta Recruitment Finder (Tab 3)...\n")
df_rec <- dbGetQuery(con, "
  SELECT 
    j.nombre_completo AS jugador,
    pa.nombre_arquetipo AS arquetipo,
    ROUND(AVG(pas.puntos_per40)::numeric, 1) AS ppg_40,
    ROUND(AVG(pas.valoracion_per40)::numeric, 1) AS val_40
  FROM segunda_feb_pro.jugadores j
  JOIN segunda_feb_pro.player_advanced_stats pas ON j.id_jugador = pas.id_jugador
  JOIN segunda_feb_pro.player_archetypes pa ON j.id_jugador = pa.id_jugador
  WHERE pas.cumple_umbral = TRUE AND pa.cluster_id IN (1,2,3,4,5,6)
  GROUP BY j.id_jugador, j.nombre_completo, pa.nombre_arquetipo
  HAVING AVG(pas.puntos_per40) >= 10 AND AVG(pas.ts_pct) >= 45 AND AVG(pas.valoracion_per40) >= 10
  LIMIT 5;
")
dbDisconnect(con)
print(as.data.frame(df_rec), row.names = FALSE)

cat("\n=================================================================\n")
cat("          TODOS LOS TESTS DE QUERIES Y DATOS DE SHINY OK          \n")
cat("=================================================================\n")

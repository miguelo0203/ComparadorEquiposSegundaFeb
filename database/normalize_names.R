# ==============================================================================
# NORMALIZE ARCHETYPE NAMES IN SQLITE DATABASE
# ==============================================================================

library(DBI)
library(RSQLite)

sqlite_path <- "f:/Otro Proyecto/segunda_feb_pro.sqlite"
con <- dbConnect(RSQLite::SQLite(), sqlite_path)

cat("Actualizando nombres de arquetipos en SQLite...\n")

dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Interior Defensivo' WHERE cluster_id = 1;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Base Organizador' WHERE cluster_id = 2;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Alero 3&D' WHERE cluster_id = 3;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Tirador Catch & Shoot' WHERE cluster_id = 4;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Anotador Principal' WHERE cluster_id = 5;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Pívot Abierto' WHERE cluster_id = 6;")

# También en PostgreSQL si está disponible
try({
  library(RPostgres)
  pg_con <- dbConnect(RPostgres::Postgres(), dbname = "postgres", host = "127.0.0.1", port = 5433, user = "postgres", password = "")
  dbExecute(pg_con, "SET search_path TO segunda_feb_pro, public;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Interior Defensivo' WHERE cluster_id = 1;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Base Organizador' WHERE cluster_id = 2;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Alero 3&D' WHERE cluster_id = 3;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Tirador Catch & Shoot' WHERE cluster_id = 4;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Anotador Principal' WHERE cluster_id = 5;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Pívot Abierto' WHERE cluster_id = 6;")
  dbDisconnect(pg_con)
}, silent = TRUE)

df_check <- dbGetQuery(con, "SELECT DISTINCT cluster_id, nombre_arquetipo FROM player_archetypes ORDER BY cluster_id;")
print(df_check)

dbDisconnect(con)

cat("Nombres de arquetipos normalizados con éxito.\n")

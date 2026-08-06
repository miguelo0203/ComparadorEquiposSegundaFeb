# ==============================================================================
# UPDATE ARCHETYPE NAMES AND CLEAN DESCRIPTIONS IN SQLITE & POSTGRESQL
# ==============================================================================

library(DBI)
library(RSQLite)

sqlite_path <- "f:/Otro Proyecto/segunda_feb_pro.sqlite"
con <- dbConnect(RSQLite::SQLite(), sqlite_path)

cat("Actualizando descripciones y nombres de arquetipos en SQLite...\n")

dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Interior Defensivo', descripcion_perfil = 'Interior defensivo especializado en rebote, protección de aro y juego en la pintura.' WHERE cluster_id = 1;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Base Organizador', descripcion_perfil = 'Base organizador centrado en la creación de juego, asistencias y dirección de equipo.' WHERE cluster_id = 2;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Alero 3&D', descripcion_perfil = 'Alero polivalente con equilibrio defensivo y amenaza exterior en tiros lejanos.' WHERE cluster_id = 3;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Tirador Catch & Shoot', descripcion_perfil = 'Especialista exterior con alto volumen de tiros de tres y juego sin balón.' WHERE cluster_id = 4;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Anotador Principal', descripcion_perfil = 'Anotador exterior con alta tasa de uso y protagonismo ofensivo.' WHERE cluster_id = 5;")
dbExecute(con, "UPDATE player_archetypes SET nombre_arquetipo = 'Pívot Abierto', descripcion_perfil = 'Interior versátil con capacidad para anotar cerca del aro y abrir el campo desde el triple.' WHERE cluster_id = 6;")

# También en PostgreSQL si está disponible
try({
  library(RPostgres)
  pg_con <- dbConnect(RPostgres::Postgres(), dbname = "postgres", host = "127.0.0.1", port = 5433, user = "postgres", password = "")
  dbExecute(pg_con, "SET search_path TO segunda_feb_pro, public;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Interior Defensivo', descripcion_perfil = 'Interior defensivo especializado en rebote, protección de aro y juego en la pintura.' WHERE cluster_id = 1;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Base Organizador', descripcion_perfil = 'Base organizador centrado en la creación de juego, asistencias y dirección de equipo.' WHERE cluster_id = 2;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Alero 3&D', descripcion_perfil = 'Alero polivalente con equilibrio defensivo y amenaza exterior en tiros lejanos.' WHERE cluster_id = 3;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Tirador Catch & Shoot', descripcion_perfil = 'Especialista exterior con alto volumen de tiros de tres y juego sin balón.' WHERE cluster_id = 4;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Anotador Principal', descripcion_perfil = 'Anotador exterior con alta tasa de uso y protagonismo ofensivo.' WHERE cluster_id = 5;")
  dbExecute(pg_con, "UPDATE segunda_feb_pro.player_archetypes SET nombre_arquetipo = 'Pívot Abierto', descripcion_perfil = 'Interior versátil con capacidad para anotar cerca del aro y abrir el campo desde el triple.' WHERE cluster_id = 6;")
  dbDisconnect(pg_con)
}, silent = TRUE)

df_check <- dbGetQuery(con, "SELECT DISTINCT cluster_id, nombre_arquetipo, descripcion_perfil FROM player_archetypes ORDER BY cluster_id;")
print(df_check)

dbDisconnect(con)

cat("Descripciones de arquetipos actualizadas con éxito.\n")

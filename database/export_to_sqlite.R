# ==============================================================================
# EXPORT POSTGRESQL TO STANDALONE SQLITE DATABASE FOR SHINYAPPS.IO DEPLOYMENT
# ==============================================================================

library(DBI)
library(RPostgres)
library(RSQLite)
library(dplyr)

cat("Iniciando exportación de PostgreSQL a SQLite...\n")

pg_con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)
dbExecute(pg_con, "SET search_path TO segunda_feb_pro, public;")

sqlite_path <- "f:/Otro Proyecto/segunda_feb_pro.sqlite"
if (file.exists(sqlite_path)) file.remove(sqlite_path)

sqlite_con <- dbConnect(RSQLite::SQLite(), sqlite_path)

tables <- c("equipos", "jugadores", "partidos", "box_scores_raw", 
            "team_advanced_stats", "player_advanced_stats", 
            "player_archetypes")

for (tbl in tables) {
  cat(sprintf(" -> Exportando tabla: %s... ", tbl))
  df <- dbGetQuery(pg_con, sprintf("SELECT * FROM segunda_feb_pro.%s;", tbl))
  
  # Convert integer64 or Date objects for SQLite compatibility
  df <- df %>% mutate(across(where(~ inherits(.x, "integer64")), as.numeric))
  
  dbWriteTable(sqlite_con, tbl, df, overwrite = TRUE)
  cat(sprintf("OK (%d registros)\n", nrow(df)))
}

dbDisconnect(pg_con)
dbDisconnect(sqlite_con)

cat("\n=================================================================\n")
cat("EXPORTACIÓN A SQLITE COMPLETADA CON ÉXITO: segunda_feb_pro.sqlite\n")
cat("=================================================================\n")

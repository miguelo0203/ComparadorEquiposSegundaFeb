# ==============================================================================
# ENRIQUECIMIENTO MASIVO DE PERFILES DE JUGADORES ÚNICOS (FASE B)
# ==============================================================================

library(rvest)
library(httr)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)
library(lubridate)
library(DBI)
library(RPostgres)

cat("=================================================================\n")
cat("   FASE B: ENRIQUECIMIENTO DE METADATOS BIOGRÁFICOS DE JUGADORES  \n")
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

# Extraer todos los id_jugador de la tabla jugadores que no tienen altura o puesto
df_jugadores_pendientes <- dbGetQuery(con, "
  SELECT DISTINCT j.id_jugador, j.id_equipo_actual
  FROM segunda_feb_pro.jugadores j
  WHERE j.altura_cm IS NULL OR j.puesto_posicion IS NULL;
")

cat(sprintf("[FASE B] Jugadores a procesar perfil biográfico: %d\n", nrow(df_jugadores_pendientes)))

limpiar_altura_cm <- function(cadena_altura) {
  if (is.null(cadena_altura) || is.na(cadena_altura) || cadena_altura %in% c("", "-", "N/A")) return(NA_integer_)
  num <- as.integer(str_extract(cadena_altura, "\\d+"))
  if (!is.na(num) && num > 140 && num < 240) return(num)
  return(NA_integer_)
}

parsear_fecha <- function(cadena_fecha) {
  if (is.null(cadena_fecha) || is.na(cadena_fecha) || cadena_fecha %in% c("", "-", "N/A")) return(NA_Date_)
  return(dmy(cadena_fecha, quiet = TRUE))
}

extraer_perfil_jugador <- function(id_jugador, id_equipo) {
  url_j <- sprintf("https://baloncestoenvivo.feb.es/Jugador.aspx?i=%s&c=%s", id_equipo, id_jugador)
  resp <- GET(url_j, add_headers("User-Agent" = "Mozilla/5.0"))
  if (status_code(resp) != 200) return(NULL)
  
  html <- read_html(resp)
  box <- html %>% html_node("div.box-jugador")
  if (is.na(box)) return(NULL)
  
  nodos <- box %>% html_nodes(".info .nodo")
  meta <- list()
  for (n in nodos) {
    lbl <- str_squish(n %>% html_node("span.label") %>% html_text(trim = TRUE))
    val <- str_squish(n %>% html_node("span.string") %>% html_text(trim = TRUE))
    if (!is.na(lbl) && nchar(lbl) > 0) meta[[lbl]] <- val
  }
  
  puesto_raw <- meta[["Puesto"]]
  puesto_val <- if (!is.null(puesto_raw) && puesto_raw != "-") puesto_raw else NA_character_
  altura_val <- if (!is.null(meta[["Altura"]])) limpiar_altura_cm(meta[["Altura"]]) else NA_integer_
  fecha_val  <- if (!is.null(meta[["Fecha Nacimiento"]])) parsear_fecha(meta[["Fecha Nacimiento"]]) else NA_Date_
  nac_val    <- if (!is.null(meta[["Nacionalidad"]])) meta[["Nacionalidad"]] else NA_character_
  
  tibble(
    id_jugador = id_jugador,
    puesto_posicion = puesto_val,
    altura_cm = altura_val,
    fecha_nacimiento = fecha_val,
    nacionalidad = nac_val
  )
}

update_jugador_perfil <- function(con, id_j, puesto, altura, f_nac, nac) {
  sql <- "
    UPDATE segunda_feb_pro.jugadores
    SET puesto_posicion = COALESCE($2, puesto_posicion),
        altura_cm = COALESCE($3, altura_cm),
        fecha_nacimiento = COALESCE($4, fecha_nacimiento),
        nacionalidad = COALESCE($5, nacionalidad),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id_jugador = $1;
  "
  dbExecute(con, sql, params = list(
    id_j,
    if(is.null(puesto) || is.na(puesto)) NA else puesto,
    if(is.null(altura) || is.na(altura)) NA else as.integer(altura),
    if(is.null(f_nac) || is.na(f_nac)) NA else as.character(f_nac),
    if(is.null(nac) || is.na(nac)) NA else nac
  ))
}

cnt_ok <- 0
for (i in 1:nrow(df_jugadores_pendientes)) {
  id_j <- df_jugadores_pendientes$id_jugador[i]
  id_eq <- df_jugadores_pendientes$id_equipo_actual[i]
  
  res_p <- tryCatch(extraer_perfil_jugador(id_j, id_eq), error = function(e) NULL)
  if (!is.null(res_p)) {
    update_jugador_perfil(
      con = con,
      id_j = id_j,
      puesto = res_p$puesto_posicion[1],
      altura = res_p$altura_cm[1],
      f_nac = res_p$fecha_nacimiento[1],
      nac = res_p$nacionalidad[1]
    )
    cnt_ok <- cnt_ok + 1
  }
  
  if (i %% 50 == 0 || i == nrow(df_jugadores_pendientes)) {
    cat(sprintf("  -> Progreso Perfiles: %d/%d (%0.1f%%)\n", i, nrow(df_jugadores_pendientes), (i/nrow(df_jugadores_pendientes))*100))
  }
}

dbDisconnect(con)
cat(sprintf("\n[FASE B COMPLETADA] %d perfiles actualizados en base de datos.\n", cnt_ok))

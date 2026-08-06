# ==============================================================================
# ENRIQUECIMIENTO ULTRA-ROBUSTO DE JUGADORES MEDIANTE URLS REALES DE FEB
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
cat(" FASE B: EXTRACCIÓN Y ENRIQUECIMIENTO DE PERFILES BIOGRÁFICOS   \n")
cat("=================================================================\n\n")

df_calendario <- readRDS("f:/Otro Proyecto/df_calendario.rds")

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)
dbExecute(con, "SET search_path TO segunda_feb_pro, public;")

jugadores_pendientes <- dbGetQuery(con, "
  SELECT id_jugador 
  FROM segunda_feb_pro.jugadores 
  WHERE altura_cm IS NULL OR puesto_posicion IS NULL;
")$id_jugador

cat(sprintf("[FASE B] Jugadores pendientes de enriquecer: %d\n", length(jugadores_pendientes)))

dict_urls <- list()

cat("[FASE B] Mapeando URLs reales de jugadores desde actas de partidos...\n")

indices_muestra <- unique(c(1:50, seq(51, nrow(df_calendario), by = 3), nrow(df_calendario)))

for (idx in indices_muestra) {
  if (length(dict_urls) >= length(jugadores_pendientes)) break
  url_p <- df_calendario$url_partido[idx]
  
  resp <- tryCatch(GET(url_p, add_headers("User-Agent" = "Mozilla/5.0")), error = function(e) NULL)
  if (is.null(resp) || status_code(resp) != 200) next
  
  html <- read_html(resp)
  links_j <- html %>% html_nodes("td.nombre.jugador a")
  
  for (lj in links_j) {
    href_j <- html_attr(lj, "href")
    if (!is.na(href_j) && str_detect(href_j, "Jugador.aspx")) {
      id_j_ext <- as.integer(str_extract(href_j, "(?<=c=)\\d+"))
      if (!is.na(id_j_ext) && (id_j_ext %in% jugadores_pendientes) && is.null(dict_urls[[as.character(id_j_ext)]])) {
        full_url <- if (str_starts(href_j, "http")) href_j else paste0("https://baloncestoenvivo.feb.es/", str_remove(href_j, "^/"))
        dict_urls[[as.character(id_j_ext)]] <- full_url
      }
    }
  }
}

cat(sprintf("[FASE B] URLs reales encontradas para %d jugadores pendientes.\n", length(dict_urls)))

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

extraer_perfil_jugador_url <- function(url_j) {
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
  puesto_val <- if (!is.null(puesto_raw) && str_squish(puesto_raw) != "" && str_squish(puesto_raw) != "-") str_squish(puesto_raw) else NA_character_
  altura_val <- if (!is.null(meta[["Altura"]])) limpiar_altura_cm(meta[["Altura"]]) else NA_integer_
  fecha_val  <- if (!is.null(meta[["Fecha Nacimiento"]])) parsear_fecha(meta[["Fecha Nacimiento"]]) else NA_Date_
  nac_raw    <- meta[["Nacionalidad"]]
  nac_val    <- if (!is.null(nac_raw) && str_squish(nac_raw) != "" && str_squish(nac_raw) != "-") str_squish(nac_raw) else NA_character_
  
  tibble(
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

cat("[FASE B] Procesando perfiles individuales...\n")

cnt_ok <- 0
keys_j <- names(dict_urls)

for (k in 1:length(keys_j)) {
  id_j_str <- keys_j[k]
  id_j <- as.integer(id_j_str)
  url_j <- dict_urls[[id_j_str]]
  
  res_p <- tryCatch(extraer_perfil_jugador_url(url_j), error = function(e) NULL)
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
  
  if (k %% 50 == 0 || k == length(keys_j)) {
    cat(sprintf("  -> Progreso Perfiles: %d/%d (%0.1f%%)\n", k, length(keys_j), (k/length(keys_j))*100))
  }
}

dbDisconnect(con)
cat(sprintf("\n[FASE B COMPLETADA ÉXITO] %d perfiles biográficos actualizados en PostgreSQL.\n", cnt_ok))

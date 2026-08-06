# ==============================================================================
# WORKER PARALELO DE INGESTA DE PARTIDOS Y ACTAS (SEGUNDA FEB)
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

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Uso: Rscript parallel_worker.R <start_idx> <end_idx>")
}

start_idx <- as.integer(args[1])
end_idx   <- as.integer(args[2])

df_calendario <- readRDS("f:/Otro Proyecto/df_calendario.rds")
total_partidos <- nrow(df_calendario)

end_idx <- min(end_idx, total_partidos)

cat(sprintf("[WORKER %d-%d] Procesando partidos del %d al %d de %d...\n", 
            start_idx, end_idx, start_idx, end_idx, total_partidos))

# Helpers
convertir_minutos_decimal <- function(cadena_minutos) {
  if (is.na(cadena_minutos) || cadena_minutos %in% c("", "-", "N/A")) return(0.00)
  partes <- str_split(cadena_minutos, ":")[[1]]
  if (length(partes) == 2) {
    minutos <- as.numeric(partes[1])
    segundos <- as.numeric(partes[2])
    if (!is.na(minutos) && !is.na(segundos)) return(round(minutos + (segundos / 60), 2))
  }
  return(0.00)
}

limpiar_entero <- function(val, valor_defecto = 0) {
  if (is.na(val) || val %in% c("", "-", "N/A")) return(valor_defecto)
  num <- as.integer(str_extract(val, "-?\\d+"))
  if (is.na(num)) return(valor_defecto) else return(num)
}

parsear_tiros <- function(cadena_tiros) {
  if (is.na(cadena_tiros) || cadena_tiros %in% c("", "-")) return(list(anotados = 0, intentados = 0))
  match <- str_match(cadena_tiros, "^(\\d+)/(\\d+)")
  if (!is.na(match[1,1])) return(list(anotados = as.integer(match[1,2]), intentados = as.integer(match[1,3])))
  return(list(anotados = 0, intentados = 0))
}

extraer_acta_partido <- function(url_partido, nom_grupo = "Grupo Este", num_jornada = 1) {
  id_partido_ext <- as.integer(str_extract(url_partido, "(?<=p=)\\d+"))
  resp <- GET(url_partido, add_headers("User-Agent" = "Mozilla/5.0"))
  if (status_code(resp) != 200) stop(paste("HTTP Error", status_code(resp)))
  
  html <- read_html(resp)
  nombres_equipos <- html %>% html_nodes("h1.titulo-modulo") %>% html_text(trim = TRUE)
  if (length(nombres_equipos) < 2) stop("No se pudieron identificar ambos equipos.")
  
  equipo_local <- str_squish(nombres_equipos[1])
  equipo_visitante <- str_squish(nombres_equipos[2])
  
  tablas <- html %>% html_nodes("div.responsive-scroll > table")
  if (length(tablas) < 2) stop("No se localizan las 2 tablas estadísticas.")
  
  parsear_tabla_equipo <- function(tabla_node, nombre_equipo) {
    filas <- tabla_node %>% html_nodes("tr")
    filas_j <- filas[sapply(filas, function(f) length(html_nodes(f, "td.nombre")) > 0)]
    
    map_dfr(filas_j, function(f) {
      nodo_a <- f %>% html_node("td.nombre.jugador a")
      url_j <- nodo_a %>% html_attr("href")
      id_jugador_ext <- if (!is.na(url_j)) as.integer(str_extract(url_j, "(?<=c=)\\d+")) else NA_integer_
      nombre_j <- str_squish(nodo_a %>% html_text(trim = TRUE))
      
      if (is.na(id_jugador_ext)) return(NULL)
      
      url_j_full <- if (!is.na(url_j)) {
        if (str_starts(url_j, "http")) url_j else paste0("https://baloncestoenvivo.feb.es/", str_remove(url_j, "^/"))
      } else NA_character_
      
      dorsal_raw <- f %>% html_node("td.dorsal") %>% html_text(trim = TRUE)
      minutos_raw <- f %>% html_node("td.minutos") %>% html_text(trim = TRUE)
      puntos_raw <- f %>% html_node("td.puntos") %>% html_text(trim = TRUE)
      t2_raw <- f %>% html_node("td.tiros.dos") %>% html_text(trim = TRUE)
      t3_raw <- f %>% html_node("td.tiros.tres") %>% html_text(trim = TRUE)
      tl_raw <- f %>% html_node("td.tiros.libres") %>% html_text(trim = TRUE)
      ro_raw <- f %>% html_node("td.rebotes.ofensivos") %>% html_text(trim = TRUE)
      rd_raw <- f %>% html_node("td.rebotes.defensivos") %>% html_text(trim = TRUE)
      rt_raw <- f %>% html_node("td.rebotes.total") %>% html_text(trim = TRUE)
      as_raw <- f %>% html_node("td.asistencias") %>% html_text(trim = TRUE)
      br_raw <- f %>% html_node("td.recuperaciones") %>% html_text(trim = TRUE)
      bp_raw <- f %>% html_node("td.perdidas") %>% html_text(trim = TRUE)
      tf_raw <- f %>% html_node("td.tapones.favor") %>% html_text(trim = TRUE)
      fc_raw <- f %>% html_node("td.faltas.cometidas") %>% html_text(trim = TRUE)
      va_raw <- f %>% html_node("td.valoracion") %>% html_text(trim = TRUE)
      
      t2 <- parsear_tiros(t2_raw)
      t3 <- parsear_tiros(t3_raw)
      tl <- parsear_tiros(tl_raw)
      
      tibble(
        id_jugador = id_jugador_ext,
        nombre_completo = nombre_j,
        url_jugador = url_j_full,
        equipo_nombre = nombre_equipo,
        dorsal = limpiar_entero(dorsal_raw),
        minutos_decimal = convertir_minutos_decimal(minutos_raw),
        puntos = limpiar_entero(puntos_raw),
        t2_anotados = t2$anotados, t2_intentados = t2$intentados,
        t3_anotados = t3$anotados, t3_intentados = t3$intentados,
        tl_anotados = tl$anotados, tl_intentados = tl$intentados,
        rebotes_ofensivos = limpiar_entero(ro_raw),
        rebotes_defensivos = limpiar_entero(rd_raw),
        rebotes_totales = limpiar_entero(rt_raw),
        asistencias = limpiar_entero(as_raw),
        recuperaciones = limpiar_entero(br_raw),
        perdidas = limpiar_entero(bp_raw),
        tapones = limpiar_entero(tf_raw),
        faltas_cometidas = limpiar_entero(fc_raw),
        valoracion = limpiar_entero(va_raw, 0)
      )
    })
  }
  
  box_local <- parsear_tabla_equipo(tablas[[1]], equipo_local)
  box_visitante <- parsear_tabla_equipo(tablas[[2]], equipo_visitante)
  
  pts_local <- sum(box_local$puntos, na.rm = TRUE)
  pts_visita <- sum(box_visitante$puntos, na.rm = TRUE)
  
  list(
    partido_meta = tibble(
      id_partido = id_partido_ext,
      temporada = "2024-2025",
      jornada = num_jornada,
      grupo = nom_grupo,
      fecha_partido = now(),
      equipo_local = equipo_local,
      equipo_visitante = equipo_visitante,
      puntos_local = pts_local,
      puntos_visitante = pts_visita
    ),
    box_score = bind_rows(box_local, box_visitante) %>% filter(!is.na(id_jugador))
  )
}

upsert_equipo <- function(con, nombre_oficial, grupo = "Grupo Este") {
  sql <- "
    INSERT INTO segunda_feb_pro.equipos (nombre_oficial, grupo)
    VALUES ($1, $2)
    ON CONFLICT (nombre_oficial) DO UPDATE 
      SET grupo = COALESCE(EXCLUDED.grupo, segunda_feb_pro.equipos.grupo)
    RETURNING id_equipo;
  "
  df <- dbGetQuery(con, sql, params = list(nombre_oficial, grupo))
  return(df$id_equipo[1])
}

upsert_partido <- function(con, p_meta, id_loc, id_vis) {
  sql <- "
    INSERT INTO segunda_feb_pro.partidos (
      id_partido, temporada, jornada, fecha_partido, 
      id_equipo_local, id_equipo_visitante, puntos_local, puntos_visitante
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (id_partido) DO UPDATE SET
      temporada = EXCLUDED.temporada,
      jornada = EXCLUDED.jornada,
      puntos_local = EXCLUDED.puntos_local,
      puntos_visitante = EXCLUDED.puntos_visitante;
  "
  dbExecute(con, sql, params = list(
    p_meta$id_partido, p_meta$temporada, p_meta$jornada,
    as.character(p_meta$fecha_partido), id_loc, id_vis,
    p_meta$puntos_local, p_meta$puntos_visitante
  ))
}

upsert_jugador_basico <- function(con, id_j, nombre, id_eq) {
  sql <- "
    INSERT INTO segunda_feb_pro.jugadores (id_jugador, nombre_completo, id_equipo_actual)
    VALUES ($1, $2, $3)
    ON CONFLICT (id_jugador) DO UPDATE SET
      nombre_completo = EXCLUDED.nombre_completo,
      id_equipo_actual = EXCLUDED.id_equipo_actual,
      actualizado_en = CURRENT_TIMESTAMP;
  "
  dbExecute(con, sql, params = list(id_j, nombre, id_eq))
}

upsert_box_score <- function(con, id_partido, id_j, id_eq, row) {
  sql <- "
    INSERT INTO segunda_feb_pro.box_scores_raw (
      id_partido, id_jugador, id_equipo, dorsal, minutos_decimal, puntos,
      t2_anotados, t2_intentados, t3_anotados, t3_intentados, tl_anotados, tl_intentados,
      rebotes_ofensivos, rebotes_defensivos, rebotes_totales, asistencias, recuperaciones,
      perdidas, tapones, faltas_cometidas, valoracion
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
    ON CONFLICT (id_partido, id_jugador) DO UPDATE SET
      dorsal = EXCLUDED.dorsal,
      minutos_decimal = EXCLUDED.minutos_decimal,
      puntos = EXCLUDED.puntos,
      t2_anotados = EXCLUDED.t2_anotados,
      t2_intentados = EXCLUDED.t2_intentados,
      t3_anotados = EXCLUDED.t3_anotados,
      t3_intentados = EXCLUDED.t3_intentados,
      tl_anotados = EXCLUDED.tl_anotados,
      tl_intentados = EXCLUDED.tl_intentados,
      rebotes_ofensivos = EXCLUDED.rebotes_ofensivos,
      rebotes_defensivos = EXCLUDED.rebotes_defensivos,
      rebotes_totales = EXCLUDED.rebotes_totales,
      asistencias = EXCLUDED.asistencias,
      recuperaciones = EXCLUDED.recuperaciones,
      perdidas = EXCLUDED.perdidas,
      tapones = EXCLUDED.tapones,
      faltas_cometidas = EXCLUDED.faltas_cometidas,
      valoracion = EXCLUDED.valoracion;
  "
  dbExecute(con, sql, params = list(
    id_partido, id_j, id_eq, row$dorsal, row$minutos_decimal, row$puntos,
    row$t2_anotados, row$t2_intentados, row$t3_anotados, row$t3_intentados,
    row$tl_anotados, row$tl_intentados, row$rebotes_ofensivos, row$rebotes_defensivos,
    row$rebotes_totales, row$asistencias, row$recuperaciones, row$perdidas,
    row$tapones, row$faltas_cometidas, row$valoracion
  ))
}

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)
dbExecute(con, "SET search_path TO segunda_feb_pro, public;")

count_ok <- 0
count_err <- 0

for (idx in start_idx:end_idx) {
  p_info <- df_calendario[idx, ]
  url_p <- p_info$url_partido
  id_p  <- p_info$id_partido
  g_p   <- p_info$grupo
  j_p   <- p_info$jornada
  
  tryCatch({
    datos <- extraer_acta_partido(url_p, nom_grupo = g_p, num_jornada = j_p)
    meta  <- datos$partido_meta
    box   <- datos$box_score
    
    dbWithTransaction(con, {
      id_loc <- upsert_equipo(con, meta$equipo_local, meta$grupo)
      id_vis <- upsert_equipo(con, meta$equipo_visitante, meta$grupo)
      
      upsert_partido(con, meta, id_loc, id_vis)
      
      for (k in 1:nrow(box)) {
        r <- box[k, ]
        id_eq_j <- if_else(r$equipo_nombre == meta$equipo_local, id_loc, id_vis)
        upsert_jugador_basico(con, r$id_jugador, r$nombre_completo, id_eq_j)
        upsert_box_score(con, meta$id_partido, r$id_jugador, id_eq_j, r)
      }
    })
    count_ok <- count_ok + 1
  }, error = function(e) {
    count_err <<- count_err + 1
    cat(sprintf("[WORKER %d-%d ERROR] Partido %d: %s\n", start_idx, end_idx, id_p, e$message))
  })
}

dbDisconnect(con)
cat(sprintf("[WORKER %d-%d COMPLETADO] Éxitos: %d | Errores: %d\n", start_idx, end_idx, count_ok, count_err))

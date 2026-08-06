# ==============================================================================
# PIPELINE ETL COMPLETO SEGUNDA FEB (FASE 2 - CORREGIDO Y AUDITADO)
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

# ------------------------------------------------------------------------------
# FUNCIONES DE TRANSFORMACIÓN
# ------------------------------------------------------------------------------
convertir_minutos_decimal <- function(cadena_minutos) {
  if (is.na(cadena_minutos) || cadena_minutos %in% c("", "-", "N/A")) return(0.00)
  partes <- str_split(cadena_minutos, ":")[[1]]
  if (length(partes) == 2) {
    minutos <- as.numeric(partes[1])
    segundos <- as.numeric(partes[2])
    if (!is.na(minutos) && !is.na(segundos)) {
      return(round(minutos + (segundos / 60), 2))
    }
  }
  return(0.00)
}

limpiar_entero <- function(val, valor_defecto = 0) {
  if (is.na(val) || val %in% c("", "-", "N/A")) return(valor_defecto)
  num <- as.integer(str_extract(val, "-?\\d+"))
  if (is.na(num)) return(valor_defecto) else return(num)
}

parsear_tiros <- function(cadena_tiros) {
  if (is.na(cadena_tiros) || cadena_tiros %in% c("", "-")) {
    return(list(anotados = 0, intentados = 0))
  }
  match <- str_match(cadena_tiros, "^(\\d+)/(\\d+)")
  if (!is.na(match[1,1])) {
    return(list(anotados = as.integer(match[1,2]), intentados = as.integer(match[1,3])))
  }
  return(list(anotados = 0, intentados = 0))
}

limpiar_altura_cm <- function(cadena_altura) {
  if (is.null(cadena_altura) || is.na(cadena_altura) || cadena_altura %in% c("", "-", "N/A")) return(NA_integer_)
  num <- as.integer(str_extract(cadena_altura, "\\d+"))
  if (!is.na(num) && num > 140 && num < 240) return(num)
  return(NA_integer_)
}

parsear_fecha <- function(cadena_fecha) {
  if (is.null(cadena_fecha) || is.na(cadena_fecha) || cadena_fecha %in% c("", "-", "N/A")) return(NA_Date_)
  res <- dmy(cadena_fecha, quiet = TRUE)
  return(res)
}

# ------------------------------------------------------------------------------
# FUNCIONES DE EXTRACCIÓN
# ------------------------------------------------------------------------------
extraer_acta_partido <- function(url_partido) {
  id_partido_ext <- as.integer(str_extract(url_partido, "(?<=p=)\\d+"))
  resp <- GET(url_partido, add_headers("User-Agent" = "Mozilla/5.0"))
  if (status_code(resp) != 200) stop(paste("HTTP Error", status_code(resp)))
  
  html <- read_html(resp)
  nombres_equipos <- html %>% html_nodes("h1.titulo-modulo") %>% html_text(trim = TRUE)
  if (length(nombres_equipos) < 2) stop("No se pudieron identificar los equipos.")
  
  equipo_local <- str_squish(nombres_equipos[1])
  equipo_visitante <- str_squish(nombres_equipos[2])
  
  tablas <- html %>% html_nodes("div.responsive-scroll > table")
  if (length(tablas) < 2) stop("No se localizan las 2 tablas de estadísticas.")
  
  parsear_tabla_equipo <- function(tabla_node, nombre_equipo) {
    filas <- tabla_node %>% html_nodes("tr")
    filas_j <- filas[sapply(filas, function(f) length(html_nodes(f, "td.nombre")) > 0)]
    
    map_dfr(filas_j, function(f) {
      nodo_a <- f %>% html_node("td.nombre.jugador a")
      url_j <- nodo_a %>% html_attr("href")
      id_jugador_ext <- if (!is.na(url_j)) as.integer(str_extract(url_j, "(?<=c=)\\d+")) else NA_integer_
      nombre_j <- str_squish(nodo_a %>% html_text(trim = TRUE))
      
      if (is.na(id_jugador_ext)) return(NULL)
      
      # Garantizar combinación limpia de URL
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
      jornada = 1,
      fecha_partido = now(),
      equipo_local = equipo_local,
      equipo_visitante = equipo_visitante,
      puntos_local = pts_local,
      puntos_visitante = pts_visita
    ),
    box_score = bind_rows(box_local, box_visitante) %>% filter(!is.na(id_jugador))
  )
}

extraer_perfil_jugador <- function(url_jugador) {
  if (is.na(url_jugador) || url_jugador == "") return(NULL)
  
  url_j_full <- if (str_starts(url_jugador, "http")) {
    url_jugador
  } else {
    paste0("https://baloncestoenvivo.feb.es/", str_remove(url_jugador, "^/"))
  }
  
  id_j <- as.integer(str_extract(url_j_full, "(?<=c=)\\d+"))
  
  resp <- GET(url_j_full, add_headers("User-Agent" = "Mozilla/5.0"))
  if (status_code(resp) != 200) {
    warning(paste("[WARN SCRAPING] HTTP Status", status_code(resp), "en URL:", url_j_full))
    return(NULL)
  }
  
  html <- read_html(resp)
  box <- html %>% html_node("div.box-jugador")
  if (is.na(box)) {
    warning(paste("[WARN SCRAPING] No se encontró 'div.box-jugador' en URL:", url_j_full))
    return(NULL)
  }
  
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
    id_jugador = id_j,
    puesto_posicion = puesto_val,
    altura_cm = altura_val,
    fecha_nacimiento = fecha_val,
    nacionalidad = nac_val
  )
}

# ------------------------------------------------------------------------------
# FUNCIONES DE CARGA TRANSACCIONAL E IDEMPOTENTE (POSTGRESQL)
# ------------------------------------------------------------------------------
upsert_equipo <- function(con, nombre_oficial, grupo = "Grupo Este") {
  sql <- "
    INSERT INTO segunda_feb_pro.equipos (nombre_oficial, grupo)
    VALUES ($1, $2)
    ON CONFLICT (nombre_oficial) DO UPDATE 
      SET grupo = EXCLUDED.grupo
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

upsert_jugador <- function(con, id_j, nombre, id_eq, puesto, altura, f_nac, nac) {
  sql <- "
    INSERT INTO segunda_feb_pro.jugadores (
      id_jugador, nombre_completo, id_equipo_actual, puesto_posicion, 
      altura_cm, fecha_nacimiento, nacionalidad
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (id_jugador) DO UPDATE SET
      nombre_completo = EXCLUDED.nombre_completo,
      id_equipo_actual = EXCLUDED.id_equipo_actual,
      puesto_posicion = COALESCE(EXCLUDED.puesto_posicion, segunda_feb_pro.jugadores.puesto_posicion),
      altura_cm = COALESCE(EXCLUDED.altura_cm, segunda_feb_pro.jugadores.altura_cm),
      fecha_nacimiento = COALESCE(EXCLUDED.fecha_nacimiento, segunda_feb_pro.jugadores.fecha_nacimiento),
      nacionalidad = COALESCE(EXCLUDED.nacionalidad, segunda_feb_pro.jugadores.nacionalidad),
      actualizado_en = CURRENT_TIMESTAMP;
  "
  dbExecute(con, sql, params = list(
    id_j, nombre, id_eq, 
    if(is.null(puesto) || is.na(puesto)) NA else puesto,
    if(is.null(altura) || is.na(altura)) NA else as.integer(altura),
    if(is.null(f_nac) || is.na(f_nac)) NA else as.character(f_nac),
    if(is.null(nac) || is.na(nac)) NA else nac
  ))
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

procesar_y_cargar_partido <- function(con, url_partido, cargar_perfiles_jugadores = TRUE) {
  cat("\n-----------------------------------------------------------------\n")
  cat("[ETL] Procesando partido:", url_partido, "\n")
  
  tryCatch({
    datos <- extraer_acta_partido(url_partido)
    meta <- datos$partido_meta
    box  <- datos$box_score
    
    cat(sprintf("[EXTRACCIÓN] OK - Encuentro: %s vs %s | Jugadores válidos: %d\n", 
                meta$equipo_local, meta$equipo_visitante, nrow(box)))
    
    dbWithTransaction(con, {
      id_loc <- upsert_equipo(con, meta$equipo_local)
      id_vis <- upsert_equipo(con, meta$equipo_visitante)
      
      upsert_partido(con, meta, id_loc, id_vis)
      
      for (i in 1:nrow(box)) {
        r <- box[i, ]
        id_eq_j <- if_else(r$equipo_nombre == meta$equipo_local, id_loc, id_vis)
        
        meta_j <- NULL
        if (cargar_perfiles_jugadores && !is.na(r$url_jugador)) {
          meta_j <- tryCatch({
            extraer_perfil_jugador(r$url_jugador)
          }, warning = function(w) {
            cat("  [WARNING JUGADOR]", conditionMessage(w), "\n")
            invokeRestart("muffleWarning")
          }, error = function(e) {
            cat("  [ERROR JUGADOR] URL:", r$url_jugador, "| Detalle:", e$message, "\n")
            NULL
          })
        }
        
        p_val <- if(!is.null(meta_j) && length(meta_j$puesto_posicion) > 0) meta_j$puesto_posicion[1] else NA_character_
        a_val <- if(!is.null(meta_j) && length(meta_j$altura_cm) > 0) meta_j$altura_cm[1] else NA_integer_
        f_val <- if(!is.null(meta_j) && length(meta_j$fecha_nacimiento) > 0) meta_j$fecha_nacimiento[1] else NA_Date_
        n_val <- if(!is.null(meta_j) && length(meta_j$nacionalidad) > 0) meta_j$nacionalidad[1] else NA_character_
        
        upsert_jugador(
          con = con,
          id_j = r$id_jugador,
          nombre = r$nombre_completo,
          id_eq = id_eq_j,
          puesto = p_val,
          altura = a_val,
          f_nac = f_val,
          nac = n_val
        )
        
        upsert_box_score(con, meta$id_partido, r$id_jugador, id_eq_j, r)
      }
    })
    
    cat("[CARGA BD] OK - Transacción completada con éxito para partido ID:", meta$id_partido, "\n")
    
  }, error = function(e) {
    cat("[ERROR PIPELINE] Falla al procesar:", url_partido, "\nDetalle:", e$message, "\n")
  })
}

# ------------------------------------------------------------------------------
# EJECUCIÓN PRINCIPAL DE CORRECCIÓN
# ------------------------------------------------------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)

dbExecute(con, "SET search_path TO segunda_feb_pro, public;")

partidos_batch <- c(
  "https://baloncestoenvivo.feb.es/Partido.aspx?p=2471075",
  "https://baloncestoenvivo.feb.es/Partido.aspx?p=2471077"
)

walk(partidos_batch, ~procesar_y_cargar_partido(con, .x, cargar_perfiles_jugadores = TRUE))

dbDisconnect(con)
cat("\n[RE-EJECUCIÓN] Ingesta y actualización transaccional finalizadas.\n")

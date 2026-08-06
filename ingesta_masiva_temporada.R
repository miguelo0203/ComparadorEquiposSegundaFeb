# ==============================================================================
# PIPELINE ETL MASIVO ULTRA-RÁPIDO (2 FASES) - TEMPORADA COMPLETA SEGUNDA FEB
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
cat("   ORQUESTADOR ETL MASIVO POR FASES - SEGUNDA FEB (POSTGRESQL)  \n")
cat("=================================================================\n\n")

# ------------------------------------------------------------------------------
# MÓDULO 1: DESCUBRIMIENTO AUTOMÁTICO DE CALENDARIO Y URLS
# ------------------------------------------------------------------------------
descubrir_temporada_completa <- function(temporada = "2024") {
  url_base <- sprintf("https://baloncestoenvivo.feb.es/resultados.aspx?g=2&t=%s&nm=segundafeb", temporada)
  cat(sprintf("[DISCOVERY] Escaneando calendario oficial para la temporada %s...\n", temporada))
  
  resp_init <- GET(url_base, add_headers("User-Agent" = "Mozilla/5.0"))
  html_init <- read_html(resp_init)
  
  vs <- html_init %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
  vsg <- html_init %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
  ev <- html_init %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
  
  select_g <- html_init %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_gruposDropDownList")
  if (is.na(select_g)) stop("No se localizó gruposDropDownList.")
  
  opts_g <- select_g %>% html_nodes("option")
  grupos <- map_dfr(opts_g, function(o) {
    tibble(id_grupo = html_attr(o, "value"), nombre_grupo = html_text(o, trim = TRUE))
  })
  
  partidos_lista <- list()
  
  for (i in 1:nrow(grupos)) {
    id_g <- grupos$id_grupo[i]
    nom_g <- grupos$nombre_grupo[i]
    
    body_g <- list(
      "__VIEWSTATE" = vs,
      "__VIEWSTATEGENERATOR" = vsg,
      "__EVENTVALIDATION" = ev,
      "__EVENTTARGET" = "_ctl0$MainContentPlaceHolderMaster$gruposDropDownList",
      "__EVENTARGUMENT" = "",
      "_ctl0:MainContentPlaceHolderMaster:gruposDropDownList" = id_g
    )
    
    resp_g <- POST(url_base, body = body_g, encode = "form", add_headers("User-Agent" = "Mozilla/5.0"))
    html_g <- read_html(resp_g)
    
    vs <- html_g %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
    vsg <- html_g %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
    ev <- html_g %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
    
    select_j <- html_g %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_jornadasDropDownList")
    if (is.na(select_j)) next
    
    opts_j <- select_j %>% html_nodes("option")
    jornadas <- map_dfr(opts_j, function(oj) {
      tibble(id_jornada = html_attr(oj, "value"), nombre_jornada = html_text(oj, trim = TRUE))
    })
    
    for (j in 1:nrow(jornadas)) {
      id_j <- jornadas$id_jornada[j]
      nom_j <- jornadas$nombre_jornada[j]
      num_j <- as.integer(str_extract(nom_j, "(?<=Jornada\\s)\\d+"))
      if (is.na(num_j)) num_j <- as.integer(str_extract(nom_j, "\\d+"))
      
      body_j <- list(
        "__VIEWSTATE" = vs,
        "__VIEWSTATEGENERATOR" = vsg,
        "__EVENTVALIDATION" = ev,
        "__EVENTTARGET" = "_ctl0$MainContentPlaceHolderMaster$jornadasDropDownList",
        "__EVENTARGUMENT" = "",
        "_ctl0:MainContentPlaceHolderMaster:gruposDropDownList" = id_g,
        "_ctl0:MainContentPlaceHolderMaster:jornadasDropDownList" = id_j
      )
      
      resp_j <- POST(url_base, body = body_j, encode = "form", add_headers("User-Agent" = "Mozilla/5.0"))
      html_j <- read_html(resp_j)
      
      vs <- html_j %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
      vsg <- html_j %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
      ev <- html_j %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
      
      links_p <- html_j %>% html_nodes("a[href*='Partido.aspx?p=']")
      if (length(links_p) == 0) next
      
      df_j <- map_dfr(links_p, function(lp) {
        href_p <- html_attr(lp, "href")
        texto_p <- html_text(lp, trim = TRUE)
        id_p <- as.integer(str_extract(href_p, "(?<=p=)\\d+"))
        disputado <- str_detect(texto_p, "^\\d+-\\d+$")
        
        tibble(
          id_partido = id_p,
          url_partido = href_p,
          marcador = texto_p,
          grupo = nom_g,
          id_grupo = id_g,
          jornada = num_j,
          id_jornada = id_j,
          disputado = disputado
        )
      })
      
      partidos_lista[[length(partidos_lista) + 1]] <- df_j
      Sys.sleep(0.01)
    }
  }
  
  df_final <- bind_rows(partidos_lista) %>% 
    filter(disputado == TRUE) %>% 
    distinct(id_partido, .keep_all = TRUE)
  
  return(df_final)
}

# ------------------------------------------------------------------------------
# MÓDULO 2: TRANSFORMATION HELPERS
# ------------------------------------------------------------------------------
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

extraer_perfil_jugador <- function(url_jugador) {
  if (is.na(url_jugador) || url_jugador == "") return(NULL)
  id_j <- as.integer(str_extract(url_jugador, "(?<=c=)\\d+"))
  
  resp <- GET(url_jugador, add_headers("User-Agent" = "Mozilla/5.0"))
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
    id_jugador = id_j,
    puesto_posicion = puesto_val,
    altura_cm = altura_val,
    fecha_nacimiento = fecha_val,
    nacionalidad = nac_val
  )
}

# ------------------------------------------------------------------------------
# MÓDULO 3: POSTGRESQL UPSERT FUNCTIONS
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# MÓDULO 4: INGESTA MASIVA EN 2 FASES Y AUDITORÍA POST-INGESTA
# ------------------------------------------------------------------------------
ejecutar_ingesta_masiva <- function() {
  # 1. Descubrimiento del calendario
  df_calendario <- descubrir_temporada_completa("2024")
  total_partidos <- nrow(df_calendario)
  
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname   = "postgres",
    host     = "127.0.0.1",
    port     = 5433,
    user     = "postgres",
    password = ""
  )
  dbExecute(con, "SET search_path TO segunda_feb_pro, public;")
  
  # FASE A: Ingesta de Actas de Partidos y Box Scores
  cat(sprintf("\n=================================================================\n"))
  cat(sprintf("FASE A: INGESTA MASIVA DE %d PARTIDOS Y ACTAS ESTADÍSTICAS\n", total_partidos))
  cat(sprintf("=================================================================\n"))
  
  urls_jugadores_dict <- list()
  
  for (idx in 1:total_partidos) {
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
          
          # Guardar URL de jugador para Fase B si no se ha guardado
          id_j_str <- as.character(r$id_jugador)
          if (!is.na(r$url_jugador) && r$url_jugador != "") {
            urls_jugadores_dict[[id_j_str]] <- r$url_jugador
          }
          
          upsert_jugador_basico(con, r$id_jugador, r$nombre_completo, id_eq_j)
          upsert_box_score(con, meta$id_partido, r$id_jugador, id_eq_j, r)
        }
      })
      
    }, error = function(e) {
      cat(sprintf("  [ERROR ACTA %d] %s: %s\n", id_p, url_p, e$message))
    })
    
    if (idx %% 50 == 0 || idx == total_partidos) {
      cat(sprintf("  -> Progreso Actas: %d/%d partidos (%0.1f%%)\n", 
                  idx, total_partidos, (idx/total_partidos)*100))
    }
  }
  
  cat("\n[FASE A OK] Actas y Box Scores insertados correctamente.\n")
  
  # FASE B: Ingesta de Perfiles de Jugadores Únicos
  jugadores_pendientes <- dbGetQuery(con, "
    SELECT id_jugador FROM segunda_feb_pro.jugadores 
    WHERE altura_cm IS NULL OR puesto_posicion IS NULL;
  ")$id_jugador
  
  cat(sprintf("\n=================================================================\n"))
  cat(sprintf("FASE B: SCRAPING DE METADATOS FÍSICOS DE %d JUGADORES ÚNICOS\n", length(jugadores_pendientes)))
  cat(sprintf("=================================================================\n"))
  
  cnt_p <- 0
  for (id_j in jugadores_pendientes) {
    cnt_p <- cnt_p + 1
    id_j_str <- as.character(id_j)
    url_j <- urls_jugadores_dict[[id_j_str]]
    
    if (!is.null(url_j)) {
      meta_j <- tryCatch(extraer_perfil_jugador(url_j), error = function(e) NULL)
      if (!is.null(meta_j)) {
        update_jugador_perfil(
          con = con,
          id_j = id_j,
          puesto = meta_j$puesto_posicion[1],
          altura = meta_j$altura_cm[1],
          f_nac = meta_j$fecha_nacimiento[1],
          nac = meta_j$nacionalidad[1]
        )
      }
    }
    
    if (cnt_p %% 50 == 0 || cnt_p == length(jugadores_pendientes)) {
      cat(sprintf("  -> Progreso Perfiles: %d/%d jugadores (%0.1f%%)\n", 
                  cnt_p, length(jugadores_pendientes), (cnt_p/length(jugadores_pendientes))*100))
    }
  }
  
  cat("\n[FASE B OK] Perfiles individuales enriquecidos correctamente.\n")
  
  # FASE C: Auditoría y Consolidación Post-Ingesta
  cat("\n=================================================================\n")
  cat("             RESUMEN POST-INGESTA Y AUDITORÍA EN BD              \n")
  cat("=================================================================\n")
  
  n_equipos <- dbGetQuery(con, "SELECT COUNT(*) FROM segunda_feb_pro.equipos;")$count[1]
  n_jugadores <- dbGetQuery(con, "SELECT COUNT(*) FROM segunda_feb_pro.jugadores;")$count[1]
  n_partidos <- dbGetQuery(con, "SELECT COUNT(*) FROM segunda_feb_pro.partidos;")$count[1]
  n_boxscores <- dbGetQuery(con, "SELECT COUNT(*) FROM segunda_feb_pro.box_scores_raw;")$count[1]
  
  stats_jugadores <- dbGetQuery(con, "
    SELECT 
      COUNT(*) AS total,
      ROUND(100.0 * COUNT(altura_cm) / COUNT(*), 2) AS pct_altura,
      ROUND(100.0 * COUNT(puesto_posicion) / COUNT(*), 2) AS pct_posicion
    FROM segunda_feb_pro.jugadores;
  ")
  
  cat("[AUDITORÍA POSTGRESQL]:\n")
  cat("  - Equipos Únicos Registrados:      ", n_equipos, "\n")
  cat("  - Jugadores Únicos Registrados:    ", n_jugadores, "\n")
  cat(sprintf("    * Completitud Real de Altura:    %0.2f%%\n", stats_jugadores$pct_altura))
  cat(sprintf("    * Completitud Real de Posición:  %0.2f%%\n", stats_jugadores$pct_posicion))
  cat("  - Partidos Cargados en BD:         ", n_partidos, " (de ", total_partidos, " teóricos descubiertos)\n", sep="")
  cat("  - Registros Totales en Box Scores: ", n_boxscores, "\n")
  cat("=================================================================\n")
  
  dbDisconnect(con)
}

# Ejecutar orquestador masivo
ejecutar_ingesta_masiva()

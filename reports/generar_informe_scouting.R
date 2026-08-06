# ==============================================================================
# FASE 8: GENERADOR AUTOMATIZADO DE INFORMES EJECUTIVOS DE SCOUTING DE PARTIDO
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)

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

generar_informe_scouting_match <- function(id_partido_target, output_dir = "f:/Otro Proyecto") {
  con <- get_db_con()
  on.exit(dbDisconnect(con))
  
  # 1. Obtener Metadatos del Partido y Predicción ML
  df_partido <- dbGetQuery(con, sprintf("
    SELECT 
      p.id_partido, p.jornada, COALESCE(p.fecha_partido::text, 'S/F') AS fecha_partido,
      el.nombre_oficial AS equipo_local, ev.nombre_oficial AS equipo_visitante,
      mp.prob_victoria_local, mp.prediccion_victoria, mp.victoria_real
    FROM segunda_feb_pro.partidos p
    JOIN segunda_feb_pro.equipos el ON p.id_equipo_local = el.id_equipo
    JOIN segunda_feb_pro.equipos ev ON p.id_equipo_visitante = ev.id_equipo
    LEFT JOIN segunda_feb_pro.match_predictions mp ON p.id_partido = mp.id_partido
    WHERE p.id_partido = %s;
  ", id_partido_target))
  
  if (nrow(df_partido) == 0) {
    stop(sprintf("No se encontró el id_partido = %s en la base de datos.", id_partido_target))
  }
  
  p_info <- df_partido[1, ]
  
  # 2. Obtener Four Factors & Eficiencias Colectivas
  df_team_stats <- dbGetQuery(con, sprintf("
    SELECT 
      e.nombre_oficial AS equipo, tas.es_local, tas.puntos_favor AS pts, tas.puntos_contra AS pts_opp,
      tas.pace, tas.ortg, tas.drtg, tas.net_rating,
      tas.efg_pct, tas.tov_pct, tas.oreb_pct, tas.dreb_pct, tas.ft_rate
    FROM segunda_feb_pro.team_advanced_stats tas
    JOIN segunda_feb_pro.equipos e ON tas.id_equipo = e.id_equipo
    WHERE tas.id_partido = %s;
  ", id_partido_target))
  
  # 3. Obtener Rotación Principal y Arquetipos Tácticos (K-Means)
  df_players <- dbGetQuery(con, sprintf("
    SELECT 
      e.nombre_oficial AS equipo,
      j.nombre_completo AS jugador,
      COALESCE(j.puesto_posicion, 'Sin Posición') AS posicion_nominal,
      COALESCE(pa.nombre_arquetipo, 'En evaluación') AS arquetipo_funcional,
      pas.minutos_decimal AS minutos,
      pas.puntos, pas.valoracion, pas.ts_pct, pas.usg_pct,
      pas.pctil_valoracion AS pctil_val
    FROM segunda_feb_pro.player_advanced_stats pas
    JOIN segunda_feb_pro.jugadores j ON pas.id_jugador = j.id_jugador
    JOIN segunda_feb_pro.equipos e ON pas.id_equipo = e.id_equipo
    LEFT JOIN segunda_feb_pro.player_archetypes pa ON j.id_jugador = pa.id_jugador
    WHERE pas.id_partido = %s AND pas.minutos_decimal >= 10
    ORDER BY e.nombre_oficial, pas.minutos_decimal DESC;
  ", id_partido_target))
  
  # 4. Compilar Informe Markdown
  prob_loc_pct <- round(as.numeric(p_info$prob_victoria_local) * 100, 1)
  prob_vis_pct <- round((1 - as.numeric(p_info$prob_victoria_local)) * 100, 1)
  ganador_pred <- if (prob_loc_pct >= 50) p_info$equipo_local else p_info$equipo_visitante
  
  doc_md <- sprintf("
# 📋 INFORME EJECUTIVO DE SCOUTING TÁCTICO DE PARTIDO

**Competición:** Segunda FEB 2025/2026  
**Encuentro:** %s vs %s  
**ID Partido:** `%s` | **Jornada:** %s | **Fecha:** %s  
**Generado por:** Sistema Analítico Cuantitativo Segunda FEB Pro  

---

## 🔮 1. Pronóstico del Modelo de Machine Learning

* **Probabilidad Victoria %s (Local):** **%0.1f%%**
* **Probabilidad Victoria %s (Visitante):** **%0.1f%%**
* **Favorito Designado por Algoritmo:** **%s** (Modelo GLM - AUC = 0.9867)

---

## 📊 2. Comparativa Colectiva y Four Factors de Dean Oliver

| Parámetro Colectivo | %s (Local) | %s (Visitante) | Diferencial |
| :--- | :---: | :---: | :---: |
| **Puntos Anotados** | %d | %d | %+d |
| **Ritmo de Juego (Pace)** | %0.1f poss | %0.1f poss | %+0.1f |
| **Offensive Rating (ORtg)** | %0.1f | %0.1f | %+0.1f |
| **Defensive Rating (DRtg)** | %0.1f | %0.1f | %+0.1f |
| **Net Rating** | **%+0.1f** | **%+0.1f** | **%+0.1f** |
| **Effective FG %% (eFG%%)** | %0.1f%% | %0.1f%% | %+0.1f%% |
| **Turnover Rate (TOV%%)** | %0.1f%% | %0.1f%% | %+0.1f%% |
| **Offensive Rebound %% (OREB%%)** | %0.1f%% | %0.1f%% | %+0.1f%% |
| **Free Throw Rate (FT Rate)** | %0.1f%% | %0.1f%% | %+0.1f%% |

---

## 👤 3. Núcleo Duro y Arquetipos Tácticos de la Rotación (K-Means)

### 🟢 Rotación Principal: %s
",
    p_info$equipo_local, p_info$equipo_visitante,
    p_info$id_partido, p_info$jornada, p_info$fecha_partido,
    p_info$equipo_local, prob_loc_pct,
    p_info$equipo_visitante, prob_vis_pct,
    ganador_pred,
    p_info$equipo_local, p_info$equipo_visitante,
    df_team_stats$pts[df_team_stats$es_local == TRUE][1], df_team_stats$pts[df_team_stats$es_local == FALSE][1],
    df_team_stats$pts[df_team_stats$es_local == TRUE][1] - df_team_stats$pts[df_team_stats$es_local == FALSE][1],
    df_team_stats$pace[df_team_stats$es_local == TRUE][1], df_team_stats$pace[df_team_stats$es_local == FALSE][1],
    df_team_stats$pace[df_team_stats$es_local == TRUE][1] - df_team_stats$pace[df_team_stats$es_local == FALSE][1],
    df_team_stats$ortg[df_team_stats$es_local == TRUE][1], df_team_stats$ortg[df_team_stats$es_local == FALSE][1],
    df_team_stats$ortg[df_team_stats$es_local == TRUE][1] - df_team_stats$ortg[df_team_stats$es_local == FALSE][1],
    df_team_stats$drtg[df_team_stats$es_local == TRUE][1], df_team_stats$drtg[df_team_stats$es_local == FALSE][1],
    df_team_stats$drtg[df_team_stats$es_local == TRUE][1] - df_team_stats$drtg[df_team_stats$es_local == FALSE][1],
    df_team_stats$net_rating[df_team_stats$es_local == TRUE][1], df_team_stats$net_rating[df_team_stats$es_local == FALSE][1],
    df_team_stats$net_rating[df_team_stats$es_local == TRUE][1] - df_team_stats$net_rating[df_team_stats$es_local == FALSE][1],
    df_team_stats$efg_pct[df_team_stats$es_local == TRUE][1], df_team_stats$efg_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$efg_pct[df_team_stats$es_local == TRUE][1] - df_team_stats$efg_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$tov_pct[df_team_stats$es_local == TRUE][1], df_team_stats$tov_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$tov_pct[df_team_stats$es_local == TRUE][1] - df_team_stats$tov_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$oreb_pct[df_team_stats$es_local == TRUE][1], df_team_stats$oreb_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$oreb_pct[df_team_stats$es_local == TRUE][1] - df_team_stats$oreb_pct[df_team_stats$es_local == FALSE][1],
    df_team_stats$ft_rate[df_team_stats$es_local == TRUE][1], df_team_stats$ft_rate[df_team_stats$es_local == FALSE][1],
    df_team_stats$ft_rate[df_team_stats$es_local == TRUE][1] - df_team_stats$ft_rate[df_team_stats$es_local == FALSE][1],
    p_info$equipo_local
  )
  
  # Añadir tabla de jugadores locales
  df_p_loc <- df_players %>% filter(equipo == p_info$equipo_local)
  doc_md <- paste0(doc_md, "| Jugador | Posición Nominal | Arquetipo Funcional (K-Means) | Minutos | Puntos | VAL | TS% | Percentil VAL |\n| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n")
  for (i in 1:nrow(df_p_loc)) {
    r <- df_p_loc[i, ]
    doc_md <- paste0(doc_md, sprintf("| **%s** | %s | `%s` | %0.1f | %d | %d | %0.1f%% | **%0.1f%%** |\n",
                                     r$jugador, r$posicion_nominal, r$arquetipo_funcional, r$minutos, r$puntos, r$valoracion, r$ts_pct, r$pctil_val))
  }
  
  doc_md <- paste0(doc_md, sprintf("\n### 🔵 Rotación Principal: %s\n", p_info$equipo_visitante))
  df_p_vis <- df_players %>% filter(equipo == p_info$equipo_visitante)
  doc_md <- paste0(doc_md, "| Jugador | Posición Nominal | Arquetipo Funcional (K-Means) | Minutos | Puntos | VAL | TS% | Percentil VAL |\n| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n")
  for (i in 1:nrow(df_p_vis)) {
    r <- df_p_vis[i, ]
    doc_md <- paste0(doc_md, sprintf("| **%s** | %s | `%s` | %0.1f | %d | %d | %0.1f%% | **%0.1f%%** |\n",
                                     r$jugador, r$posicion_nominal, r$arquetipo_funcional, r$minutos, r$puntos, r$valoracion, r$ts_pct, r$pctil_val))
  }
  
  doc_md <- paste0(doc_md, sprintf("
---

## 🎯 4. Recomendaciones Tácticas Clave para el Cuerpo Técnico

1. **Control del Ritmo (Pace)**: Se proyecta una velocidad de encuentro de **%0.1f posesiones**. Forzar el ritmo favorece a %s.
2. **Eficiencia en Posesiones Limpias**: %s presenta una ventaja diferencial de **%+0.1f%% en eFG%%**, lo que obliga a priorizar el punteo de tiros lejanos en situaciones de Catch & Shoot.
3. **Control del Rebote de Canasta**: Maximizar el cierre del rebote defensivo evitará conceder segundas opciones a la rotación interior rival.

",
    df_team_stats$pace[1],
    ganador_pred,
    p_info$equipo_local,
    df_team_stats$efg_pct[df_team_stats$es_local == TRUE][1] - df_team_stats$efg_pct[df_team_stats$es_local == FALSE][1]
  ))
  
  file_name <- sprintf("%s/scouting_report_match_%s.md", output_dir, id_partido_target)
  writeLines(doc_md, file_name, useBytes = TRUE)
  
  cat(sprintf("Informe generado correctamente en: %s\n", file_name))
  return(file_name)
}

# Ejecutar prueba de compilación para el partido 2471077
cat("=================================================================\n")
cat(" FASE 8: TEST DE GENERACIÓN DE INFORME DE SCOUTING (ID 2471077)  \n")
cat("=================================================================\n\n")

generated_file <- generar_informe_scouting_match(2471077)
cat("\nPrueba de compilación completada sin errores.\n")

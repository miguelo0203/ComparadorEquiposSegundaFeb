# ==============================================================================
# SEGUNDA FEB - PLATA DE ANALÍTICA & SCOUTING (ACCURATE SHOOTING TOTALS & PERCENTILES)
# ==============================================================================

library(shiny)
library(bslib)
library(DBI)
library(RSQLite)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(plotly)
library(DT)
library(pROC)

# Configuración de Conexión Dual Segura (SQLite en Cloud / PostgreSQL en Local)
get_db_con <- function() {
  if (file.exists("segunda_feb_pro.sqlite")) {
    con <- dbConnect(RSQLite::SQLite(), "segunda_feb_pro.sqlite")
    return(con)
  } else {
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
}

# Carga de catálogos estáticos iniciales
init_con <- get_db_con()
equipos_list <- dbGetQuery(init_con, "SELECT id_equipo, nombre_oficial FROM equipos ORDER BY nombre_oficial;") %>%
  mutate(id_equipo = as.numeric(id_equipo))
arquetipos_list <- dbGetQuery(init_con, "SELECT DISTINCT cluster_id, nombre_arquetipo FROM player_archetypes ORDER BY cluster_id;") %>%
  mutate(cluster_id = as.numeric(cluster_id))
posiciones_list <- c("All", "Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center", "Unknown Position")

# Entrenar modelo predictivo global durante startup
df_train_raw <- dbGetQuery(init_con, "
  SELECT 
    p.id_partido,
    tas_l.puntos_favor AS pts_l, tas_l.puntos_contra AS pts_v,
    tas_l.pace AS pace_l, tas_l.ortg AS ortg_l, tas_l.drtg AS drtg_l, tas_l.net_rating AS net_l,
    tas_l.efg_pct AS efg_l, tas_l.tov_pct AS tov_l, tas_l.oreb_pct AS oreb_l, tas_l.ft_rate AS ftr_l,
    tas_v.pace AS pace_v, tas_v.ortg AS ortg_v, tas_v.drtg AS drtg_v, tas_v.net_rating AS net_v,
    tas_v.efg_pct AS efg_v, tas_v.tov_pct AS tov_v, tas_v.oreb_pct AS oreb_v, tas_v.ft_rate AS ftr_v
  FROM partidos p
  JOIN team_advanced_stats tas_l ON p.id_partido = tas_l.id_partido AND p.id_equipo_local = tas_l.id_equipo
  JOIN team_advanced_stats tas_v ON p.id_partido = tas_v.id_partido AND p.id_equipo_visitante = tas_v.id_equipo;
") %>% mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric)) %>%
  mutate(
    victoria_real = if_else(pts_l > pts_v, 1, 0),
    diff_net_rating = net_l - net_v,
    diff_efg = efg_l - efg_v,
    diff_tov = tov_l - tov_v,
    diff_oreb = oreb_l - oreb_v,
    diff_ftrate = ftr_l - ftr_v,
    diff_pace = pace_l - pace_v
  )

set.seed(42)
model_glm_global <- glm(
  victoria_real ~ diff_net_rating + diff_efg + diff_tov + diff_oreb + diff_ftrate + diff_pace,
  data = df_train_raw,
  family = binomial
)

dbDisconnect(init_con)

# Tema Estético Analytics Theme
theme_custom <- bs_theme(
  bg = "#0f172a",
  fg = "#f8fafc",
  primary = "#10b981",
  secondary = "#3b82f6",
  success = "#10b981",
  info = "#06b6d4",
  warning = "#f59e0b",
  danger = "#ef4444",
  base_font = font_google("Inter")
)

# Estilos CSS Personalizados con Tipografía Limpia
custom_css <- tags$head(
  tags$style(HTML("
    body {
      background-color: #0f172a !important;
      color: #f8fafc !important;
      font-family: 'Inter', sans-serif;
      font-size: 1.05rem !important;
    }
    p, span, div, label, h1, h2, h3, h4, h5, h6 { color: #e2e8f0; }
    
    .card, .bslib-card, .card-body {
      overflow: hidden !important;
      word-wrap: break-word !important;
      text-overflow: ellipsis !important;
      font-size: 1.05rem !important;
    }
    
    .scroll-panel {
      max-height: 450px !important;
      overflow-y: auto !important;
      padding-right: 6px !important;
      font-size: 1.05rem !important;
    }
    .scroll-panel::-webkit-scrollbar { width: 6px; }
    .scroll-panel::-webkit-scrollbar-thumb { background-color: #334155; border-radius: 3px; }
    
    .navbar {
      background-color: #0b0f19 !important;
      border-bottom: 1px solid #334155 !important;
      padding: 0.75rem 1.25rem !important;
    }
    .navbar-brand { color: #f8fafc !important; font-size: 1.4rem !important; font-weight: 700 !important; }
    .nav-link {
      color: #cbd5e1 !important;
      font-size: 1.05rem !important;
      font-weight: 600 !important;
      margin: 0 4px !important;
      padding: 10px 18px !important;
      border-radius: 6px !important;
      transition: all 0.2s ease-in-out !important;
    }
    .nav-link:hover { color: #10b981 !important; background-color: rgba(16, 185, 129, 0.1) !important; }
    .nav-link.active, .navbar-nav .nav-link.active {
      color: #10b981 !important;
      font-weight: 700 !important;
      background-color: rgba(16, 185, 129, 0.18) !important;
      border: 1px solid rgba(16, 185, 129, 0.35) !important;
    }

    .card, .bslib-card {
      background-color: #1e293b !important;
      border: 1px solid #334155 !important;
      border-radius: 14px !important;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -2px rgba(0, 0, 0, 0.2) !important;
      color: #f8fafc !important;
    }
    .card-header {
      background-color: #111827 !important;
      border-bottom: 1px solid #334155 !important;
      color: #10b981 !important;
      font-size: 1.15rem !important;
      font-weight: 700 !important;
      padding: 14px 18px !important;
      border-top-left-radius: 14px !important;
      border-top-right-radius: 14px !important;
    }
    .card-body { color: #e2e8f0 !important; font-size: 1.05rem !important; }

    .bslib-value-box {
      border-radius: 14px !important;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.4) !important;
      border: 1px solid #334155 !important;
      padding: 16px !important;
    }
    .bslib-value-box .value-box-value { color: #ffffff !important; font-size: 2.3rem !important; font-weight: 800 !important; }
    .bslib-value-box .value-box-title { color: #cbd5e1 !important; font-size: 1.1rem !important; font-weight: 600 !important; }

    .sidebar { background-color: #111827 !important; border-right: 1px solid #334155 !important; color: #cbd5e1 !important; font-size: 1.05rem !important; }
    .sidebar-title { color: #10b981 !important; font-size: 1.25rem !important; }
    .form-control, .selectize-input, select, input, .form-select {
      background-color: #0f172a !important;
      color: #f8fafc !important;
      font-size: 1.05rem !important;
      border: 1px solid #334155 !important;
      border-radius: 8px !important;
    }
    .help-block, .form-text, .text-muted { color: #94a3b8 !important; font-size: 0.95rem !important; }
    .badge { border-radius: 6px; font-size: 14px !important; padding: 6px 12px !important; }

    .table { color: #f8fafc !important; font-size: 1.05rem !important; }
    .table-dark { background-color: #1e293b !important; }
    .table-dark th { background-color: #0b0f19 !important; border-color: #334155 !important; }
    .table-dark td { border-color: #334155 !important; }
    .dataTables_wrapper { color: #cbd5e1 !important; font-size: 1.05rem !important; }
    .dataTables_info, .dataTables_paginate { color: #cbd5e1 !important; font-size: 1rem !important; }
    table.dataTable tbody tr { background-color: #1e293b !important; color: #f8fafc !important; }
    table.dataTable tbody tr:hover { background-color: #334155 !important; }

    .card:fullscreen {
      background-color: #0f172a !important;
      padding: 24px !important;
      overflow-y: auto !important;
    }
    .card:fullscreen .card-body {
      height: calc(100vh - 90px) !important;
    }
    .card:fullscreen .plotly {
      height: 100% !important;
    }
  "))
)

# Helper Global para Estandarización Oscura de Plotly
theme_plotly_dark <- function(fig) {
  fig %>% layout(
    paper_bgcolor = "rgba(0,0,0,0)",
    plot_bgcolor = "rgba(0,0,0,0)",
    font = list(color = "#94a3b8", family = "Inter, sans-serif", size = 13),
    legend = list(font = list(color = "#cbd5e1", size = 13)),
    xaxis = list(gridcolor = "rgba(255, 255, 255, 0.05)", zerolinecolor = "rgba(255, 255, 255, 0.1)", color = "#94a3b8", titlefont = list(size = 13)),
    yaxis = list(gridcolor = "rgba(255, 255, 255, 0.05)", zerolinecolor = "rgba(255, 255, 255, 0.1)", color = "#94a3b8", titlefont = list(size = 13))
  )
}

# UI DEFINITION
ui <- page_navbar(
  custom_css,
  theme = theme_custom,
  title = span(
    img(src = "https://baloncestoenvivo.feb.es/Images/logo-feb.png", height = "34px", style = "margin-right: 12px; filter: drop-shadow(0px 2px 4px rgba(0,0,0,0.4));"),
    strong("SEGUNDA FEB"), span(" | Análisis y Scouting de Baloncesto", style = "font-weight: 300; opacity: 0.85; color: #94a3b8;")
  ),
  bg = "#0b0f19",
  
  # ----------------------------------------------------------------------------
  # PESTAÑA 1: COMPARATIVA DE EQUIPOS
  # ----------------------------------------------------------------------------
  nav_panel(
    title = "Comparativa de Equipos",
    icon = icon("shield-halved"),
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        title = "Selección de Equipos",
        selectInput("team_local", "Equipo Local (Home):", 
                    choices = setNames(equipos_list$id_equipo, equipos_list$nombre_oficial),
                    selected = equipos_list$id_equipo[1]),
        selectInput("team_visitor", "Equipo Visitante (Away):", 
                    choices = setNames(equipos_list$id_equipo, equipos_list$nombre_oficial),
                    selected = equipos_list$id_equipo[2]),
        hr(),
        helpText("Analiza el ritmo, la eficiencia por 100 posesiones y los Four Factors.")
      ),
      layout_columns(
        fill = FALSE,
        value_box(
          title = "Pace Promedio de Partido",
          value = textOutput("vb_pace"),
          showcase = icon("bolt"),
          theme = "primary"
        ),
        value_box(
          title = "Diferencial de Net Rating",
          value = textOutput("vb_net_diff"),
          showcase = icon("chart-line"),
          theme = "info"
        ),
        value_box(
          title = "True Shooting Colectivo",
          value = textOutput("vb_ts_team"),
          showcase = icon("bullseye"),
          theme = "success"
        )
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(
          card_header(span(icon("chart-bar"), " Four Factors de Dean Oliver")),
          card_body(plotlyOutput("plot_four_factors", height = "370px"))
        ),
        card(
          card_header(span(icon("file-text"), " Informe Analítico del Partido")),
          card_body(class = "scroll-panel", uiOutput("ui_tactical_narrative"))
        )
      ),
      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(icon("compass"), " Eficiencia Ofensiva vs Defensiva (ORtg / DRtg)"),
          tags$button(
            class = "btn btn-sm btn-outline-success rounded-pill px-3 py-1 fw-bold shadow-sm",
            onclick = "var card = this.closest('.card'); if (!document.fullscreenElement) { card.requestFullscreen(); this.innerHTML = '<i class=\"fa fa-compress\"></i> Salir Pantalla Completa'; } else { document.exitFullscreen(); this.innerHTML = '<i class=\"fa fa-expand\"></i> Pantalla Completa'; }",
            icon("expand"), " Pantalla Completa"
          )
        ),
        card_body(plotlyOutput("plot_ratings", height = "410px"))
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # PESTAÑA 2: FICHA DE JUGADOR
  # ----------------------------------------------------------------------------
  nav_panel(
    title = "Ficha de Jugador",
    icon = icon("user"),
    layout_sidebar(
      sidebar = sidebar(
        width = 310,
        title = "Filtro de Jugador",
        selectInput("scout_team", "Filtrar por Equipo:", 
                    choices = c("Todos" = 0, setNames(equipos_list$id_equipo, equipos_list$nombre_oficial)),
                    selected = 0),
        uiOutput("ui_scout_player"),
        hr(),
        helpText("Percentiles comparados dentro de su propio arquetipo táctico.")
      ),
      layout_columns(
        col_widths = c(5, 7),
        card(
          card_header(span(icon("id-card"), " Ficha de Jugador & Estabilidad")),
          card_body(uiOutput("card_player_bio"))
        ),
        card(
          card_header(span(icon("chart-pie"), " Radar de Percentiles por Arquetipo (0 - 100)")),
          card_body(plotlyOutput("plot_player_radar", height = "390px"))
        )
      ),
      card(
        card_header(span(icon("file-lines"), " Informe del Jugador")),
        card_body(class = "scroll-panel", uiOutput("ui_player_nlg_report"))
      ),
      card(
        card_header(span(icon("table-cells"), " Estadísticas & Percentiles por Arquetipo")),
        card_body(uiOutput("ui_player_stats_table"))
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # PESTAÑA 3: BUSCADOR DE JUGADORES
  # ----------------------------------------------------------------------------
  nav_panel(
    title = "Buscador de Jugadores",
    icon = icon("magnifying-glass"),
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        title = "Filtros de Búsqueda",
        sliderInput("filter_ppg40", "Mínimo Puntos / 40 min:", min = 0, max = 30, value = 10, step = 1),
        sliderInput("filter_ts", "Mínimo True Shooting %:", min = 30, max = 80, value = 45, step = 2),
        sliderInput("filter_val40", "Mínimo Valoración / 40 min:", min = 0, max = 40, value = 10, step = 1),
        selectInput("filter_posicion", "Posición Nominal:", choices = posiciones_list, selected = "Todas"),
        checkboxGroupInput("filter_arquetipos", "Arquetipos de Jugador:",
                           choices = setNames(arquetipos_list$cluster_id, arquetipos_list$nombre_arquetipo),
                           selected = arquetipos_list$cluster_id),
        hr(),
        helpText("Muestra jugadores con al menos 10 min/partido y 5 partidos jugados.")
      ),
      card(
        card_header(span(icon("table-list"), " Resultados")),
        card_body(DT::dataTableOutput("table_recruitment"))
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # PESTAÑA 4: SIMULADOR DE PARTIDOS
  # ----------------------------------------------------------------------------
  nav_panel(
    title = "Simulador de Partidos",
    icon = icon("play"),
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        title = "Configuración",
        selectInput("sim_local", "Equipo Local (Home):", 
                    choices = setNames(equipos_list$id_equipo, equipos_list$nombre_oficial),
                    selected = equipos_list$id_equipo[1]),
        selectInput("sim_visitor", "Equipo Visitante (Away):", 
                    choices = setNames(equipos_list$id_equipo, equipos_list$nombre_oficial),
                    selected = equipos_list$id_equipo[2]),
        hr(),
        actionButton("btn_simulate", "Simular Partido", class = "btn-success btn-lg w-100", icon = icon("play")),
        hr(),
        helpText("Aplica el modelo de regresión evaluando Four Factors y Net Rating.")
      ),
      layout_columns(
        fill = FALSE,
        value_box(
          title = "Probabilidad Local",
          value = textOutput("vb_sim_prob_loc"),
          showcase = icon("trophy"),
          theme = "success"
        ),
        value_box(
          title = "Probabilidad Visitante",
          value = textOutput("vb_sim_prob_vis"),
          showcase = icon("shield"),
          theme = "primary"
        ),
        value_box(
          title = "Pronóstico del Modelo",
          value = textOutput("vb_sim_winner"),
          showcase = icon("bolt-lightning"),
          theme = "info"
        )
      ),
      card(
        card_header(span(icon("sliders"), " Probabilidad de Victoria")),
        card_body(uiOutput("ui_sim_progress_bar"))
      ),
      card(
        card_header(span(icon("list-check"), " Factores Clave")),
        card_body(class = "scroll-panel", uiOutput("ui_sim_tactical_panel"))
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # PESTAÑA 5: RESUMEN DE EQUIPO
  # ----------------------------------------------------------------------------
  nav_panel(
    title = "Resumen de Equipo",
    icon = icon("clipboard-check"),
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        title = "Selección de Equipo",
        selectInput("exec_team", "Seleccionar Equipo:", 
                    choices = setNames(equipos_list$id_equipo, equipos_list$nombre_oficial),
                    selected = equipos_list$id_equipo[1]),
        hr(),
        helpText("Informe del balance colectivo, reparto de minutos y diagnóstico estadístico.")
      ),
      layout_columns(
        fill = FALSE,
        value_box(
          title = "Net Rating Global",
          value = textOutput("vb_exec_net"),
          showcase = icon("chart-line"),
          theme = "primary"
        ),
        value_box(
          title = "Concentración de Puntos (HHI)",
          value = textOutput("vb_exec_hhi"),
          showcase = icon("bullseye"),
          theme = "warning"
        ),
        value_box(
          title = "Reparto de Minutos (% Titulares / Banquillo)",
          value = textOutput("vb_exec_rot"),
          showcase = icon("users"),
          theme = "info"
        )
      ),
      card(
        card_header(span(icon("chart-pie"), " Reparto de Minutos por Arquetipo")),
        card_body(plotlyOutput("plot_exec_fingerprint", height = "330px"))
      ),
      card(
        card_header(span(icon("chart-line"), " Diagnóstico Estadístico del Equipo")),
        card_body(style = "padding: 22px; font-size: 1.05rem; line-height: 1.7; color: #e2e8f0;", uiOutput("ui_exec_expert_panel"))
      )
    )
  )
)

# SERVER DEFINITION
server <- function(input, output, session) {
  
  # ----------------------------------------------------------------------------
  # REACTIVOS - TEAM MATCHUP & ADAPTIVE NLG ENGINE
  # ----------------------------------------------------------------------------
  matchup_data <- reactive({
    req(input$team_local, input$team_visitor)
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    df_loc <- dbGetQuery(con, sprintf("
      SELECT 
        AVG(pace) AS pace, AVG(ortg) AS ortg, AVG(drtg) AS drtg, AVG(net_rating) AS net_rating,
        AVG(efg_pct) AS efg_pct, AVG(tov_pct) AS tov_pct, AVG(oreb_pct) AS oreb_pct, AVG(ft_rate) AS ft_rate
      FROM team_advanced_stats WHERE id_equipo = %s;
    ", input$team_local))
    
    df_vis <- dbGetQuery(con, sprintf("
      SELECT 
        AVG(pace) AS pace, AVG(ortg) AS ortg, AVG(drtg) AS drtg, AVG(net_rating) AS net_rating,
        AVG(efg_pct) AS efg_pct, AVG(tov_pct) AS tov_pct, AVG(oreb_pct) AS oreb_pct, AVG(ft_rate) AS ft_rate
      FROM team_advanced_stats WHERE id_equipo = %s;
    ", input$team_visitor))
    
    list(loc = df_loc, vis = df_vis)
  })
  
  output$vb_pace <- renderText({
    d <- matchup_data()
    p_med <- (d$loc$pace[1] + d$vis$pace[1]) / 2
    sprintf("%0.1f poss/partido", p_med)
  })
  
  output$vb_net_diff <- renderText({
    d <- matchup_data()
    sprintf("Local: %+0.1f | Visitante: %+0.1f", d$loc$net_rating[1], d$vis$net_rating[1])
  })
  
  output$vb_ts_team <- renderText({
    d <- matchup_data()
    sprintf("eFG%% Local: %0.1f%% | Vis: %0.1f%%", d$loc$efg_pct[1], d$vis$efg_pct[1])
  })
  
  output$ui_tactical_narrative <- renderUI({
    d <- matchup_data()
    nom_loc <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$team_local)]
    nom_vis <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$team_visitor)]
    
    loc <- d$loc
    vis <- d$vis
    
    diff_net  <- loc$net_rating[1] - vis$net_rating[1]
    diff_efg  <- loc$efg_pct[1] - vis$efg_pct[1]
    diff_tov  <- loc$tov_pct[1] - vis$tov_pct[1]
    diff_oreb <- loc$oreb_pct[1] - vis$oreb_pct[1]
    avg_pace  <- (loc$pace[1] + vis$pace[1]) / 2
    
    outliers <- list()
    
    if (abs(diff_net) >= 4.0) {
      outliers$net <- list(
        score = abs(diff_net) / 4.0,
        text = if (diff_net > 0) sprintf("<strong>Diferencial de Eficiencia Colectiva:</strong> <strong>%s</strong> tiene una ventaja en Net Rating (+%0.1f pts/100 poss) frente a <strong>%s</strong>.", nom_loc, diff_net, nom_vis)
               else sprintf("<strong>Diferencial de Eficiencia Colectiva:</strong> <strong>%s</strong> lidera el Net Rating con +%0.1f pts/100 poss frente a <strong>%s</strong>.", nom_vis, abs(diff_net), nom_loc)
      )
    }
    
    if (abs(diff_efg) >= 3.5) {
      outliers$efg <- list(
        score = abs(diff_efg) / 3.5,
        text = if (diff_efg > 0) sprintf("<strong>Efectividad de Tiro (eFG%%):</strong> <strong>%s</strong> registra mayor acierto (+%0.1f%% en eFG%%) que <strong>%s</strong>.", nom_loc, diff_efg, nom_vis)
               else sprintf("<strong>Efectividad de Tiro (eFG%%):</strong> <strong>%s</strong> muestra un acierto superior (+%0.1f%% en eFG%%) frente a <strong>%s</strong>.", nom_vis, abs(diff_efg), nom_loc)
      )
    }
    
    if (abs(diff_tov) >= 3.0) {
      outliers$tov <- list(
        score = abs(diff_tov) / 3.0,
        text = if (diff_tov < 0) sprintf("<strong>Control del Balón:</strong> <strong>%s</strong> pierde menos balones (%0.1f%% menos pérdidas) que <strong>%s</strong>.", nom_loc, abs(diff_tov), nom_vis)
               else sprintf("<strong>Control del Balón:</strong> <strong>%s</strong> presenta una menor tasa de pérdidas (%0.1f%% menos pérdidas) que <strong>%s</strong>.", nom_vis, diff_tov, nom_loc)
      )
    }
    
    if (abs(diff_oreb) >= 5.0) {
      outliers$oreb <- list(
        score = abs(diff_oreb) / 5.0,
        text = if (diff_oreb > 0) sprintf("<strong>Rebote de Ataque:</strong> <strong>%s</strong> captura más rebotes ofensivos (+%0.1f%% en OREB%%) que <strong>%s</strong>.", nom_loc, diff_oreb, nom_vis)
               else sprintf("<strong>Rebote de Ataque:</strong> <strong>%s</strong> controla el rebote en aro contrario (+%0.1f%% en OREB%%) frente a <strong>%s</strong>.", nom_vis, abs(diff_oreb), nom_loc)
      )
    }
    
    if (length(outliers) == 0) {
      paragraphs <- list(
        sprintf("<strong>Paridad Estructural:</strong> Emparejamiento equilibrado entre <strong>%s</strong> y <strong>%s</strong>. No se aprecian diferencias sustanciales en los Four Factors ni en el Net Rating. El ritmo medio se sitúa en <strong>%0.1f posesiones</strong>.", nom_loc, nom_vis, avg_pace)
      )
    } else {
      sorted_keys <- names(outliers)[order(sapply(outliers, function(x) x$score), decreasing = TRUE)]
      paragraphs <- lapply(sorted_keys, function(k) outliers[[k]]$text)
      
      if (avg_pace >= 76.0) {
        paragraphs[[length(paragraphs) + 1]] <- sprintf("<strong>Ritmo de Juego:</strong> El partido se proyecta a un ritmo alto de <strong>%0.1f posesiones</strong>.", avg_pace)
      } else if (avg_pace <= 70.0) {
        paragraphs[[length(paragraphs) + 1]] <- sprintf("<strong>Ritmo de Juego:</strong> Encuentro proyectado a bajo ritmo (<strong>%0.1f posesiones</strong>).", avg_pace)
      }
    }
    
    tagList(
      div(style = "line-height: 1.7; font-size: 1.05rem; color: #cbd5e1;",
          lapply(paragraphs, function(p_text) p(HTML(p_text)))
      )
    )
  })
  
  output$plot_four_factors <- renderPlotly({
    d <- matchup_data()
    nom_loc <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$team_local)]
    nom_vis <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$team_visitor)]
    
    df_ff <- tibble(
      Factor = rep(c("eFG%", "TOV%", "OREB%", "FT Rate"), 2),
      Equipo = c(rep(nom_loc, 4), rep(nom_vis, 4)),
      Valor = c(d$loc$efg_pct[1], d$loc$tov_pct[1], d$loc$oreb_pct[1], d$loc$ft_rate[1],
                d$vis$efg_pct[1], d$vis$tov_pct[1], d$vis$oreb_pct[1], d$vis$ft_rate[1])
    )
    
    p <- ggplot(df_ff, aes(x = Factor, y = Valor, fill = Equipo)) +
      geom_bar(stat = "identity", position = "dodge", width = 0.6) +
      scale_fill_manual(values = c("#10b981", "#3b82f6")) +
      theme_minimal() +
      labs(y = "Porcentaje (%)", x = NULL) +
      theme(panel.grid.minor = element_blank(),
            panel.grid.major = element_line(color = "#334155"),
            text = element_text(color = "#cbd5e1", size = 13),
            axis.text = element_text(color = "#94a3b8", size = 12))
    
    ggplotly(p) %>% theme_plotly_dark()
  })
  
  output$plot_ratings <- renderPlotly({
    req(input$team_local, input$team_visitor)
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    df_all_teams <- dbGetQuery(con, "
      SELECT 
        e.id_equipo,
        e.nombre_oficial AS equipo,
        AVG(tas.ortg) AS ortg,
        AVG(tas.drtg) AS drtg,
        AVG(tas.net_rating) AS net_rating
      FROM team_advanced_stats tas
      JOIN equipos e ON tas.id_equipo = e.id_equipo
      GROUP BY e.id_equipo, e.nombre_oficial;
    ") %>% mutate(across(c(id_equipo, ortg, drtg, net_rating), as.numeric))
    
    id_loc <- as.numeric(input$team_local)
    id_vis <- as.numeric(input$team_visitor)
    
    mean_ortg <- mean(df_all_teams$ortg, na.rm = TRUE)
    mean_drtg <- mean(df_all_teams$drtg, na.rm = TRUE)
    
    df_all_teams <- df_all_teams %>%
      mutate(
        tipo = case_when(
          id_equipo == id_loc ~ "Local",
          id_equipo == id_vis ~ "Visitante",
          TRUE ~ "Liga (Benchmark)"
        ),
        color = case_when(
          id_equipo == id_loc ~ "#10b981", # Verde Neón
          id_equipo == id_vis ~ "#06b6d4", # Azul Cian
          TRUE ~ "#94a3b8" # Gris Pizarra
        ),
        size = if_else(id_equipo %in% c(id_loc, id_vis), 14, 8),
        tooltip = sprintf("<b>%s</b><br>ORtg: %0.1f pts/100 poss (Ataque)<br>DRtg: %0.1f pts/100 poss (Menor es mejor)<br>Net Rating: %+0.1f",
                          equipo, ortg, drtg, net_rating)
      )
    
    fig <- plot_ly()
    
    df_bench <- df_all_teams %>% filter(tipo == "Liga (Benchmark)")
    fig <- fig %>% add_trace(
      data = df_bench,
      x = ~drtg, y = ~ortg,
      type = 'scatter', mode = 'markers',
      marker = list(size = ~size, color = ~color, opacity = 0.4, line = list(color = "#334155", width = 1)),
      text = ~tooltip, hoverinfo = 'text',
      name = "Liga (Benchmark)"
    )
    
    df_highlight <- df_all_teams %>% filter(tipo %in% c("Local", "Visitante"))
    fig <- fig %>% add_trace(
      data = df_highlight,
      x = ~drtg, y = ~ortg,
      type = 'scatter', mode = 'markers+text',
      textposition = 'top center',
      textfont = list(color = '#f8fafc', size = 13),
      marker = list(size = ~size, color = ~color, opacity = 1.0, line = list(color = "#ffffff", width = 2)),
      text = ~tooltip, hoverinfo = 'text',
      name = "Equipos Enfrentados"
    )
    
    fig <- fig %>% layout(
      shapes = list(
        list(type = 'line', x0 = mean_drtg, x1 = mean_drtg, y0 = min(df_all_teams$ortg) - 2, y1 = max(df_all_teams$ortg) + 2,
             line = list(color = '#334155', dash = 'dash', width = 1)),
        list(type = 'line', x0 = min(df_all_teams$drtg) - 2, x1 = max(df_all_teams$drtg) + 2, y0 = mean_ortg, y1 = mean_ortg,
             line = list(color = '#334155', dash = 'dash', width = 1))
      ),
      annotations = list(
        list(x = mean_drtg - 4, y = max(df_all_teams$ortg) + 1, text = "<b>ALTA EFICIENCIA</b>", showarrow = FALSE, font = list(color = "#10b981", size = 12)),
        list(x = mean_drtg + 4, y = max(df_all_teams$ortg) + 1, text = "<b>PERFIL OFENSIVO</b>", showarrow = FALSE, font = list(color = "#3b82f6", size = 12)),
        list(x = mean_drtg - 4, y = min(df_all_teams$ortg) - 1, text = "<b>PERFIL DEFENSIVO</b>", showarrow = FALSE, font = list(color = "#f59e0b", size = 12)),
        list(x = mean_drtg + 4, y = min(df_all_teams$ortg) - 1, text = "<b>EN CONSTRUCCIÓN</b>", showarrow = FALSE, font = list(color = "#ef4444", size = 12))
      ),
      xaxis = list(
        title = "Defensive Rating (DRtg) — Eje Invertido: Menor es Mejor Defensa",
        autorange = "reversed"
      ),
      yaxis = list(
        title = "Offensive Rating (ORtg) — Mayor es Mejor Ataque"
      ),
      showlegend = FALSE
    ) %>% theme_plotly_dark()
    
    fig
  })
  
  # ----------------------------------------------------------------------------
  # REACTIVOS - PLAYER SCOUTING & INTEGRAL DOSSIER (ACCURATE SHOOTING TOTALS)
  # ----------------------------------------------------------------------------
  players_scout_list <- reactive({
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    sql <- "SELECT j.id_jugador, j.nombre_completo FROM jugadores j"
    if (as.numeric(input$scout_team) > 0) {
      sql <- sprintf("%s WHERE j.id_equipo_actual = %s", sql, input$scout_team)
    }
    sql <- paste(sql, "ORDER BY j.nombre_completo;")
    df <- dbGetQuery(con, sql) %>% mutate(id_jugador = as.numeric(id_jugador))
    return(df)
  })
  
  output$ui_scout_player <- renderUI({
    df_p <- players_scout_list()
    if (nrow(df_p) == 0) return(helpText("No hay jugadores disponibles."))
    selectInput("scout_player_id", "Seleccionar Jugador:",
                choices = setNames(df_p$id_jugador, df_p$nombre_completo),
                selected = df_p$id_jugador[1])
  })
  
  player_data <- reactive({
    req(input$scout_player_id)
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    pid <- input$scout_player_id
    
    df_bio <- dbGetQuery(con, sprintf("
      SELECT 
        j.id_jugador, j.nombre_completo, COALESCE(NULLIF(j.puesto_posicion, 'Sin Posición'), 'Posición Desconocida') AS puesto_posicion,
        j.altura_cm, e.nombre_oficial AS equipo,
        pa.cluster_id, pa.nombre_arquetipo, pa.descripcion_perfil
      FROM jugadores j
      LEFT JOIN equipos e ON j.id_equipo_actual = e.id_equipo
      LEFT JOIN player_archetypes pa ON j.id_jugador = pa.id_jugador
      WHERE j.id_jugador = %s;
    ", pid))
    
    df_games <- dbGetQuery(con, sprintf("
      SELECT valoracion, puntos, ts_pct, usg_pct, puntos_per40, rebotes_per40, asistencias_per40, valoracion_per40
      FROM player_advanced_stats
      WHERE id_jugador = %s AND minutos_decimal > 0;
    ", pid)) %>% mutate(across(everything(), as.numeric))
    
    # Base league stats join archetype with shooting totals
    df_all_league <- dbGetQuery(con, "
      SELECT 
        j.id_jugador,
        COALESCE(pa.cluster_id, 0) AS cluster_id,
        COALESCE(pa.nombre_arquetipo, 'En evaluación') AS arquetipo_grupo,
        COUNT(bs.id_partido) AS partidos,
        AVG(bs.minutos_decimal) AS min_pg,
        AVG(bs.puntos) AS ppg,
        AVG(bs.rebotes_totales) AS rpg,
        AVG(bs.rebotes_ofensivos) AS oreb_pg,
        AVG(bs.rebotes_defensivos) AS dreb_pg,
        AVG(bs.asistencias) AS apg,
        AVG(bs.recuperaciones) AS spg,
        AVG(bs.tapones) AS bpg,
        AVG(bs.perdidas) AS topg,
        AVG(bs.faltas_cometidas) AS fpg,
        AVG(bs.valoracion) AS val_pg,
        
        SUM(bs.t2_anotados) AS t2a, SUM(bs.t2_intentados) AS t2i,
        SUM(bs.t3_anotados) AS t3a, SUM(bs.t3_intentados) AS t3i,
        SUM(bs.tl_anotados) AS tla, SUM(bs.tl_intentados) AS tli,
        
        SUM(bs.t2_anotados) * 1.0 / NULLIF(SUM(bs.t2_intentados), 0) * 100 AS t2_pct,
        SUM(bs.t3_anotados) * 1.0 / NULLIF(SUM(bs.t3_intentados), 0) * 100 AS t3_pct,
        SUM(bs.tl_anotados) * 1.0 / NULLIF(SUM(bs.tl_intentados), 0) * 100 AS tl_pct,
        
        AVG(pas.puntos_per40) AS ppg40,
        AVG(pas.rebotes_per40) AS rpg40,
        AVG(pas.asistencias_per40) AS apg40,
        AVG(pas.valoracion_per40) AS val40,
        
        AVG(pas.ts_pct) AS ts_pct,
        AVG(pas.efg_pct) AS efg_pct,
        AVG(pas.usg_pct) AS usg_pct
      FROM jugadores j
      JOIN box_scores_raw bs ON j.id_jugador = bs.id_jugador
      JOIN player_advanced_stats pas ON bs.id_jugador = pas.id_jugador AND bs.id_partido = pas.id_partido
      LEFT JOIN player_archetypes pa ON j.id_jugador = pa.id_jugador
      WHERE bs.minutos_decimal > 0
      GROUP BY j.id_jugador, pa.cluster_id, pa.nombre_arquetipo;
    ") %>% mutate(across(c(id_jugador, cluster_id, partidos, min_pg, ppg, rpg, oreb_pg, dreb_pg, apg, spg, bpg, topg, fpg, val_pg, t2a, t2i, t3a, t3i, tla, tli, t2_pct, t3_pct, tl_pct, ppg40, rpg40, apg40, val40, ts_pct, efg_pct, usg_pct), as.numeric))
    
    # Calculate percentiles GROUPED BY ARCHETYPE (cluster_id)
    df_perc <- df_all_league %>%
      group_by(cluster_id) %>%
      mutate(
        pctil_ppg     = percent_rank(ppg) * 100,
        pctil_rpg     = percent_rank(rpg) * 100,
        pctil_oreb    = percent_rank(oreb_pg) * 100,
        pctil_dreb    = percent_rank(dreb_pg) * 100,
        pctil_apg     = percent_rank(apg) * 100,
        pctil_spg     = percent_rank(spg) * 100,
        pctil_bpg     = percent_rank(bpg) * 100,
        pctil_topg    = (1 - percent_rank(topg)) * 100,
        pctil_fpg     = (1 - percent_rank(fpg)) * 100,
        pctil_val     = percent_rank(val_pg) * 100,
        pctil_val40   = percent_rank(val40) * 100,
        pctil_ppg40   = percent_rank(ppg40) * 100,
        pctil_rpg40   = percent_rank(rpg40) * 100,
        pctil_apg40   = percent_rank(apg40) * 100,
        pctil_t2      = percent_rank(coalesce(t2_pct, 0)) * 100,
        pctil_t3      = percent_rank(coalesce(t3_pct, 0)) * 100,
        pctil_tl      = percent_rank(coalesce(tl_pct, 0)) * 100,
        pctil_ts      = percent_rank(coalesce(ts_pct, 0)) * 100,
        pctil_efg     = percent_rank(coalesce(efg_pct, 0)) * 100,
        pctil_usg     = percent_rank(coalesce(usg_pct, 0)) * 100
      ) %>%
      ungroup()
    
    p_stat <- df_perc %>% filter(id_jugador == as.numeric(pid))
    
    cid <- df_bio$cluster_id[1]
    df_arq_all <- df_all_league %>% filter(cluster_id == cid)
    
    med_ts <- if (nrow(df_arq_all) > 0) median(df_arq_all$ts_pct, na.rm = TRUE) else 50.0
    med_usg <- if (nrow(df_arq_all) > 0) median(df_arq_all$usg_pct, na.rm = TRUE) else 20.0
    med_val40 <- if (nrow(df_arq_all) > 0) median(df_arq_all$val40, na.rm = TRUE) else 15.0
    
    df_arq_bench <- tibble(med_ts = med_ts, med_usg = med_usg, med_val40 = med_val40)
    
    val_vec <- df_games$valoracion
    val_mean <- mean(val_vec, na.rm = TRUE)
    val_sd <- sd(val_vec, na.rm = TRUE)
    val_mad <- mad(val_vec, na.rm = TRUE)
    val_cv <- if (!is.na(val_mean) && val_mean > 0) val_sd / val_mean else 0.5
    
    stability_label <- if (val_cv < 0.35) {
      "Muy Consistente"
    } else if (val_cv <= 0.60) {
      "Rendimiento Estable"
    } else {
      "Rendimiento Variable"
    }
    
    list(
      bio = df_bio,
      stats = p_stat,
      games = df_games,
      bench = df_arq_bench,
      mad = val_mad,
      cv = val_cv,
      stability = stability_label
    )
  })
  
  output$card_player_bio <- renderUI({
    d <- player_data()
    if (nrow(d$bio) == 0) return(div("Sin información."))
    
    b <- d$bio
    s <- d$stats
    
    arq_badge <- if (!is.na(b$nombre_arquetipo)) b$nombre_arquetipo else "En evaluación"
    arq_desc <- if (!is.na(b$descripcion_perfil)) b$descripcion_perfil else "Sin arquetipo asignado."
    alt_txt <- if (!is.na(b$altura_cm) && as.numeric(b$altura_cm) > 0) sprintf("%d cm", as.integer(b$altura_cm)) else "Altura Desconocida"
    
    stab_bg <- if (d$cv < 0.35) "bg-success" else if (d$cv <= 0.60) "bg-info" else "bg-warning"
    
    tagList(
      h3(b$nombre_completo, style = "color: #10b981; font-size: 1.6rem; font-weight: 700; margin-bottom: 4px;"),
      h5(sprintf("%s | %s | %s", b$equipo, b$puesto_posicion, alt_txt), style = "color: #94a3b8; font-size: 1.15rem; margin-bottom: 16px;"),
      div(class = "d-flex gap-2 mb-3",
          span(arq_badge, class = "badge bg-success shadow-sm rounded-pill px-3 py-2 fw-bold"),
          span(sprintf("%s (CV = %0.2f)", d$stability, d$cv), class = sprintf("badge %s shadow-sm rounded-pill px-3 py-2 fw-bold", stab_bg))
      ),
      p(strong("Perfil Táctico del Arquetipo: "), em(arq_desc), style = "font-size: 1.05rem; color: #cbd5e1; margin-top: 6px;"),
      hr(style = "border-color: #334155;"),
      layout_columns(
        fill = FALSE,
        div(style = "font-size: 1.05rem;", strong("Partidos: "), sprintf("%d", as.integer(s$partidos[1]))),
        div(style = "font-size: 1.05rem;", strong("Min/G: "), sprintf("%0.1f", s$min_pg[1])),
        div(style = "font-size: 1.05rem;", strong("PPG: "), sprintf("%0.1f", s$ppg[1])),
        div(style = "font-size: 1.05rem;", strong("VAL/G: "), sprintf("%0.1f", s$val_pg[1])),
        div(style = "font-size: 1.05rem;", strong("MAD Val: "), sprintf("%0.1f", d$mad)),
        div(style = "font-size: 1.05rem;", strong("CV Val: "), sprintf("%0.2f", d$cv))
      )
    )
  })
  
  output$plot_player_radar <- renderPlotly({
    d <- player_data()
    s <- d$stats
    if (nrow(s) == 0 || is.na(s$pctil_val[1])) return(NULL)
    
    categories <- c("Valoración", "True Shooting", "Anotación", "Rebote", "Asistencias")
    values <- c(s$pctil_val[1], s$pctil_ts[1], s$pctil_ppg[1], s$pctil_rpg[1], s$pctil_apg[1])
    
    categories <- c(categories, categories[1])
    values <- c(values, values[1])
    
    fig <- plot_ly(
      type = 'scatterpolar',
      mode = 'lines+markers',
      r = values,
      theta = categories,
      fill = 'toself',
      fillcolor = 'rgba(16, 185, 129, 0.35)',
      line = list(color = '#10b981', width = 2),
      marker = list(color = '#10b981', size = 7)
    )
    
    fig <- fig %>% layout(
      polar = list(
        radialaxis = list(visible = TRUE, range = c(0, 100), color = "#94a3b8", gridcolor = "#334155", font = list(size = 12)),
        angularaxis = list(color = "#f8fafc", gridcolor = "#334155", font = list(size = 13, weight = "bold"))
      ),
      showlegend = FALSE
    ) %>% theme_plotly_dark()
    
    fig
  })
  
  output$ui_player_stats_table <- renderUI({
    d <- player_data()
    b <- d$bio
    s <- d$stats
    if (nrow(s) == 0) return(div(class = "alert alert-warning", "Sin datos para este jugador."))
    
    arq_nombre <- if (!is.na(b$nombre_arquetipo)) b$nombre_arquetipo else "su Arquetipo"
    
    fmt_val <- function(val, suffix = "") {
      if (is.na(val)) return("—")
      sprintf("%0.1f%s", val, suffix)
    }
    
    fmt_ratio <- function(anot, tot, pct) {
      if (is.na(tot) || tot == 0) return("0/0 (0.0%)")
      sprintf("%d/%d (%0.1f%%)", as.integer(anot), as.integer(tot), pct)
    }
    
    fmt_pctil <- function(pctil) {
      if (is.na(pctil)) return(span("—", class = "badge bg-secondary"))
      v <- round(pctil, 1)
      bg_cls <- if (v >= 75) "bg-success" else if (v >= 50) "bg-info" else if (v >= 25) "bg-warning" else "bg-danger"
      
      tagList(
        div(class = "d-flex align-items-center gap-3",
            span(sprintf("%0.1f%%", v), class = sprintf("badge %s shadow-sm rounded-pill px-3 py-1 fw-bold", bg_cls), style = "min-width: 75px; text-align: center; font-size: 14px;"),
            div(class = "progress flex-grow-1 shadow-sm", style = "height: 10px; background-color: #0f172a; border-radius: 6px;",
                div(class = sprintf("progress-bar progress-bar-striped progress-bar-animated %s", bg_cls), role = "progressbar", style = sprintf("width: %0.1f%%;", v))
            )
        )
      )
    }
    
    rows <- list(
      list(icon = icon("award"), cat = "Valoración Total (VAL)", per_g = fmt_val(s$val_pg[1], " val/G"), per_40 = fmt_val(s$val40[1], " val/40"), pctil = fmt_pctil(s$pctil_val[1])),
      list(icon = icon("basketball"), cat = "Puntos (PPG / Anotación)", per_g = fmt_val(s$ppg[1], " pts/G"), per_40 = fmt_val(s$ppg40[1], " pts/40"), pctil = fmt_pctil(s$pctil_ppg[1])),
      list(icon = icon("bullseye"), cat = "True Shooting % (TS%)", per_g = fmt_val(s$ts_pct[1], "%"), per_40 = fmt_val(s$ts_pct[1], "%"), pctil = fmt_pctil(s$pctil_ts[1])),
      list(icon = icon("crosshair"), cat = "Effective Field Goal % (eFG%)", per_g = fmt_val(s$efg_pct[1], "%"), per_40 = fmt_val(s$efg_pct[1], "%"), pctil = fmt_pctil(s$pctil_efg[1])),
      list(icon = icon("fire"), cat = "Usage Rate % (USG%)", per_g = fmt_val(s$usg_pct[1], "%"), per_40 = fmt_val(s$usg_pct[1], "%"), pctil = fmt_pctil(s$pctil_usg[1])),
      list(icon = icon("circle-dot"), cat = "Acierto Tiro de 2 % (T2%)", per_g = fmt_ratio(s$t2a[1], s$t2i[1], s$t2_pct[1]), per_40 = fmt_val(s$t2_pct[1], "%"), pctil = fmt_pctil(s$pctil_t2[1])),
      list(icon = icon("bullseye"), cat = "Acierto Tiro de 3 % (T3%)", per_g = fmt_ratio(s$t3a[1], s$t3i[1], s$t3_pct[1]), per_40 = fmt_val(s$t3_pct[1], "%"), pctil = fmt_pctil(s$pctil_t3[1])),
      list(icon = icon("pen"), cat = "Acierto Tiro Libre % (TL%)", per_g = fmt_ratio(s$tla[1], s$tli[1], s$tl_pct[1]), per_40 = fmt_val(s$tl_pct[1], "%"), pctil = fmt_pctil(s$pctil_tl[1])),
      list(icon = icon("arrows-up-down"), cat = "Rebotes Totales (RPG)", per_g = fmt_val(s$rpg[1], " reb/G"), per_40 = fmt_val(s$rpg40[1], " reb/40"), pctil = fmt_pctil(s$pctil_rpg[1])),
      list(icon = icon("arrow-up-long"), cat = "Rebotes Ofensivos (OREB)", per_g = fmt_val(s$oreb_pg[1], " oreb/G"), per_40 = fmt_val(s$oreb_pg[1], " oreb/G"), pctil = fmt_pctil(s$pctil_oreb[1])),
      list(icon = icon("shield-halved"), cat = "Rebotes Defensivos (DREB)", per_g = fmt_val(s$dreb_pg[1], " dreb/G"), per_40 = fmt_val(s$dreb_pg[1], " dreb/G"), pctil = fmt_pctil(s$pctil_dreb[1])),
      list(icon = icon("share-nodes"), cat = "Asistencias (APG / Pase)", per_g = fmt_val(s$apg[1], " ast/G"), per_40 = fmt_val(s$apg40[1], " ast/40"), pctil = fmt_pctil(s$pctil_apg[1])),
      list(icon = icon("hand-sparkles"), cat = "Robos / Recuperaciones (SPG)", per_g = fmt_val(s$spg[1], " rob/G"), per_40 = fmt_val(s$spg[1], " rob/G"), pctil = fmt_pctil(s$pctil_spg[1])),
      list(icon = icon("hand"), cat = "Tapones (BPG / Def. Aro)", per_g = fmt_val(s$bpg[1], " tap/G"), per_40 = fmt_val(s$bpg[1], " tap/G"), pctil = fmt_pctil(s$pctil_bpg[1])),
      list(icon = icon("triangle-exclamation"), cat = "Pérdidas de Balón (TOPG)", per_g = fmt_val(s$topg[1], " perd/G"), per_40 = fmt_val(s$topg[1], " perd/G"), pctil = fmt_pctil(s$pctil_topg[1])),
      list(icon = icon("ban"), cat = "Faltas Cometidas (FPG)", per_g = fmt_val(s$fpg[1], " faltas/G"), per_40 = fmt_val(s$fpg[1], " faltas/G"), pctil = fmt_pctil(s$pctil_fpg[1]))
    )
    
    tagList(
      div(class = "table-responsive rounded-3 shadow-sm border border-secondary", style = "border-color: #334155 !important;",
          tags$table(class = "table table-dark table-striped table-hover align-middle mb-0", style = "font-size: 1.05rem;",
                     tags$thead(
                       tags$tr(style = "background-color: #0b0f19;",
                         tags$th("Métrica / Categoría Estadística", style = "width: 32%; color: #10b981; font-weight: 700; padding: 14px 18px;"),
                         tags$th("Totales / Promedio Per-Game", style = "width: 22%; color: #cbd5e1; padding: 14px 18px;"),
                         tags$th("Efectividad / Per-40 min", style = "width: 18%; color: #cbd5e1; padding: 14px 18px;"),
                         tags$th(sprintf("Percentil en Arquetipo (%s)", arq_nombre), style = "width: 28%; color: #cbd5e1; padding: 14px 18px;")
                       )
                     ),
                     tags$tbody(
                       lapply(rows, function(r) {
                         tags$tr(
                           tags$td(span(r$icon, style = "margin-right: 10px; color: #3b82f6;"), strong(r$cat)),
                           tags$td(r$per_g),
                           tags$td(r$per_40),
                           tags$td(r$pctil)
                         )
                       })
                     )
          )
      )
    )
  })
  
  output$ui_player_nlg_report <- renderUI({
    d <- player_data()
    b <- d$bio
    s <- d$stats
    bc <- d$bench
    
    if (nrow(s) == 0) return(NULL)
    
    p1 <- sprintf("<strong>Uso de Posesiones:</strong> Clasificado como <strong>%s</strong>, registra un <strong>%0.1f%% de USG%%</strong> (%+0.1f%% respecto a la mediana de su arquetipo: %0.1f%%).",
                  b$nombre_arquetipo, s$usg_pct[1], s$usg_pct[1] - bc$med_usg[1], bc$med_usg[1])
    
    p2 <- sprintf("<strong>Efectividad de Tiro:</strong> Registra un <strong>%0.1f%% en True Shooting (TS%%)</strong> (%+0.1f%% sobre la mediana de su arquetipo), situándose en el <strong>percentil %0.1f</strong> del grupo en valoración por partido.",
                  s$ts_pct[1], s$ts_pct[1] - bc$med_ts[1], s$pctil_val[1])
    
    p3 <- sprintf("<strong>Estabilidad de Rendimiento:</strong> Presenta un Coeficiente de Variación (CV) de <strong>%0.2f</strong> y una MAD de <strong>%0.1f val</strong> (%s).",
                  d$cv, d$mad, d$stability)
    
    tagList(
      div(style = "line-height: 1.7; font-size: 1.05rem; color: #cbd5e1;",
          p(HTML(p1)), p(HTML(p2)), p(HTML(p3))
      )
    )
  })
  
  # ----------------------------------------------------------------------------
  # REACTIVOS - BUSCADOR DE JUGADORES
  # ----------------------------------------------------------------------------
  recruitment_data <- reactive({
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    arq_vec <- paste(input$filter_arquetipos, collapse = ",")
    if (nchar(arq_vec) == 0) arq_vec <- "0"
    
    sql <- sprintf("
      SELECT 
        j.id_jugador,
        j.nombre_completo AS jugador,
        COALESCE(NULLIF(j.puesto_posicion, 'Sin Posición'), 'Posición Desconocida') AS posicion,
        pa.nombre_arquetipo AS arquetipo,
        e.nombre_oficial AS equipo,
        ROUND(AVG(pas.puntos_per40), 1) AS ppg_40,
        ROUND(AVG(pas.valoracion_per40), 1) AS val_40,
        ROUND(AVG(pas.ts_pct), 1) AS ts_pct,
        ROUND(AVG(pas.usg_pct), 1) AS usg_pct,
        ROUND(AVG(pas.pctil_valoracion), 1) AS pctil_val
      FROM jugadores j
      JOIN player_advanced_stats pas ON j.id_jugador = pas.id_jugador
      JOIN player_archetypes pa ON j.id_jugador = pa.id_jugador
      LEFT JOIN equipos e ON j.id_equipo_actual = e.id_equipo
      WHERE pas.cumple_umbral = 1
        AND pa.cluster_id IN (%s)
      GROUP BY j.id_jugador, j.nombre_completo, j.puesto_posicion, pa.nombre_arquetipo, e.nombre_oficial
      HAVING AVG(pas.puntos_per40) >= %f
         AND AVG(pas.ts_pct) >= %f
         AND AVG(pas.valoracion_per40) >= %f
    ", arq_vec, input$filter_ppg40, input$filter_ts, input$filter_val40)
    
    if (input$filter_posicion == "Posición Desconocida") {
      sql <- paste(sql, "AND (j.puesto_posicion IS NULL OR j.puesto_posicion = 'Sin Posición' OR j.puesto_posicion = 'Posición Desconocida')")
    } else if (input$filter_posicion != "Todas") {
      sql <- paste(sql, sprintf("AND j.puesto_posicion = '%s'", input$filter_posicion))
    }
    
    sql <- paste(sql, "ORDER BY AVG(pas.valoracion_per40) DESC;")
    
    df <- dbGetQuery(con, sql)
    return(df)
  })
  
  output$table_recruitment <- DT::renderDataTable({
    df <- recruitment_data()
    
    DT::datatable(
      df %>% select(-id_jugador),
      options = list(
        pageLength = 10,
        autoWidth = TRUE,
        dom = 'ftp'
      ),
      rownames = FALSE,
      style = "bootstrap4",
      class = "table table-striped table-hover"
    )
  })
  
  # ----------------------------------------------------------------------------
  # REACTIVOS - SIMULADOR DE PARTIDOS
  # ----------------------------------------------------------------------------
  simulation_result <- eventReactive(input$btn_simulate, {
    req(input$sim_local, input$sim_visitor)
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    df_loc <- dbGetQuery(con, sprintf("
      SELECT AVG(pace) AS pace, AVG(net_rating) AS net_l, AVG(efg_pct) AS efg_l, AVG(tov_pct) AS tov_l, AVG(oreb_pct) AS oreb_l, AVG(ft_rate) AS ftr_l
      FROM team_advanced_stats WHERE id_equipo = %s;
    ", input$sim_local))
    
    df_vis <- dbGetQuery(con, sprintf("
      SELECT AVG(pace) AS pace, AVG(net_rating) AS net_v, AVG(efg_pct) AS efg_v, AVG(tov_pct) AS tov_v, AVG(oreb_pct) AS oreb_v, AVG(ft_rate) AS ftr_v
      FROM team_advanced_stats WHERE id_equipo = %s;
    ", input$sim_visitor))
    
    df_sim_feat <- tibble(
      diff_net_rating = df_loc$net_l[1] - df_vis$net_v[1],
      diff_efg = df_loc$efg_l[1] - df_vis$efg_v[1],
      diff_tov = df_loc$tov_l[1] - df_vis$tov_v[1],
      diff_oreb = df_loc$oreb_l[1] - df_vis$oreb_v[1],
      diff_ftrate = df_loc$ftr_l[1] - df_vis$ftr_v[1],
      diff_pace = df_loc$pace[1] - df_vis$pace[1]
    )
    
    prob_loc <- predict(model_glm_global, newdata = df_sim_feat, type = "response")[1]
    prob_vis <- 1 - prob_loc
    
    nom_loc <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$sim_local)]
    nom_vis <- equipos_list$nombre_oficial[equipos_list$id_equipo == as.numeric(input$sim_visitor)]
    
    list(
      prob_loc = prob_loc,
      prob_vis = prob_vis,
      nom_loc = nom_loc,
      nom_vis = nom_vis,
      diff_net = df_sim_feat$diff_net_rating[1],
      diff_efg = df_sim_feat$diff_efg[1],
      diff_tov = df_sim_feat$diff_tov[1],
      diff_oreb = df_sim_feat$diff_oreb[1]
    )
  }, ignoreNULL = FALSE)
  
  output$vb_sim_prob_loc <- renderText({
    res <- simulation_result()
    sprintf("%0.1f%%", res$prob_loc * 100)
  })
  
  output$vb_sim_prob_vis <- renderText({
    res <- simulation_result()
    sprintf("%0.1f%%", res$prob_vis * 100)
  })
  
  output$vb_sim_winner <- renderText({
    res <- simulation_result()
    if (res$prob_loc >= 0.50) {
      sprintf("Victoria %s", res$nom_loc)
    } else {
      sprintf("Victoria %s", res$nom_vis)
    }
  })
  
  output$ui_sim_progress_bar <- renderUI({
    res <- simulation_result()
    p_loc <- round(res$prob_loc * 100, 1)
    p_vis <- round(res$prob_vis * 100, 1)
    
    tagList(
      div(class = "d-flex justify-content-between mb-2", style = "font-size: 1.1rem;",
          span(strong(res$nom_loc), sprintf(" (%0.1f%%)", p_loc), style = "color: #10b981; font-weight: 700;"),
          span(strong(res$nom_vis), sprintf(" (%0.1f%%)", p_vis), style = "color: #3b82f6; font-weight: 700;")
      ),
      div(class = "progress shadow-sm", style = "height: 32px; font-size: 1.05rem; font-weight: 700; border-radius: 8px;",
          div(class = "progress-bar bg-success progress-bar-striped progress-bar-animated", 
              role = "progressbar", style = sprintf("width: %0.1f%%;", p_loc),
              sprintf("%0.1f%%", p_loc)),
          div(class = "progress-bar bg-primary progress-bar-striped progress-bar-animated", 
              role = "progressbar", style = sprintf("width: %0.1f%%;", p_vis),
              sprintf("%0.1f%%", p_vis))
      )
    )
  })
  
  output$ui_sim_tactical_panel <- renderUI({
    res <- simulation_result()
    fav <- if (res$prob_loc >= 0.50) res$nom_loc else res$nom_vis
    
    tagList(
      h4(sprintf("Factores Determinantes a Favor de: %s", fav), style = "color: #f59e0b; font-weight: 700; font-size: 1.25rem;"),
      tags$ul(style = "font-size: 1.05rem; line-height: 1.8;",
        tags$li(sprintf("Diferencial de Net Rating: %+0.1f pts / 100 poss", res$diff_net)),
        tags$li(sprintf("Ventaja en Effective Field Goal %% (eFG%%): %+0.1f%%", res$diff_efg)),
        tags$li(sprintf("Diferencial en Control de Pérdidas (TOV%%): %+0.1f%%", res$diff_tov)),
        tags$li(sprintf("Dominio del Rebote Ofensivo (OREB%%): %+0.1f%%", res$diff_oreb))
      ),
      p(em("Modelo evaluado en partidos oficiales de Segunda FEB (AUC = 0.9867)."), style = "font-size: 0.95rem; color: #94a3b8; margin-top: 12px;")
    )
  })

  # ----------------------------------------------------------------------------
  # REACTIVOS - RESUMEN DE EQUIPO (DIAGNÓSTICO PARALELO)
  # ----------------------------------------------------------------------------
  exec_team_data <- reactive({
    req(input$exec_team)
    con <- get_db_con()
    on.exit(dbDisconnect(con))
    
    tid <- as.numeric(input$exec_team)
    
    # 1. Base team stats for all teams to compute Z-scores
    df_all_tas <- dbGetQuery(con, "
      SELECT 
        e.id_equipo,
        e.nombre_oficial AS equipo,
        AVG(tas.efg_pct) AS efg,
        AVG(tas.tov_pct) AS tov,
        AVG(tas.oreb_pct) AS oreb,
        AVG(tas.ft_rate) AS ftr,
        AVG(tas.net_rating) AS net_rating
      FROM team_advanced_stats tas
      JOIN equipos e ON tas.id_equipo = e.id_equipo
      GROUP BY e.id_equipo, e.nombre_oficial;
    ") %>% mutate(across(where(~ is.numeric(.) || inherits(., "integer64")), as.numeric))
    
    # 2. HHI per team
    df_pts <- dbGetQuery(con, "
      SELECT id_equipo, id_jugador, SUM(puntos) AS total_pts
      FROM box_scores_raw
      GROUP BY id_equipo, id_jugador;
    ") %>% mutate(across(everything(), as.numeric))
    
    df_hhi <- df_pts %>%
      group_by(id_equipo) %>%
      summarise(
        tot_pts = sum(total_pts),
        hhi = if (tot_pts > 0) sum((total_pts / tot_pts)^2) * 100 else 0,
        .groups = "drop"
      )
    
    # 3. Starter fatigue (Top 5 minutes ratio)
    df_min <- dbGetQuery(con, "
      SELECT id_equipo, id_jugador, SUM(minutos_decimal) AS total_min
      FROM box_scores_raw
      GROUP BY id_equipo, id_jugador;
    ") %>% mutate(across(everything(), as.numeric))
    
    df_rot <- df_min %>%
      group_by(id_equipo) %>%
      arrange(desc(total_min)) %>%
      summarise(
        tot_min = sum(total_min),
        top5_min = sum(head(total_min, 5)),
        top5_pct = if (tot_min > 0) (top5_min / tot_min) * 100 else 0,
        .groups = "drop"
      )
    
    # 4. Spacing %
    df_arch_min <- dbGetQuery(con, "
      SELECT 
        bs.id_equipo,
        COALESCE(pa.nombre_arquetipo, 'En Evaluación') AS arquetipo,
        SUM(bs.minutos_decimal) AS minutos_totales
      FROM box_scores_raw bs
      LEFT JOIN player_archetypes pa ON bs.id_jugador = pa.id_jugador
      GROUP BY bs.id_equipo, pa.nombre_arquetipo;
    ") %>% mutate(across(c(id_equipo, minutos_totales), as.numeric))
    
    df_spacing <- df_arch_min %>%
      group_by(id_equipo) %>%
      summarise(
        tot_m = sum(minutos_totales, na.rm = TRUE),
        str_m = sum(minutos_totales[arquetipo %in% c("Pívot Abierto", "Tirador Catch & Shoot", "Alero 3&D")], na.rm = TRUE),
        spacing_pct = if (tot_m > 0) (str_m / tot_m) * 100 else 0,
        .groups = "drop"
      )
    
    df_all_metrics <- df_all_tas %>%
      left_join(df_hhi %>% select(id_equipo, hhi), by = "id_equipo") %>%
      left_join(df_rot %>% select(id_equipo, top5_pct), by = "id_equipo") %>%
      left_join(df_spacing %>% select(id_equipo, spacing_pct), by = "id_equipo")
    
    target_row <- df_all_metrics %>% filter(id_equipo == tid)
    
    # Single team archetypes breakdown for Donut Chart
    df_archetypes_min <- df_arch_min %>% filter(id_equipo == tid)
    
    list(
      target = target_row,
      all_metrics = df_all_metrics,
      df_arch = df_archetypes_min
    )
  })
  
  output$vb_exec_net <- renderText({
    d <- exec_team_data()
    sprintf("%+0.1f pts/100 poss", d$target$net_rating[1])
  })
  
  output$vb_exec_hhi <- renderText({
    d <- exec_team_data()
    hhi_val <- d$target$hhi[1]
    lbl <- if (hhi_val > 15.0) "Alta Dependencia" else "Anotación Coral"
    sprintf("%0.1f%% (%s)", hhi_val, lbl)
  })
  
  output$vb_exec_rot <- renderText({
    d <- exec_team_data()
    top5 <- d$target$top5_pct[1]
    sprintf("%0.1f%% Titulares / %0.1f%% Banquillo", top5, 100 - top5)
  })
  
  output$plot_exec_fingerprint <- renderPlotly({
    d <- exec_team_data()
    df_a <- d$df_arch
    if (nrow(df_a) == 0) return(NULL)
    
    fig <- plot_ly(
      df_a,
      labels = ~arquetipo,
      values = ~minutos_totales,
      type = 'pie',
      hole = 0.4,
      textinfo = 'percent',
      hoverinfo = 'label+value+percent',
      marker = list(colors = c("#10b981", "#3b82f6", "#f59e0b", "#6366f1", "#ec4899", "#8b5cf6"))
    ) %>% layout(
      showlegend = TRUE,
      legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15, font = list(color = "#cbd5e1", size = 12)),
      margin = list(l = 10, r = 10, t = 10, b = 50)
    ) %>% theme_plotly_dark()
    
    fig
  })

  # MOTOR DINÁMICO DE DETECCIÓN DE OUTLIERS MULTIVARIABLE (TITULARES Y TEXTOS NORMALIZADOS)
  output$ui_exec_expert_panel <- renderUI({
    d <- exec_team_data()
    t <- d$target
    all_df <- d$all_metrics
    
    if (nrow(t) == 0) return(NULL)
    
    # Calculate League Means and Standard Deviations
    m <- summarise(all_df, across(c(efg, tov, oreb, ftr, hhi, top5_pct, spacing_pct), mean, na.rm = TRUE))
    s <- summarise(all_df, across(c(efg, tov, oreb, ftr, hhi, top5_pct, spacing_pct), sd, na.rm = TRUE))
    
    # Compute Z-Scores for target team
    z_efg     <- (t$efg[1] - m$efg[1]) / s$efg[1]
    z_tov     <- (t$tov[1] - m$tov[1]) / s$tov[1]
    z_oreb    <- (t$oreb[1] - m$oreb[1]) / s$oreb[1]
    z_ftr     <- (t$ftr[1] - m$ftr[1]) / s$ftr[1]
    z_hhi     <- (t$hhi[1] - m$hhi[1]) / s$hhi[1]
    z_rot     <- (t$top5_pct[1] - m$top5_pct[1]) / s$top5_pct[1]
    z_space   <- (t$spacing_pct[1] - m$spacing_pct[1]) / s$spacing_pct[1]
    
    outlier_cards <- list()
    
    # 1. Outlier eFG% (|Z| >= 1.0)
    if (abs(z_efg) >= 1.0) {
      outlier_cards$efg <- if (z_efg > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #10b981; border-radius: 12px;",
            span("📊 EFECTIVIDAD DE TIRO (eFG%)", class = "badge bg-success mb-3"),
            h5("Acierto Superior", style = "color: #10b981; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("El equipo registra un <strong>%0.1f%% en eFG%%</strong> (+%0.1f DE sobre la media: %0.1f%%).", t$efg[1], z_efg, m$efg[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #ef4444; border-radius: 12px;",
            span("📊 EFECTIVIDAD DE TIRO (eFG%)", class = "badge bg-danger mb-3"),
            h5("Acierto Reducido", style = "color: #ef4444; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Presenta un eFG%% del <strong>%0.1f%%</strong> (%0.1f DE por debajo de la media: %0.1f%%).", t$efg[1], abs(z_efg), m$efg[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 2. Outlier TOV% (|Z| >= 1.0)
    if (abs(z_tov) >= 1.0) {
      outlier_cards$tov <- if (z_tov > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #ef4444; border-radius: 12px;",
            span("📊 TASA DE PÉRDIDAS (TOV%)", class = "badge bg-danger mb-3"),
            h5("Alto Volumen de Pérdidas", style = "color: #ef4444; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("El equipo pierde el <strong>%0.1f%%</strong> de sus posesiones (+%0.1f DE sobre la media: %0.1f%%).", t$tov[1], z_tov, m$tov[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #10b981; border-radius: 12px;",
            span("📊 CONTROL DE PÉRDIDAS", class = "badge bg-success mb-3"),
            h5("Buen Control del Balón", style = "color: #10b981; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Contiene las pérdidas en un <strong>%0.1f%%</strong> (%0.1f DE por debajo de la media: %0.1f%%).", t$tov[1], abs(z_tov), m$tov[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 3. Outlier OREB% (|Z| >= 1.0)
    if (abs(z_oreb) >= 1.0) {
      outlier_cards$oreb <- if (z_oreb > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #06b6d4; border-radius: 12px;",
            span("📊 REBOTE OFENSIVO (OREB%)", class = "badge bg-info mb-3"),
            h5("Alto Rebote de Ataque", style = "color: #06b6d4; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Atrapa un <strong>%0.1f%%</strong> de los rebotes de ataque (+%0.1f DE sobre la media: %0.1f%%).", t$oreb[1], z_oreb, m$oreb[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #f59e0b; border-radius: 12px;",
            span("📊 REBOTE OFENSIVO (OREB%)", class = "badge bg-warning mb-3"),
            h5("Bajo Rebote de Ataque", style = "color: #f59e0b; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("La captura en ataque se sitúa en un <strong>%0.1f%%</strong> (%0.1f DE por debajo de la media: %0.1f%%).", t$oreb[1], abs(z_oreb), m$oreb[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 4. Outlier FT Rate (|Z| >= 1.0)
    if (abs(z_ftr) >= 1.0) {
      outlier_cards$ftr <- if (z_ftr > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #3b82f6; border-radius: 12px;",
            span("📊 TIROS LIBRES (FT Rate)", class = "badge bg-primary mb-3"),
            h5("Alto Volumen de Tiros Libres", style = "color: #3b82f6; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Registra un FT Rate del <strong>%0.1f%%</strong> (+%0.1f DE sobre la media: %0.1f%%).", t$ftr[1], z_ftr, m$ftr[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #94a3b8; border-radius: 12px;",
            span("📊 TIROS LIBRES (FT Rate)", class = "badge bg-secondary mb-3"),
            h5("Bajo Volumen de Tiros Libres", style = "color: #94a3b8; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Muestra una tasa FT Rate del <strong>%0.1f%%</strong> (%0.1f DE por debajo de la media: %0.1f%%).", t$ftr[1], abs(z_ftr), m$ftr[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 5. Outlier HHI Concentration (|Z| >= 1.0)
    if (abs(z_hhi) >= 1.0) {
      outlier_cards$hhi <- if (z_hhi > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #f59e0b; border-radius: 12px;",
            span("📊 CONCENTRACIÓN DE PUNTOS (HHI)", class = "badge bg-warning mb-3"),
            h5("Anotación Concentrada", style = "color: #f59e0b; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Índice HHI del <strong>%0.1f%%</strong> (+%0.1f DE sobre la media: %0.1f%%).", t$hhi[1], z_hhi, m$hhi[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #10b981; border-radius: 12px;",
            span("📊 CONCENTRACIÓN DE PUNTOS (HHI)", class = "badge bg-success mb-3"),
            h5("Anotación Repartida", style = "color: #10b981; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Índice HHI del <strong>%0.1f%%</strong> (%0.1f DE por debajo de la media: %0.1f%%).", t$hhi[1], abs(z_hhi), m$hhi[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 6. Outlier Starter Fatigue (|Z| >= 1.0)
    if (abs(z_rot) >= 1.0) {
      outlier_cards$rot <- if (z_rot > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #f59e0b; border-radius: 12px;",
            span("📊 USO DE TITULARES", class = "badge bg-warning mb-3"),
            h5("Carga Alta de Titulares", style = "color: #f59e0b; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Los 5 principales titulares juegan el <strong>%0.1f%%</strong> de los minutos (+%0.1f DE sobre la media: %0.1f%%).", t$top5_pct[1], z_rot, m$top5_pct[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #06b6d4; border-radius: 12px;",
            span("📊 ROTACIÓN DE BANQUILLO", class = "badge bg-info mb-3"),
            h5("Rotación Amplia de Banquillo", style = "color: #06b6d4; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Los 5 titulares disputan solo el <strong>%0.1f%%</strong> de los minutos (%0.1f DE por debajo de la media: %0.1f%%).", t$top5_pct[1], abs(z_rot), m$top5_pct[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # 7. Outlier Spacing% (|Z| >= 1.0)
    if (abs(z_space) >= 1.0) {
      outlier_cards$space <- if (z_space > 0) {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #10b981; border-radius: 12px;",
            span("📊 TIRO EXTERIOR (SPACING%)", class = "badge bg-success mb-3"),
            h5("Mayor Espacio Exterior", style = "color: #10b981; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Un <strong>%0.1f%%</strong> de los minutos corresponde a jugadores exteriores/tiradores (+%0.1f DE sobre la media: %0.1f%%).", t$spacing_pct[1], z_space, m$spacing_pct[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      } else {
        div(class = "card p-4 h-100 bg-dark text-light", style = "border: 1px solid #94a3b8; border-radius: 12px;",
            span("📊 JUEGO INTERIOR", class = "badge bg-secondary mb-3"),
            h5("Menor Volumen Exterior", style = "color: #94a3b8; font-weight: 700; font-size: 1.25rem; margin-bottom: 12px;"),
            p(HTML(sprintf("Un <strong>%0.1f%%</strong> de los minutos pertenece a tiradores (%0.1f DE por debajo de la media: %0.1f%%).", t$spacing_pct[1], abs(z_space), m$spacing_pct[1])), style = "font-size: 1.05rem; line-height: 1.7; color: #cbd5e1;")
        )
      }
    }
    
    # Render Outliers or Edge-Case Balanced Card
    if (length(outlier_cards) == 0) {
      div(class = "card p-4 text-center bg-dark text-light", style = "border: 1px solid #334155; border-radius: 12px;",
          span("⚖️ PERFIL EQUILIBRADO", class = "badge bg-secondary mb-3"),
          h5("Perfil Colectivo Equilibrado", style = "color: #f8fafc; font-weight: 700; font-size: 1.25rem; margin-bottom: 10px;"),
          p("Perfil colectivamente equilibrado sin desviaciones estadísticas significativas respecto a la media de la liga.", style = "font-size: 1.1rem; line-height: 1.7; color: #cbd5e1;")
      )
    } else {
      n_cards <- length(outlier_cards)
      w <- if (n_cards == 1) 12 else if (n_cards == 2) 6 else if (n_cards == 3) 4 else 3
      
      cols <- lapply(outlier_cards, function(card_elem) {
        div(class = sprintf("col-md-%d col-12 d-flex align-items-stretch", w), card_elem)
      })
      
      div(class = "row g-3 d-flex flex-wrap align-items-stretch",
          cols
      )
    }
  })
}

# RUN SHINY APP
shinyApp(ui = ui, server = server)

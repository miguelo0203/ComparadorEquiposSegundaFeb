library(rvest)
library(httr)
library(stringr)
library(dplyr)
library(purrr)

discover_feb_groups <- function(temporada = "2024") {
  url_base <- sprintf("https://baloncestoenvivo.feb.es/resultados.aspx?g=2&t=%s&nm=segundafeb", temporada)
  resp <- GET(url_base, add_headers("User-Agent" = "Mozilla/5.0"))
  html <- read_html(resp)
  
  grupos_select <- html %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_gruposDropDownList")
  if (is.na(grupos_select)) {
    cat("No se encontró gruposDropDownList en URL base.\n")
    return(NULL)
  }
  
  options_g <- grupos_select %>% html_nodes("option")
  grupos <- map_dfr(options_g, function(opt) {
    tibble(
      id_grupo = html_attr(opt, "value"),
      nombre_grupo = html_text(opt, trim = TRUE)
    )
  })
  
  cat(sprintf("Temporada %s - Grupos encontrados (%d):\n", temporada, nrow(grupos)))
  print(grupos)
  
  # Para cada grupo, descubrir todas sus jornadas
  partidos_todos <- map_dfr(grupos$id_grupo, function(id_g) {
    nombre_g <- grupos$nombre_grupo[grupos$id_grupo == id_g]
    url_g <- sprintf("https://baloncestoenvivo.feb.es/resultados.aspx?g=%s&t=%s", id_g, temporada)
    resp_g <- GET(url_g, add_headers("User-Agent" = "Mozilla/5.0"))
    html_g <- read_html(resp_g)
    
    jornadas_select <- html_g %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_jornadasDropDownList")
    if (is.na(jornadas_select)) return(NULL)
    
    options_j <- jornadas_select %>% html_nodes("option")
    jornadas <- map_dfr(options_j, function(opt_j) {
      tibble(
        id_jornada = html_attr(opt_j, "value"),
        nombre_jornada = html_text(opt_j, trim = TRUE)
      )
    })
    
    # Recorrer cada jornada del grupo
    map_dfr(jornadas$id_jornada, function(id_j) {
      nombre_j <- jornadas$nombre_jornada[jornadas$id_jornada == id_j]
      num_jornada <- as.integer(str_extract(nombre_j, "(?<=Jornada\\s)\\d+"))
      if (is.na(num_jornada)) num_jornada <- as.integer(str_extract(nombre_j, "\\d+"))
      
      url_j <- sprintf("https://baloncestoenvivo.feb.es/resultados.aspx?g=%s&t=%s&j=%s", id_g, temporada, id_j)
      resp_j <- GET(url_j, add_headers("User-Agent" = "Mozilla/5.0"))
      html_j <- read_html(resp_j)
      
      links_p <- html_j %>% html_nodes("a[href*='Partido.aspx?p=']")
      if (length(links_p) == 0) return(NULL)
      
      map_dfr(links_p, function(lp) {
        href_p <- html_attr(lp, "href")
        texto_p <- html_text(lp, trim = TRUE)
        id_p <- as.integer(str_extract(href_p, "(?<=p=)\\d+"))
        
        # Filtrar solo partidos disputados (que tengan resultado numérico ej "80-70", desestimando "*-*")
        es_disputado <- str_detect(texto_p, "\\d+-\\d+")
        
        tibble(
          id_partido = id_p,
          url_partido = href_p,
          resultado = texto_p,
          grupo = nombre_g,
          id_grupo = id_g,
          jornada = num_jornada,
          id_jornada = id_j,
          disputado = es_disputado
        )
      })
    })
  })
  
  return(partidos_todos)
}

df_2025 <- discover_feb_groups("2025")
cat(sprintf("\nTemporada 2025/2026 - Total enlaces descubiertos: %d | Disputados: %d\n", 
            nrow(df_2025), sum(df_2025$disputado, na.rm = TRUE)))

df_2024 <- discover_feb_groups("2024")
cat(sprintf("\nTemporada 2024/2025 - Total enlaces descubiertos: %d | Disputados: %d\n", 
            nrow(df_2024), sum(df_2024$disputado, na.rm = TRUE)))

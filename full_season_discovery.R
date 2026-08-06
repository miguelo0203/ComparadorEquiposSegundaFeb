library(rvest)
library(httr)
library(stringr)
library(dplyr)
library(purrr)

descubrir_temporada_completa <- function(temporada = "2024") {
  url_base <- sprintf("https://baloncestoenvivo.feb.es/resultados.aspx?g=2&t=%s&nm=segundafeb", temporada)
  
  cat(sprintf("\n=== INICIANDO DESCUBRIMIENTO DE CALENDARIO SEGUNDA FEB (TEMPORADA %s) ===\n", temporada))
  resp_init <- GET(url_base, add_headers("User-Agent" = "Mozilla/5.0"))
  html_init <- read_html(resp_init)
  
  # Extraer viewstates iniciales
  vs <- html_init %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
  vsg <- html_init %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
  ev <- html_init %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
  
  # Grupos disponibles
  select_g <- html_init %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_gruposDropDownList")
  if (is.na(select_g)) stop("No se localizó gruposDropDownList.")
  
  opts_g <- select_g %>% html_nodes("option")
  grupos <- map_dfr(opts_g, function(o) {
    tibble(id_grupo = html_attr(o, "value"), nombre_grupo = html_text(o, trim = TRUE))
  })
  
  cat(sprintf("Grupos identificados (%d):\n", nrow(grupos)))
  print(grupos)
  
  partidos_lista <- list()
  
  for (i in 1:nrow(grupos)) {
    id_g <- grupos$id_grupo[i]
    nom_g <- grupos$nombre_grupo[i]
    
    cat(sprintf("\n[GRUPO %d/%d] %s (ID: %s)\n", i, nrow(grupos), nom_g, id_g))
    
    # POST para cambiar a este grupo
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
    
    # Actualizar viewstates post-grupo
    vs <- html_g %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
    vsg <- html_g %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
    ev <- html_g %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
    
    # Extraer jornadas para este grupo
    select_j <- html_g %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_jornadasDropDownList")
    if (is.na(select_j)) next
    
    opts_j <- select_j %>% html_nodes("option")
    jornadas <- map_dfr(opts_j, function(oj) {
      tibble(id_jornada = html_attr(oj, "value"), nombre_jornada = html_text(oj, trim = TRUE))
    })
    
    cat(sprintf("  Jornadas en %s: %d\n", nom_g, nrow(jornadas)))
    
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
      
      # Extraer viewstate de respuesta
      vs <- html_j %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
      vsg <- html_j %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
      ev <- html_j %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")
      
      links_p <- html_j %>% html_nodes("a[href*='Partido.aspx?p=']")
      if (length(links_p) == 0) next
      
      df_j <- map_dfr(links_p, function(lp) {
        href_p <- html_attr(lp, "href")
        texto_p <- html_text(lp, trim = TRUE)
        id_p <- as.integer(str_extract(href_p, "(?<=p=)\\d+"))
        
        # El partido está disputado si la celda tiene marcador (ej "80-70") y no es "*-*" o "Descansa"
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
      cat(sprintf("  -> Jornada %2d (%s): %d partidos (%d jugados)\n", 
                  if(is.na(num_j)) 0 else num_j, nom_j, nrow(df_j), sum(df_j$disputado)))
      
      Sys.sleep(0.1)
    }
  }
  
  df_consolidado <- bind_rows(partidos_lista) %>% distinct(id_partido, .keep_all = TRUE)
  return(df_consolidado)
}

df_partidos_2024 <- descubrir_temporada_completa("2024")
cat("\n=================================================================\n")
cat(sprintf("RESUMEN DISCOVERY: %d partidos únicos descubiertos (%d disputados)\n",
            nrow(df_partidos_2024), sum(df_partidos_2024$disputado)))
cat("=================================================================\n")
print(head(df_partidos_2024, 10))

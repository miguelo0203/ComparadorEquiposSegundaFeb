library(rvest)
library(httr)
library(stringr)
library(dplyr)
library(purrr)

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
    }
  }
  
  df_final <- bind_rows(partidos_lista) %>% 
    filter(disputado == TRUE) %>% 
    distinct(id_partido, .keep_all = TRUE)
  
  return(df_final)
}

df_cal <- descubrir_temporada_completa("2024")
saveRDS(df_cal, "f:/Otro Proyecto/df_calendario.rds")
cat(sprintf("\n[CALENDARIO GUARDADO] Total partidos disputados: %d en df_calendario.rds\n", nrow(df_cal)))

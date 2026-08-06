library(rvest)
library(httr)
library(stringr)
library(dplyr)

# Probemos calendario.aspx para el grupo 89999 y 90000 de la temporada 2025 (2025/2026)
for (g in c("89999", "90000")) {
  url_cal <- sprintf("https://baloncestoenvivo.feb.es/calendario.aspx?g=%s&t=2025", g)
  resp <- GET(url_cal, add_headers("User-Agent" = "Mozilla/5.0"))
  html <- read_html(resp)
  
  a_partidos <- html %>% html_nodes("a[href*='Partido.aspx?p=']")
  cat(sprintf("Grupo %s | Total enlaces a partidos en Calendario: %d\n", g, length(a_partidos)))
  
  # Ver si los enlaces tienen puntuación (partidos jugados) o no jugados
  scores <- html %>% html_nodes("a[href*='Partido.aspx?p=']") %>% html_text(trim = TRUE)
  cat("  Ejemplos de textos de enlaces (puntuaciones):", paste(head(scores, 5), collapse = ", "), "\n")
}

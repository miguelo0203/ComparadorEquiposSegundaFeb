library(rvest)
library(httr)
library(stringr)
library(dplyr)
library(purrr)

# Probar discovery en Segunda FEB
url_res <- "https://baloncestoenvivo.feb.es/resultados.aspx?g=2&t=2026&nm=segundafeb"
resp <- GET(url_res, add_headers("User-Agent" = "Mozilla/5.0"))
html <- read_html(resp)

# Buscar selects (grupos, jornadas)
selects <- html %>% html_nodes("select")
cat("Selects encontrados:", length(selects), "\n")

for (s in selects) {
  id_s <- html_attr(s, "id")
  name_s <- html_attr(s, "name")
  options <- s %>% html_nodes("option")
  cat(sprintf("Select id: %s | name: %s | Opción count: %d\n", id_s, name_s, length(options)))
  for (i in 1:min(5, length(options))) {
    val <- html_attr(options[i], "value")
    txt <- html_text(options[i], trim = TRUE)
    cat(sprintf("   [%s] %s\n", val, txt))
  }
}

# Buscar enlaces a partidos directamente
a_partidos <- html %>% html_nodes("a[href*='Partido.aspx?p=']")
cat("\nEnlaces a partidos encontrados directamente en la página:", length(a_partidos), "\n")
for (i in 1:min(5, length(a_partidos))) {
  cat(sprintf("  [%d] %s -> %s\n", i, html_text(a_partidos[i], trim = TRUE), html_attr(a_partidos[i], "href")))
}

library(rvest)
library(httr)

# Probar extraer de un partido real
url_p <- "https://baloncestoenvivo.feb.es/Partido.aspx?p=2471075"
resp <- GET(url_p, add_headers("User-Agent" = "Mozilla/5.0"))
html <- read_html(resp)

links_j <- html %>% html_nodes("td.nombre.jugador a")
cat("Enlaces de jugadores en partido 2471075:\n")
for (i in 1:min(5, length(links_j))) {
  cat("  -", html_text(links_j[i], trim = TRUE), "->", html_attr(links_j[i], "href"), "\n")
}

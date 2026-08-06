library(rvest)
library(httr)
library(stringr)

test_id <- 2167735  # Ejemplo de ID
url_j <- sprintf("https://baloncestoenvivo.feb.es/Jugador.aspx?i=940428&c=%s", test_id)
resp <- GET(url_j, add_headers("User-Agent" = "Mozilla/5.0"))
html <- read_html(resp)

nodos <- html %>% html_nodes("div.box-jugador .info .nodo")
for (n in nodos) {
  lbl <- str_squish(n %>% html_node("span.label") %>% html_text(trim = TRUE))
  val <- str_squish(n %>% html_node("span.string") %>% html_text(trim = TRUE))
  cat(lbl, "->", val, "\n")
}

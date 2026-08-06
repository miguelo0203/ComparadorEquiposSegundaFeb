library(rvest)
library(httr)
library(stringr)

# Test 1: resultados.aspx?g=86348&t=2024
url1 <- "https://baloncestoenvivo.feb.es/resultados.aspx?g=86348&t=2024"
resp1 <- GET(url1, add_headers("User-Agent" = "Mozilla/5.0"))
html1 <- read_html(resp1)

links1 <- html1 %>% html_nodes("a[href*='Partido.aspx?p=']")
cat("Resultados.aspx?g=86348&t=2024 -> Enlaces encontrados:", length(links1), "\n")
for (i in 1:min(5, length(links1))) {
  cat("  -", html_text(links1[i], trim = TRUE), "->", html_attr(links1[i], "href"), "\n")
}

# Test 2: calendario.aspx?g=86348&t=2024
url2 <- "https://baloncestoenvivo.feb.es/calendario.aspx?g=86348&t=2024"
resp2 <- GET(url2, add_headers("User-Agent" = "Mozilla/5.0"))
html2 <- read_html(resp2)

links2 <- html2 %>% html_nodes("a[href*='Partido.aspx?p=']")
cat("\nCalendario.aspx?g=86348&t=2024 -> Enlaces encontrados:", length(links2), "\n")
for (i in 1:min(5, length(links2))) {
  cat("  -", html_text(links2[i], trim = TRUE), "->", html_attr(links2[i], "href"), "\n")
}

# Test 3: ver opciones del select de jornadas
jornadas_select <- html1 %>% html_node("select#_ctl0_MainContentPlaceHolderMaster_jornadasDropDownList")
if (!is.na(jornadas_select)) {
  opts <- jornadas_select %>% html_nodes("option")
  cat("\nJornadas encontradas en select:", length(opts), "\n")
  for (i in 1:min(5, length(opts))) {
    cat("  Option:", html_attr(opts[i], "value"), "->", html_text(opts[i], trim = TRUE), "\n")
  }
}

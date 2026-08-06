library(rvest)
library(httr)
library(stringr)

url <- "https://baloncestoenvivo.feb.es/resultados.aspx?g=2&t=2024&nm=segundafeb"
resp <- GET(url, add_headers("User-Agent" = "Mozilla/5.0"))
html <- read_html(resp)

vs <- html %>% html_node("input#__VIEWSTATE") %>% html_attr("value")
vsg <- html %>% html_node("input#__VIEWSTATEGENERATOR") %>% html_attr("value")
ev <- html %>% html_node("input#__EVENTVALIDATION") %>% html_attr("value")

cat("VIEWSTATE obtenido. Tamaño:", nchar(vs), "\n")

# Probar cambiar al Grupo Oeste (id: 86349) o Jornada 1
body_data <- list(
  "__VIEWSTATE" = vs,
  "__VIEWSTATEGENERATOR" = vsg,
  "__EVENTVALIDATION" = ev,
  "__EVENTTARGET" = "_ctl0$MainContentPlaceHolderMaster$gruposDropDownList",
  "__EVENTARGUMENT" = "",
  "_ctl0:MainContentPlaceHolderMaster:gruposDropDownList" = "86349"
)

resp_post <- POST(url, body = body_data, encode = "form", add_headers("User-Agent" = "Mozilla/5.0"))
html_post <- read_html(resp_post)

links_post <- html_post %>% html_nodes("a[href*='Partido.aspx?p=']")
cat("POST a Grupo 86349 (Liga Regular OESTE) -> Partidos encontrados:", length(links_post), "\n")
for (i in 1:min(5, length(links_post))) {
  cat("  -", html_text(links_post[i], trim = TRUE), "->", html_attr(links_post[i], "href"), "\n")
}

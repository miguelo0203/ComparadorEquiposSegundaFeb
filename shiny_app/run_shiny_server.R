library(shiny)
cat("Iniciando servidor R Shiny en http://127.0.0.1:8080...\n")
runApp("f:/Otro Proyecto/app.R", port = 8080, host = "127.0.0.1", launch.browser = FALSE)

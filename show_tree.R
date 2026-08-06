dirs <- c("database", "analytics", "audit", "shiny_app", "reports")
cat("=================================================================\n")
cat("          ESTRUCTURA FINAL DEL REPOSITORIO (SEGUNDA FEB PRO)      \n")
cat("=================================================================\n\n")

for (d in dirs) {
  path <- file.path("f:/Otro Proyecto", d)
  cat(sprintf("[%s/]\n", d))
  files <- list.files(path)
  for (f in files) {
    cat(sprintf("  |-- %s\n", f))
  }
  cat("\n")
}

cat("=================================================================\n")

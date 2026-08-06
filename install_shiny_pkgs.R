pkgs <- c("shiny", "bslib", "plotly", "DT")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    cat("Instalando paquete:", p, "...\n")
    install.packages(p, repos = "https://cloud.r-project.org")
  } else {
    cat("Paquete ya instalado:", p, "\n")
  }
}
cat("INSTALACION COMPLETADA OK\n")

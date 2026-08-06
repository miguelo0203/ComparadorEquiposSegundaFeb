# ==============================================================================
# DEPLOY SEGUNDA FEB PRO TO SHINYAPPS.IO CLOUD
# ==============================================================================

library(rsconnect)

cat("Configurando cuenta miguelo0203 en rsconnect...\n")

rsconnect::setAccountInfo(
  name   = 'miguelo0203',
  token  = 'C55219061C24B7CBACD9095ED2F4380D',
  secret = 'RwCLr2WMm4QnGJ7A92oUNJI5dn5z5Q72WAmeYv6u'
)

cat("Iniciando despliegue de la aplicación a shinyapps.io...\n")

rsconnect::deployApp(
  appDir          = "f:/Otro Proyecto",
  appName         = "ComparadorEquiposSegundaFeb",
  appTitle        = "SEGUNDA FEB PRO | Elite Analytics System",
  account         = "miguelo0203",
  server          = "shinyapps.io",
  forceUpdate     = TRUE,
  launch.browser  = FALSE
)

cat("\n=================================================================\n")
cat("DESPLIEGUE EN LA NUBE COMPLETADO EXISOSAMENTE\n")
cat("=================================================================\n")

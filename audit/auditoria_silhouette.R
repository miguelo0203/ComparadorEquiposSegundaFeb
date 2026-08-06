# ==============================================================================
# AUDITORÍA MATEMÁTICA DE SILHOUETTE Y VALIDACIÓN DE K PARA K-MEANS
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)
library(cluster)

cat("=================================================================\n")
cat("  AUDITORÍA DE COHESIÓN Y SEPARACIÓN MEDIANTE COEFICIENTE SILHOUETTE \n")
cat("=================================================================\n\n")

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "postgres",
  host     = "127.0.0.1",
  port     = 5433,
  user     = "postgres",
  password = ""
)
dbExecute(con, "SET search_path TO segunda_feb_pro, public;")

# ------------------------------------------------------------------------------
# 1. RECONSTRUCCIÓN DE LA MATRIZ ESCALADA DEL NÚCLEO DURO (326 JUGADORES)
# ------------------------------------------------------------------------------
cat("[1/3] Extrayendo y escalando matriz de características (326 jugadores)...\n")

df_pa <- dbGetQuery(con, "
  SELECT 
    pa.id_jugador,
    pa.cluster_id,
    pa.nombre_arquetipo,
    pa.altura_cm,
    pa.ppg_per40,
    pa.rpg_per40,
    pa.apg_per40,
    pa.ts_pct,
    pa.usg_pct,
    pa.t3_ratio,
    COALESCE(j.puesto_posicion, 'Sin Posición') AS puesto_posicion
  FROM segunda_feb_pro.player_archetypes pa
  JOIN segunda_feb_pro.jugadores j ON pa.id_jugador = j.id_jugador;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

# Imputar altura si falta
altura_mediana_pos <- df_pa %>%
  group_by(puesto_posicion) %>%
  summarise(mediana_h = median(altura_cm, na.rm = TRUE), .groups = "drop")

df_clean <- df_pa %>%
  left_join(altura_mediana_pos, by = "puesto_posicion") %>%
  mutate(altura_clean = if_else(is.na(altura_cm), if_else(is.na(mediana_h), 195, mediana_h), as.numeric(altura_cm)))

features_matrix <- df_clean %>%
  select(altura_clean, ppg_per40, rpg_per40, apg_per40, ts_pct, usg_pct, t3_ratio)

scaled_mat <- scale(features_matrix)
dist_mat <- dist(scaled_mat)

cat("  -> Matriz de distancias euclidianas calculada (326 x 326).\n")

# ------------------------------------------------------------------------------
# 2. CÁLCULO DEL COEFICIENTE DE SILHOUETTE PARA K = 6
# ------------------------------------------------------------------------------
cat("\n[2/3] Calculando Coeficiente de Silhouette para K = 6...\n")

set.seed(42)
km6 <- kmeans(scaled_mat, centers = 6, nstart = 25)

sil6 <- silhouette(km6$cluster, dist_mat)
summary_sil6 <- summary(sil6)

cat(sprintf("\n--- RESULTADOS SILHOUETTE PARA K = 6 ---\n"))
cat(sprintf("Anchura Media Global de la Silueta (Average Silhouette Width): %0.4f\n\n", summary_sil6$avg.width))

df_sil6_clusters <- tibble(
  cluster_id = 1:6,
  n_jugadores = summary_sil6$clus.sizes,
  sil_media = round(summary_sil6$clus.avg.widths, 4)
) %>%
  left_join(
    df_clean %>% select(cluster_id, nombre_arquetipo) %>% distinct(cluster_id, .keep_all = TRUE),
    by = "cluster_id"
  )

cat("Silueta Media por Clúster Individual (K = 6):\n")
print(as.data.frame(df_sil6_clusters %>% select(cluster_id, nombre_arquetipo, n_jugadores, sil_media)), row.names = FALSE)

# ------------------------------------------------------------------------------
# 3. BARRIDO DE VALIDACIÓN DE K EN EL RANGO [4, 8]
# ------------------------------------------------------------------------------
cat("\n[3/3] Ejecutando barrido de modelos K-Means para K in [4, 8]...\n")

res_barrido <- map_dfr(4:8, function(k_val) {
  set.seed(42)
  km_k <- kmeans(scaled_mat, centers = k_val, nstart = 25)
  sil_k <- silhouette(km_k$cluster, dist_mat)
  sil_sum <- summary(sil_k)
  
  totss <- km_k$totss
  betweenss <- km_k$betweenss
  var_exp <- (betweenss / totss) * 100
  
  tibble(
    K = k_val,
    avg_sil_width = round(sil_sum$avg.width, 4),
    var_explicada_pct = round(var_exp, 2),
    min_cluster_size = min(sil_sum$clus.sizes),
    max_cluster_size = max(sil_sum$clus.sizes)
  )
})

cat("\nTabla Comparativa del Barrido de K (K in 4:8):\n")
print(as.data.frame(res_barrido), row.names = FALSE)

dbDisconnect(con)

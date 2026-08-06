# ==============================================================================
# FASE 6: MACHINE LEARNING PREDICTIVO - WIN PREDICTION MODEL & PERSISTENCIA
# ==============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(stringr)
library(pROC)

set.seed(42)

cat("=================================================================\n")
cat("      FASE 6: MACHINE LEARNING PREDICTIVO (MODELO DE VICTORIA)    \n")
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
# 1. DDL: TABLA MATCH_PREDICTIONS EN POSTGRESQL (IDEMPOTENTE)
# ------------------------------------------------------------------------------
cat("[1/4] Creando tabla segunda_feb_pro.match_predictions...\n")

ddl_table <- "
CREATE TABLE IF NOT EXISTS segunda_feb_pro.match_predictions (
    id_partido INT NOT NULL,
    id_equipo_local INT NOT NULL,
    id_equipo_visitante INT NOT NULL,
    prob_victoria_local NUMERIC(5,4) NOT NULL,
    prediccion_victoria INT NOT NULL,
    victoria_real INT NOT NULL,
    acierto_prediccion BOOLEAN NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_match_predictions PRIMARY KEY (id_partido),
    CONSTRAINT fk_mp_partido FOREIGN KEY (id_partido) REFERENCES segunda_feb_pro.partidos(id_partido) ON DELETE CASCADE,
    CONSTRAINT fk_mp_local FOREIGN KEY (id_equipo_local) REFERENCES segunda_feb_pro.equipos(id_equipo) ON DELETE CASCADE,
    CONSTRAINT fk_mp_visiting FOREIGN KEY (id_equipo_visitante) REFERENCES segunda_feb_pro.equipos(id_equipo) ON DELETE CASCADE
);
"
dbExecute(con, ddl_table)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_mp_local ON segunda_feb_pro.match_predictions(id_equipo_local);")

cat("  -> Tabla match_predictions creada e indexada.\n")

# ------------------------------------------------------------------------------
# 2. FEATURE ENGINEERING & DATASET DE ENTRENAMIENTO
# ------------------------------------------------------------------------------
cat("[2/4] Construyendo dataset de características a nivel de partido (396 encuentros)...\n")

df_partidos_raw <- dbGetQuery(con, "
  SELECT 
    p.id_partido, p.id_equipo_local, p.id_equipo_visitante,
    tas_l.puntos_favor AS pts_local, tas_l.puntos_contra AS pts_vis,
    tas_l.pace AS pace_l, tas_l.ortg AS ortg_l, tas_l.drtg AS drtg_l, tas_l.net_rating AS net_l,
    tas_l.efg_pct AS efg_l, tas_l.tov_pct AS tov_l, tas_l.oreb_pct AS oreb_l, tas_l.ft_rate AS ftr_l,
    tas_v.pace AS pace_v, tas_v.ortg AS ortg_v, tas_v.drtg AS drtg_v, tas_v.net_rating AS net_v,
    tas_v.efg_pct AS efg_v, tas_v.tov_pct AS tov_v, tas_v.oreb_pct AS oreb_v, tas_v.ft_rate AS ftr_v
  FROM segunda_feb_pro.partidos p
  JOIN segunda_feb_pro.team_advanced_stats tas_l ON p.id_partido = tas_l.id_partido AND p.id_equipo_local = tas_l.id_equipo
  JOIN segunda_feb_pro.team_advanced_stats tas_v ON p.id_partido = tas_v.id_partido AND p.id_equipo_visitante = tas_v.id_equipo;
") %>%
  mutate(across(where(~ inherits(.x, "integer64") || is.integer(.x)), as.numeric))

df_features <- df_partidos_raw %>%
  mutate(
    victoria_real = if_else(pts_local > pts_vis, 1, 0),
    diff_net_rating = net_l - net_v,
    diff_efg = efg_l - efg_v,
    diff_tov = tov_l - tov_v,
    diff_oreb = oreb_l - oreb_v,
    diff_ftrate = ftr_l - ftr_v,
    diff_pace = pace_l - pace_v
  )

cat(sprintf("  -> Dataset preparado: %d partidos procesados.\n", nrow(df_features)))

# ------------------------------------------------------------------------------
# 3. ENTRENAMIENTO Y EVALUACIÓN DEL MODELO (70% TRAIN / 30% TEST)
# ------------------------------------------------------------------------------
cat("[3/4] Entrenando modelo de clasificación binaria (Regresión Logística)...\n")

train_idx <- sample(seq_len(nrow(df_features)), size = floor(0.70 * nrow(df_features)))
df_train <- df_features[train_idx, ]
df_test  <- df_features[-train_idx, ]

# Modelo Logístico con Four Factors & Net Rating Differentials
model_glm <- glm(
  victoria_real ~ diff_net_rating + diff_efg + diff_tov + diff_oreb + diff_ftrate + diff_pace,
  data = df_train,
  family = binomial
)

# Evaluación en conjunto de prueba (30%)
test_probs <- predict(model_glm, newdata = df_test, type = "response")
test_preds <- if_else(test_probs >= 0.50, 1, 0)

conf_mat <- table(Prediccion = test_preds, Real = df_test$victoria_real)
accuracy <- mean(test_preds == df_test$victoria_real) * 100
roc_obj <- roc(df_test$victoria_real, test_probs, quiet = TRUE)
auc_val <- auc(roc_obj)

cat("\n--- MÉTRICAS DE EVALUACIÓN EN CONJUNTO DE PRUEBA (TEST SET) ---\n")
cat(sprintf("Accuracy (Precisión Global): %0.2f%%\n", accuracy))
cat(sprintf("AUC (Area Under Curve ROC): %0.4f\n\n", auc_val))

cat("Matriz de Confusión:\n")
print(conf_mat)

# ------------------------------------------------------------------------------
# 4. INFERENCIA GLOBAL TEMPORADA Y PERSISTENCIA UPSERT EN POSTGRESQL
# ------------------------------------------------------------------------------
cat("\n[4/4] Generando predicciones globales y volcando a segunda_feb_pro.match_predictions...\n")

df_features$prob_victoria_local <- predict(model_glm, newdata = df_features, type = "response")
df_features <- df_features %>%
  mutate(
    prediccion_victoria = if_else(prob_victoria_local >= 0.50, 1, 0),
    acierto_prediccion = (prediccion_victoria == victoria_real)
  )

sql_upsert <- "
INSERT INTO segunda_feb_pro.match_predictions (
  id_partido, id_equipo_local, id_equipo_visitante,
  prob_victoria_local, prediccion_victoria, victoria_real, acierto_prediccion
) VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (id_partido) DO UPDATE SET
  id_equipo_local = EXCLUDED.id_equipo_local,
  id_equipo_visitante = EXCLUDED.id_equipo_visitante,
  prob_victoria_local = EXCLUDED.prob_victoria_local,
  prediccion_victoria = EXCLUDED.prediccion_victoria,
  victoria_real = EXCLUDED.victoria_real,
  acierto_prediccion = EXCLUDED.acierto_prediccion,
  creado_en = CURRENT_TIMESTAMP;
"

dbWithTransaction(con, {
  for (i in 1:nrow(df_features)) {
    r <- df_features[i, ]
    dbExecute(con, sql_upsert, params = list(
      r$id_partido, r$id_equipo_local, r$id_equipo_visitante,
      round(r$prob_victoria_local, 4), r$prediccion_victoria, r$victoria_real, r$acierto_prediccion
    ))
  }
})

cat("  -> Persistencia completada con éxito.\n")

# ------------------------------------------------------------------------------
# 5. VALIDACIÓN Y SANITY CHECK SQL
# ------------------------------------------------------------------------------
cat("\nConsulta SQL de Validación (Muestra de 5 Partidos Predichos vs Resultado Real):\n")

df_sample_pred <- dbGetQuery(con, "
  SELECT 
    mp.id_partido,
    el.nombre_oficial AS equipo_local,
    ev.nombre_oficial AS equipo_visitante,
    ROUND(mp.prob_victoria_local * 100, 2) AS prob_local_pct,
    mp.prediccion_victoria AS pred_vic,
    mp.victoria_real AS vic_real,
    mp.acierto_prediccion AS acierto
  FROM segunda_feb_pro.match_predictions mp
  JOIN segunda_feb_pro.equipos el ON mp.id_equipo_local = el.id_equipo
  JOIN segunda_feb_pro.equipos ev ON mp.id_equipo_visitante = ev.id_equipo
  ORDER BY mp.id_partido DESC
  LIMIT 5;
")

print(as.data.frame(df_sample_pred), row.names = FALSE)

dbDisconnect(con)

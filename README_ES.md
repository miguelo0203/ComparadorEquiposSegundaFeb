[🇪🇸 Español](README_ES.md) | [🇬🇧 English](README.md)

# 🏀 Segunda FEB: Plataforma de Analítica & Scouting de Baloncesto
> **Plataforma interactiva de inteligencia deportiva, scouting de jugadores y predicción de encuentros para la Segunda FEB (España), construida con R Shiny, SQLite/PostgreSQL y Machine Learning.**

[![R](https://img.shields.io/badge/R-4.6.1-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/R%20Shiny-Cloud-green.svg)](https://shiny.posit.co/)
[![Live App](https://img.shields.io/badge/Web%20App-shinyapps.io-success.svg)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
[![SQLite](https://img.shields.io/badge/SQLite-Standalone-green.svg)](https://www.sqlite.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.0-blue.svg)](https://www.postgresql.org/)
[![Machine Learning](https://img.shields.io/badge/ML-Logistic_Regression_AUC_0.9867-orange.svg)](https://scikit-learn.org/)

---

## 🚀 Empieza aquí

*Si es tu primera vez en este proyecto:*
1. 🌐 **[Abrir aplicación web interactiva (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)**: Explora la aplicación en vivo en la nube (simulador de partidos, cuadrantes de eficiencia ORtg/DRtg, scouting de jugadores y radar posicional).
2. 👔 **[Dossier ejecutivo de producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)** | **[Executive Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)**: Visión completa de arquitectura, modelos y aplicación práctica en el club.
3. 📄 **[Resumen ejecutivo simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md)** | **[Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md)**: Documento conciso de 2 páginas con los hallazgos principales y métricas clave.
4. 📋 **[Informe de scouting de partido de ejemplo](reports/scouting_report_match_2471077.md)** | **[Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md)**: Ejemplo real de informe táctico prepartido generado automáticamente.

---

## 📌 ¿Qué es este proyecto?

**SEGUNDA FEB PRO** es una plataforma de inteligencia analítica y scouting desarrollada para cuerpos técnicos, directores deportivos y analistas de baloncesto.

A partir del procesamiento automatizado de actas oficiales de la **Federación Española de Baloncesto (FEB)** para los 28 clubes de la Segunda FEB, la plataforma ofrece una aplicación web interactiva en **R Shiny** con arquitectura dual de datos (SQLite autónomo en la nube y PostgreSQL 16 en local), modelos de **Clustering K-Means** (identificación de arquetipos tácticos funcionales), **Regresión Logística multivariable** (simulador predictivo de partidos con **AUC de 0.9867**) y generación automatizada de informes tácticos (*NLG*).

---

## 🏆 Resultados clave

- 🔮 **Simulador predictivo de partidos (Machine Learning)**: Modelo de Regresión Logística multivariable entrenado con el histórico completo de la liga, alcanzando un **AUC de 0.9867** y una **precisión de clasificación del 94.12%** a partir de diferenciales de Four Factors y ritmo (Pace).
- 🎯 **Clasificación funcional por arquetipos (K-Means Clustering)**: Agrupamiento determinista ($k=6$, Silhouette $=0.58$, $	ext{BSS}/	ext{TSS} = 57.87\%$) que identifica el rol táctico real del jugador en pista (*Rim Protector, Stretch Big, 3&D Wing, Slashing Scorer, Primary Initiator, Paint Finisher*) superando la posición nominal del acta.
- 📊 **Matriz de cuadrantes de eficiencia (ORtg vs. DRtg)**: Mapa interactivo en Plotly de los 28 clubes clasificados en 4 cuadrantes tácticos (**ÉLITE**, **PERFIL OFENSIVO**, **PERFIL DEFENSIVO**, **EN CONSTRUCCIÓN**), con la escala defensiva invertida para facilitar su lectura a los entrenadores.
- 🟢 **Índice de regularidad y fiabilidad ($CV$)**: Medición de la consistencia partido a partido mediante el Coeficiente de Variación de valoración: *Altamente Consistente* ($CV < 0.35$), *Estable* ($0.35 \le CV \le 0.60$) o *Volátil* ($CV > 0.60$).
- ⚖️ **Índice Herfindahl-Hirschman (HHI) y ratio de rotación**: Medición de la concentración del volumen anotador colectivo (reparto equilibrado $\le 15.0\%$ vs. hiperdependencia $> 15.0\%$) y proporción de minutos asumidos por el quinteto titular frente al banquillo.

---

## 🛠️ Qué he construido

1. **Aplicación interactiva en R Shiny (`app.R` / `app_en.R`)**: 5 módulos funcionales con diseño visual oscuro de alto contraste (*Dark Analytics Theme*), gráficos reactivos en Plotly y tablas paginadas en DT.
2. **Arquitectura dual de datos**: Compatibilidad directa con PostgreSQL 16 (desarrollo local y flujos de análisis) y SQLite optimizado (despliegue autónomo en la nube en shinyapps.io).
3. **Flujo ETL y normalización de posesiones**: Extracción automatizada de actas oficiales FEB, cálculo de posesiones estimadas y los Cuatro Factores de Dean Oliver ($eFG\%$, $TOV\%$, $OREB\%$, $FTr$).
4. **Módulo de scouting y comparador de percentiles**: Radar polar de 5 ejes que compara a cada jugador frente a la mediana exacta de sus rivales de posición en métricas normalizadas por 40 minutos.
5. **Generador automático de informes prepartido (NLG)**: Algoritmo de detección de ventajas estadísticas y redacción instantánea de informes tácticos objetivos.

---

## 🎯 Por qué es relevante

En categorías profesionales donde los presupuestos son ajustados y los calendarios exigentes, basar las decisiones únicamente en la intuición o en estadísticas tradicionales de acta genera ineficiencias financieras y tácticas. Esta plataforma actúa como un apoyo cuantitativo que ahorra horas de visionado manual, identifica oportunidades en el mercado de fichajes (*Recruitment Finder*) y detecta las claves tácticas antes de cada jornada.

---

## 🧭 Navegación del proyecto

### 👔 Vista ejecutiva (Entrenadores, Scouts y Directores Deportivos)
- 🌐 [Aplicación web en vivo (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
- 📄 [Dossier ejecutivo de producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md) | [Executive Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)
- 📄 [Resumen ejecutivo simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md) | [Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md)
- 📋 [Informe de scouting de partido (Español)](reports/scouting_report_match_2471077.md) | [Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md)

### 🔬 Vista técnica (Analistas de Datos e Ingenieros)
- `app.R` / `shiny_app/app.R`: Código principal de la aplicación R Shiny (Español).
- `app_en.R` / `shiny_app/app_en.R`: Código de la aplicación R Shiny (English).
- `analytics/eda_segunda_feb.R`: Análisis exploratorio de datos de la competición.
- `analytics/ml_modelo_predictivo_fase6.R`: Entrenamiento y validación del modelo de Regresión Logística (AUC de 0.9867).
- `analytics/motor_clustering_fase4.R`: Pipeline K-Means de arquetipos tácticos.
- `audit/auditoria_cientifica_fase4.R` y `audit/auditoria_silhouette.R`: Validación matemática de los clusters.
- `database/`: Scripts SQL DDL, exportación a SQLite y conexión segura a PostgreSQL.

---

## 📂 Estructura del repositorio

```text
ComparadorEquiposSegundaFeb/
├── README.md                           # Presentación del proyecto (English)
├── README_ES.md                        # Presentación del proyecto (Español)
├── app.R                               # Servidor y UI de la aplicación Shiny (Español)
├── app_en.R                            # Servidor y UI de la aplicación Shiny (English)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md  # Dossier ejecutivo maestro (Español)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md # Dossier ejecutivo maestro (English)
├── RESUMEN_EJECUTIVO_SIMPLE.md         # Resumen ejecutivo de 2 páginas (Español)
├── RESUMEN_EJECUTIVO_SIMPLE_EN.md      # Resumen ejecutivo de 2 páginas (English)
├── segunda_feb_pro.sqlite              # Base de datos embebida para despliegue web
│
├── analytics/                          # Motores estadísticos y Machine Learning
│   ├── eda_segunda_feb.R               # Análisis exploratorio de la competición
│   ├── ml_modelo_predictivo_fase6.R    # Regresión logística y simulación predictiva
│   ├── motor_clustering_fase4.R        # Arquetipos tácticos K-Means
│   ├── motor_colectivo_fase4.R         # Four Factors y ratings colectivos
│   └── motor_jugadores_fase4.R         # Métricas normalizadas por 40 min
│
├── audit/                              # Auditorías de calidad y validación científica
│   ├── auditoria_cientifica_fase4.R    # Trazabilidad y validación de variables
│   ├── auditoria_silhouette.R          # Coeficiente Silhouette de clusters
│   └── auditoria_final_produccion_fase9.R # Comprobaciones de integridad previas al despliegue
│
├── database/                           # Scripts SQL y gestión de datos
│   ├── export_to_sqlite.R              # Pipeline de exportación Postgres -> SQLite
│   ├── normalize_names.R               # Normalización de entidades y nombres
│   └── auditoria_global.sql            # Consultas de verificación de esquema
│
├── reports/                            # Generación de informes prepartido
│   ├── generar_informe_scouting.R      # Generador automatizado de informes (Español)
│   ├── generar_informe_scouting_en.R   # Generador automatizado de informes (English)
│   ├── scouting_report_match_2471077.md # Informe de ejemplo (Español)
│   └── scouting_report_match_2471077_EN.md # Informe de ejemplo (English)
│
└── shiny_app/                          # Paquete de despliegue en la nube
    ├── app.R                           # Standalone Shiny App (Español)
    └── app_en.R                        # Standalone Shiny App (English)
```

---

## 👤 Autor y contacto

**Miguel** — Data Analyst | Basketball Analytics  
- **GitHub**: [@miguelo0203](https://github.com/miguelo0203)
- **LinkedIn**: [linkedin.com/in/miguelo0203](https://www.linkedin.com)
- **Aplicación web en vivo**: [miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

---
*Plataforma analítica reproducible desarrollada con R Shiny, SQLite, PostgreSQL y Machine Learning.*

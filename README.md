[🇪🇸 Español](README.md) | [🇬🇧 English](README_EN.md)

# 🏀 Segunda FEB: Plataforma de Analítica & Scouting de Baloncesto
> **Plataforma interactiva de inteligencia deportiva, scouting de jugadores y predicción de encuentros para la Segunda FEB (España), impulsada por R Shiny, SQLite/PostgreSQL y Machine Learning.**

[![R](https://img.shields.io/badge/R-4.6.1-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/R%20Shiny-Cloud-green.svg)](https://shiny.posit.co/)
[![Live App](https://img.shields.io/badge/Web%20App-shinyapps.io-success.svg)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
[![SQLite](https://img.shields.io/badge/SQLite-Standalone-green.svg)](https://www.sqlite.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.0-blue.svg)](https://www.postgresql.org/)
[![Machine Learning](https://img.shields.io/badge/ML-Logistic_Regression_AUC_0.9867-orange.svg)](https://scikit-learn.org/)

---

## 🚀 Empieza Aquí (Start Here)

*Si es tu primera vez en este proyecto:*
1. 🌐 **[Abrir Aplicación Web Interactiva (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)**: Explora el dashboard en vivo en la nube (simulador de partidos, cuadrantes ORtg/DRtg, scouting de jugadores y radar posicional).
2. 👔 **[Dossier Ejecutivo de Producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)** | **[Executive Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)**: Visión completa de arquitectura, modelos y valor deportivo.
3. 📄 **[Resumen Ejecutivo Simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md)** | **[Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md)**: Documento conciso de 2 páginas con hallazgos y KPIs.
4. 📋 **[Informe de Scouting de Partido de Ejemplo](reports/scouting_report_match_2471077.md)** | **[Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md)**: Ejemplo real de informe táctico prepartido generado automáticamente.

---

## 📌 ¿Qué es este proyecto? (What is this?)

**SEGUNDA FEB PRO** es una plataforma integral de inteligencia analítica y scouting desarrollada para cuerpos técnicos, directores deportivos y analistas de baloncesto.

Transforma el procesamiento automatizado de actas oficiales de la **Federación Española de Baloncesto (FEB)** para los 28 clubes de la Segunda FEB en una aplicación web interactiva en **R Shiny** con arquitectura dual de datos (SQLite autónomo en la nube y PostgreSQL 16 en local), modelos no supervisados de **Clustering K-Means** (identificación de arquetipos tácticos), **Regresión Logística multivariable** (simulador predictivo de partidos con **AUC 0.9867**) y generación automatizada de informes en lenguaje natural (*NLG*).

---

## 🏆 Resultados Clave (Key Results)

- 🔮 **Simulador Predictivo de Partidos (Machine Learning)**: Modelo de Regresión Logística multivariable entrenado con el histórico completo de la liga, alcanzando un **AUC de 0.9867** y una **Precisión de clasificación del 94.12%** a partir de diferenciales de Four Factors y Pace.
- 🎯 **Clasificación Funcional por Arquetipos (K-Means Clustering)**: Agrupamiento determinista ($k=6$, Silhouette $=0.58$, $\text{BSS}/\text{TSS} = 57.87\%$) que identifica el rol táctico real del jugador (*Rim Protector, Stretch Big, 3&D Wing, Slashing Scorer, Primary Initiator, Paint Finisher*) superando la posición nominal del acta.
- 📊 **Matriz de Cuadrantes de Eficiencia (ORtg vs. DRtg)**: Mapeo interactivo en Plotly de los 28 clubes en 4 cuadrantes tácticos (**ÉLITE**, **PERFIL OFENSIVO**, **PERFIL DEFENSIVO**, **EN CONSTRUCCIÓN**), con escala defensiva invertida para lectura táctica intuitiva.
- 🟢 **Índice de Regularidad y Fiabilidad ($CV$)**: Clasificación de consistencia partido a partido mediante el Coeficiente de Variación de valoración: *Altamente Consistente* ($CV < 0.35$), *Estable* ($0.35 \le CV \le 0.60$) o *Volátil/Boom-or-Bust* ($CV > 0.60$).
- ⚖️ **Índice Herfindahl-Hirschman (HHI) y Ratio de Rotación**: Medición de la concentración anotadora colectiva (coral $\le 15.0\%$ vs. hiper-dependiente $> 15.0\%$) y porcentaje de minutos asumidos por los 5 titulares vs. banquillo.

---

## 🛠️ Qué he construido (What I Built)

1. **Dashboard Interactivo R Shiny (`app.R` / `app_en.R`)**: 5 módulos funcionales con tema visual oscuro (*Dark Analytics Theme*), gráficos reactivos en Plotly y tablas paginadas en DT.
2. **Arquitectura Dual de Datos**: Soporte transparente para PostgreSQL 16 (desarrollo local y pipelines) y SQLite optimizado (despliegue en la nube en Posit shinyapps.io).
3. **Pipeline ETL & Normalización**: Extracción automatizada de actas oficiales FEB, cálculo de posesiones y Four Factors de Dean Oliver ($eFG\%$, $TOV\%$, $OREB\%$, $FTr$).
4. **Motor de Scouting & Comparador de Percentiles**: Radar polar de 5 ejes comparando a cada jugador frente a la mediana exacta de sus rivales posicionales en métricas por 40 minutos.
5. **Generador NLG de Informes Prepartido**: Algoritmo de detección de outliers y redacción instantánea de informes tácticos objetivos.

---

## 🎯 Por qué es relevante (Why It Matters)

En ligas profesionales con presupuestos acotados y calendarios exigentes, la toma de decisiones basada exclusivamente en la intuición o estadísticas tradicionales de box-score genera ineficiencias financieras y tácticas. Esta plataforma actúa como un copiloto cuantitativo que reduce horas de visionado manual, identifica gangas de mercado (*Recruitment Finder*) y detecta las ventajas diferenciales antes de cada encuentro.

---

## 🧭 Navegación del Proyecto (Project Navigation)

### 👔 Vista Ejecutiva (Coaches, Scouts & Directivos)
- 🌐 [Aplicación Web en Vivo (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
- 📄 [Dossier Ejecutivo de Producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md) | [Executive Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)
- 📄 [Resumen Ejecutivo Simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md) | [Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md)
- 📋 [Informe de Scouting de Partido (Español)](reports/scouting_report_match_2471077.md) | [Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md)

### 🔬 Vista Técnica (Data Analysts & Engineers)
- `app.R` / `shiny_app/app.R`: Aplicación interactiva R Shiny principal (Español).
- `app_en.R` / `shiny_app/app_en.R`: Interactive R Shiny dashboard (English).
- `analytics/eda_segunda_feb.R`: Análisis exploratorio de datos y distribuciones.
- `analytics/ml_modelo_predictivo_fase6.R`: Entrenamiento y validación del modelo de Regresión Logística (AUC 0.9867).
- `analytics/motor_clustering_fase4.R`: Modelo K-Means de arquetipos tácticos.
- `audit/auditoria_cientifica_fase4.R` & `audit/auditoria_silhouette.R`: Validación matemática de clusters y robustez.
- `database/`: Scripts SQL DDL, exportación a SQLite y conexión segura PostgreSQL.

---

## 📂 Estructura del Repositorio

```text
ComparadorEquiposSegundaFeb/
├── README.md                           # Presentación del proyecto (Español)
├── README_EN.md                        # Project presentation (English)
├── app.R                               # Servidor y UI de la App Shiny (Español)
├── app_en.R                            # Server & UI of the Shiny App (English)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md  # Dossier ejecutivo maestro (Español)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md # Executive master portfolio (English)
├── RESUMEN_EJECUTIVO_SIMPLE.md         # Resumen ejecutivo de 2 páginas (Español)
├── RESUMEN_EJECUTIVO_SIMPLE_EN.md      # Simple executive summary (English)
├── segunda_feb_pro.sqlite              # Base de datos embebida para despliegue web
│
├── analytics/                          # Motores estadísticos y Machine Learning
│   ├── eda_segunda_feb.R               # Análisis exploratorio de la competición
│   ├── ml_modelo_predictivo_fase6.R    # Regresión logística y simulación
│   ├── motor_clustering_fase4.R        # Arquetipos tácticos K-Means
│   ├── motor_colectivo_fase4.R         # Four Factors y ratings colectivos
│   └── motor_jugadores_fase4.R         # Métricas normalizadas por 40 min
│
├── audit/                              # Auditorías de calidad y validación científica
│   ├── auditoria_cientifica_fase4.R    # Trazabilidad y validación de variables
│   ├── auditoria_silhouette.R          # Coeficiente Silhouette de clusters
│   └── auditoria_final_produccion_fase9.R # Sanity checks pre-despliegue
│
├── database/                           # Scripts SQL y gestión de datos
│   ├── export_to_sqlite.R              # Pipeline de exportación Postgres -> SQLite
│   ├── normalize_names.R               # Resolución de entidades y nombres
│   └── auditoria_global.sql            # Consultas de verificación de esquema
│
├── reports/                            # Generación de informes prepartido
│   ├── generar_informe_scouting.R      # Generador automatizado NLG (Español)
│   ├── generar_informe_scouting_en.R   # Automated NLG report generator (English)
│   ├── scouting_report_match_2471077.md # Informe de ejemplo (Español)
│   └── scouting_report_match_2471077_EN.md # Example match report (English)
│
└── shiny_app/                          # Paquete de despliegue en la nube
    ├── app.R                           # Standalone Shiny App (Español)
    └── app_en.R                        # Standalone Shiny App (English)
```

---

## 👤 Autor y Contacto

**Miguel** — Data Analyst | Basketball Analytics  
- **GitHub**: [@miguelo0203](https://github.com/miguelo0203)
- **LinkedIn**: [linkedin.com/in/miguelo0203](https://www.linkedin.com)
- **Live Dashboard**: [miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

---
*Plataforma analítica reproducible desarrollada con R Shiny, SQLite, PostgreSQL y Machine Learning.*

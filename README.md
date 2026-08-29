[🇬🇧 English](README.md) | [🇪🇸 Español](README_ES.md)

# 🏀 Segunda FEB: Basketball Analytics & Scouting Platform
> **Interactive sports intelligence, player scouting, and match prediction platform for Spain's Segunda FEB league, powered by R Shiny, SQLite/PostgreSQL, and Machine Learning.**

[![R](https://img.shields.io/badge/R-4.6.1-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/R%20Shiny-Cloud-green.svg)](https://shiny.posit.co/)
[![Live App](https://img.shields.io/badge/Web%20App-shinyapps.io-success.svg)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
[![SQLite](https://img.shields.io/badge/SQLite-Standalone-green.svg)](https://www.sqlite.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.0-blue.svg)](https://www.postgresql.org/)
[![Machine Learning](https://img.shields.io/badge/ML-Logistic_Regression_AUC_0.9867-orange.svg)](https://scikit-learn.org/)

---

## 🚀 Start Here

*New to this project?*
1. 🌐 **[Open Interactive Live Web App (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)**: Explore the cloud-deployed dashboard (match simulator, ORtg/DRtg quadrants, player scouting, and positional percentile radar).
2. 👔 **[Executive Product Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)** | **[Dossier Ejecutivo de Producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)**: Full architecture breakdown, statistical models, and basketball value proposition.
3. 📄 **[Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md)** | **[Resumen Ejecutivo Simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md)**: Concise 2-page brief with core findings and KPIs.
4. 📋 **[Sample Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md)** | **[Informe de Scouting de Partido (Español)](reports/scouting_report_match_2471077.md)**: Real-world example of an automated pre-game tactical brief.

---

## 📌 What is this?

**SEGUNDA FEB PRO** is an end-to-end sports intelligence and scouting platform designed for coaching staffs, sporting directors, and basketball analysts.

It automates the ingestion of official game box scores from the **Spanish Basketball Federation (FEB)** across all 28 clubs in Segunda FEB into an interactive **R Shiny** web application with a dual data architecture (standalone SQLite for cloud hosting and PostgreSQL 16 for local development), unsupervised **K-Means Clustering** (functional tactical archetypes), multivariable **Logistic Regression** (match simulation engine with **AUC 0.9867**), and automated Natural Language Generation (*NLG*) scouting reports.

---

## 🏆 Key Results

- 🔮 **Match Prediction & Win Probability Simulator (ML)**: Multivariable Logistic Regression model trained on historical league data, achieving an **AUC of 0.9867** and **94.12% classification accuracy** from Four Factors differentials and Pace.
- 🎯 **Functional Archetype Clustering (K-Means)**: Deterministic clustering ($k=6$, Silhouette $=0.58$, $\text{BSS}/\text{TSS} = 57.87\%$) identifying players' true tactical on-court roles (*Rim Protector, Stretch Big, 3&D Wing, Slashing Scorer, Primary Initiator, Paint Finisher*) beyond nominal roster positions.
- 📊 **Efficiency Quadrant Matrix (ORtg vs. DRtg)**: Interactive Plotly scatter plot mapping all 28 clubs across 4 tactical quadrants (**ELITE**, **OFFENSIVE PROFILE**, **DEFENSIVE PROFILE**, **REBUILDING / IN CONSTRUCTION**), featuring an inverted defensive axis for intuitive coaching comprehension.
- 🟢 **Consistency & Reliability Index ($CV$)**: Game-to-game stability classification based on evaluation score Coefficient of Variation: *Highly Consistent* ($CV < 0.35$), *Stable Performance* ($0.35 \le CV \le 0.60$), or *Volatile / Boom-or-Bust* ($CV > 0.60$).
- ⚖️ **Herfindahl-Hirschman Index (HHI) & Rotation Ratio**: Quantitative assessment of team scoring concentration (balanced $\le 15.0\%$ vs. hyper-dependent $> 15.0\%$) and starter vs. bench playing time allocation.

---

## 🛠️ What I Built

1. **Interactive R Shiny Dashboard (`app.R` / `app_en.R`)**: 5 specialized modules with dark analytics styling, reactive Plotly charts, and paginated DT tables.
2. **Dual Data Architecture**: Transparent support for PostgreSQL 16 (local development and pipelines) and optimized SQLite (cloud deployment on Posit shinyapps.io).
3. **ETL Pipeline & Metric Normalization**: Automated extraction of FEB box scores, possession reconstruction, and Dean Oliver's Four Factors ($eFG\%$, $TOV\%$, $OREB\%$, $FTr$).
4. **Positional Percentile Radar**: 5-axis polar chart benchmarking individual player production per 40 minutes against the exact positional median.
5. **Automated NLG Pre-Game Brief Generator**: Outlier detection engine generating objective tactical summaries highlighting decisive matchup advantages.

---

## 🎯 Why It Matters

In professional basketball leagues operating under tight budgets and demanding schedules, relying solely on intuition or basic box-score totals creates substantial financial and tactical inefficiencies. This platform acts as a quantitative co-pilot that saves hours of manual video scouting, identifies undervalued market targets (*Recruitment Finder*), and pinpoints game-deciding matchups before tip-off.

---

## 🧭 Project Navigation

### 👔 Executive View (Coaches, Scouts & Sporting Directors)
- 🌐 [Interactive Live Web App (shinyapps.io)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)
- 📄 [Executive Product Portfolio Dossier (English)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md) | [Dossier Ejecutivo de Producto (Español)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)
- 📄 [Simple Executive Summary (English)](RESUMEN_EJECUTIVO_SIMPLE_EN.md) | [Resumen Ejecutivo Simple (Español)](RESUMEN_EJECUTIVO_SIMPLE.md)
- 📋 [Sample Match Scouting Report (English)](reports/scouting_report_match_2471077_EN.md) | [Informe de Scouting de Partido (Español)](reports/scouting_report_match_2471077.md)

### 🔬 Technical View (Data Analysts & Engineers)
- `app_en.R` / `shiny_app/app_en.R`: Interactive R Shiny dashboard (English).
- `app.R` / `shiny_app/app.R`: Main interactive R Shiny application (Spanish).
- `analytics/eda_segunda_feb.R`: Exploratory data analysis and league-wide metric distributions.
- `analytics/ml_modelo_predictivo_fase6.R`: Logistic Regression training, ROC-AUC curve, and win probability simulation.
- `analytics/motor_clustering_fase4.R`: K-Means archetype clustering model.
- `audit/auditoria_cientifica_fase4.R` & `audit/auditoria_silhouette.R`: Mathematical validation of cluster stability and data integrity.
- `database/`: SQL DDL schemas, PostgreSQL-to-SQLite export pipelines, and entity resolution scripts.

---

## 📂 Repository Structure

```text
ComparadorEquiposSegundaFeb/
├── README.md                           # Project presentation (Spanish)
├── README_EN.md                        # Project presentation (English)
├── app.R                               # Shiny App Server & UI (Spanish)
├── app_en.R                            # Shiny App Server & UI (English)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md  # Executive master dossier (Spanish)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md # Executive master dossier (English)
├── RESUMEN_EJECUTIVO_SIMPLE.md         # 2-Page Executive Summary (Spanish)
├── RESUMEN_EJECUTIVO_SIMPLE_EN.md      # 2-Page Executive Summary (English)
├── segunda_feb_pro.sqlite              # Embedded database for cloud deployment
│
├── analytics/                          # Statistical and Machine Learning engines
│   ├── eda_segunda_feb.R               # League-wide exploratory analysis
│   ├── ml_modelo_predictivo_fase6.R    # Logistic Regression & simulation
│   ├── motor_clustering_fase4.R        # K-Means tactical archetypes
│   ├── motor_colectivo_fase4.R         # Four Factors and collective ratings
│   └── motor_jugadores_fase4.R         # Per-40-minute normalized metrics
│
├── audit/                              # Quality audits & scientific validation
│   ├── auditoria_cientifica_fase4.R    # Data lineage & variable validation
│   ├── auditoria_silhouette.R          # Silhouette cluster evaluation
│   └── auditoria_final_produccion_fase9.R # Pre-deployment sanity checks
│
├── database/                           # SQL scripts and database engineering
│   ├── export_to_sqlite.R              # Postgres -> SQLite export pipeline
│   ├── normalize_names.R               # Entity resolution & name cleaning
│   └── auditoria_global.sql            # Schema verification SQL queries
│
├── reports/                            # Pre-game report generation
│   ├── generar_informe_scouting.R      # Automated NLG report generator (Spanish)
│   ├── generar_informe_scouting_en.R   # Automated NLG report generator (English)
│   ├── scouting_report_match_2471077.md # Sample match report (Spanish)
│   └── scouting_report_match_2471077_EN.md # Sample match report (English)
│
└── shiny_app/                          # Cloud deployment package (Posit shinyapps.io)
    ├── app.R                           # Standalone Shiny App (Spanish)
    └── app_en.R                        # Standalone Shiny App (English)
```

---

## 👤 Author & Contact

**Miguel** — Data Analyst | Basketball Analytics  
- **GitHub**: [@miguelo0203](https://github.com/miguelo0203)
- **LinkedIn**: [linkedin.com/in/miguelo0203](https://www.linkedin.com)
- **Live Dashboard**: [miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

---
*Reproducible analytics platform built with R Shiny, SQLite, PostgreSQL, and Machine Learning.*

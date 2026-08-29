[🇬🇧 English](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md) | [🇪🇸 Español](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)

# 🏀 SEGUNDA FEB PRO: Comprehensive Quantitative Intelligence & Advanced Scouting Platform
> **Executive Product Dossier & Technology Architecture Applied to High Performance**
> 
> *Designed for Sporting Directors, Coaching Staffs, and Professional Sports Agencies.*

---

## Executive Summary: Turning Data into Wins and Efficient Decisions

In modern professional basketball, the difference between competing for promotion to Primera FEB (LEB Oro) or struggling to avoid relegation in **Segunda FEB** lies in the ability to minimize the margin of error. With constrained budgets and demanding competition schedules, decision-making based solely on traditional intuition or raw box-score statistics (unadjusted points and rebounds) creates significant financial and tactical inefficiencies.

**SEGUNDA FEB PRO** is an enterprise-grade analytics ecosystem built natively on **PostgreSQL 16**, **R (Statistical Computing Platform)**, and **R Shiny**. The system centralizes automated web scraping of official game box scores, advanced feature engineering (100-possession normalized metrics, Dean Oliver's Four Factors), unsupervised and supervised Machine Learning modeling, and automated Natural Language Generation (*NLG*) reporting.

The core objective of this ecosystem is to serve as an **objective quantitative co-pilot**, eliminating hours of manual video scouting and delivering a clear competitive edge before, during, and after every game week.

---

## 🔄 1. Technology Translation: From Data Science to High-Performance Basketball

To bridge statistical complexity with day-to-day front office and coaching operations, the architecture of **SEGUNDA FEB PRO** translates every algorithmic module into direct basketball value:

| Technical Module / Algorithm | Statistical Metric or Model | Sports & Business Translation |
| :--- | :--- | :--- |
| **Unsupervised Clustering** | K-Means ($k=6$, Silhouette $=0.58$, $\text{BSS}/\text{TSS} = 57.87\%$) | **Functional Archetype Classification:** Identifying a player's real on-court role (*Stretch Big, 3&D Wing, Slashing Scorer, Rim Protector*) beyond the nominal position listed on the roster. |
| **Supervised Predictive Model** | Multivariable Logistic Regression (**AUC 0.9867**, Accuracy 94.12%) | **Win Probability Simulator:** Quantitative match outcome projection and exact breakdown of critical matchup differentials. |
| **Natural Language Generation (NLG)** | Tactical Rule Engine & Outlier Detection | **Automated Pre-Game Brief Generator:** Instant generation of objective match briefs and player evaluation profiles free from emotional bias. |
| **Robust Dispersion Statistics** | Median Absolute Deviation (MAD) & Coefficient of Variation (CV) | **Consistency & Reliability Index:** Categorizing players by game-to-game stability (*Highly Consistent, Stable,* or *Volatile / Boom-or-Bust*). |
| **Economic-Statistical Concentration** | Herfindahl-Hirschman Index (HHI) & Rotation Ratio | **Offensive Dependency Audit:** Numerical measurement of scoring distribution concentration and monitoring starter fatigue vs. bench contribution. |

---

## 🧩 2. Module-by-Module Breakdown of the R Shiny Platform

The interactive platform is organized into **5 specialized modules**, accessible via an enterprise web interface with high-contrast Dark Analytics styling:

### 1. Team Matchup Engine & Efficiency Quadrants (ORtg vs. DRtg)
* **Tactical Objective**: Pre-game assessment of team pace, net efficiency differentials per 100 possessions, and Dean Oliver's **Four Factors**:
  $$\text{Four Factors} = \{\text{eFG\%}, \text{TOV\%}, \text{OREB\%}, \text{FT Rate}\}$$
* **Collective Efficiency Quadrant Matrix**: Interactive Plotly scatter plot mapping all 28 Segunda FEB clubs crossing *Offensive Rating* (Y-axis) and *Defensive Rating* (inverted X-axis). Instantly visualizes teams across 4 tactical quadrants: **ELITE**, **OFFENSIVE PROFILE**, **DEFENSIVE PROFILE**, and **REBUILDING / IN CONSTRUCTION**.
* **Adaptive Tactical Narrative Engine**: Algorithm that detects significant statistical outliers and generates automated pre-game headlines focusing on real strategic advantages (e.g., transition turnovers or second-chance dominance).

> [!NOTE]
> **Defensive Rating Axis Inversion:** On the quadrant matrix, the Defensive Rating scale is inverted so that lower values (defensive excellence) appear to the right, enabling intuitive reading for coaching staffs.

---

### 2. Player Scouting & Comprehensive Dossier
* **Scouting Objective**: Deep, individualized performance profiling for every player in the competition.
* **Player Bio & Consistency Badge**: Displays biometric data, functional K-Means archetype assignment, and a stability badge based on evaluation score dispersion across games ($CV = \sigma / \mu$):
  * 🟢 **Highly Consistent** ($CV < 0.35$)
  * 🔵 **Stable Performance** ($0.35 \le CV \le 0.60$)
  * 🟡 **Volatile / Boom-or-Bust** ($CV > 0.60$)
* **Positional Percentile Radar (0–100)**: 5-axis polar chart benchmarking the player against the exact median of positional peers in *Evaluation, True Shooting (TS%), Scoring, Rebounding,* and *Assists*.
* **Per-40 Minute Table & NLG Brief**: Normalization to 40 minutes of playing time and automated commentary on possession usage (`USG%`) and true shooting efficiency (`TS%`).

---

### 3. Recruitment Finder (Market Intelligence & Roster Construction)
* **Front Office Objective**: Surgical identification of transfer market targets tailored to budget limits and specific positional needs.
* **Combined Performance Filters**:
  * Scoring volume per 40 minutes (`PPG / 40 min`).
  * True shooting efficiency (`True Shooting TS%`).
  * Overall production (`VAL / 40 min`).
  * Nominal position (including **Unknown / Versatile** for positionless players).
  * K-Means tactical archetypes (e.g., filtering exclusively for *Rim Protectors* or *Off-Ball Specialists*).
* **Structured Output**: Interactive, filterable table with clean pagination ready for executive export.

---

### 4. Match Simulator & Win Probability ML
* **Projection Objective**: Pre-game simulation based on the Logistic Regression model trained on historical league data (**AUC = 0.9867**).
* **Win Probability Gauge**: Interactive percentage probability bar for home vs. away team.
* **Key Factor Differentials**: Breakdown of the 4 most decisive metric advantages that drive the simulated outcome.

---

### 5. Team Executive Summary (Front Office Audit & HHI)
* **Executive Objective**: Macro evaluation of team playing style and playing time allocation.
* **Collective Metrics & Herfindahl-Hirschman Index (HHI)**:
  * **Overall Net Rating** per 100 possessions.
  * **Scoring HHI**: Numerically assesses whether scoring is balanced ($HHI \le 15.0\%$) or heavily concentrated in one or two primary options ($HHI > 15.0\%$).
  * **Rotation Ratio**: Percentage of total team minutes played by the starting 5 vs. the bench.
* **Stylistic Team DNA (Donut Chart)**: Interactive chart displaying the minute share allocated to each K-Means tactical archetype.
* **Descriptive Statistical Diagnostics (Full-Width Grid)**: 3-panel breakdown analyzing *Perimeter Threat*, *Ball Security / Turnover Care*, and *Roster Minute Distribution*.

---

## 🛠️ 3. Repository Architecture

```text
ComparadorEquiposSegundaFeb/
├── app.R                          # Main R Shiny Server & UI (Spanish)
├── app_en.R                       # Main R Shiny Server & UI (English)
├── run_shiny_server.R             # Local Server Launcher (Port 8080)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md # Master Executive Dossier (Spanish)
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md # Master Executive Dossier (English)
├── segunda_feb_pro.sqlite         # Standalone Database for Cloud Deployment
│
├── database/                      # SQL Schema & PostgreSQL Connection Scripts
│   ├── ddl_schema_segunda_feb.sql # Schema DDL (8 Relational Tables)
│   └── get_db_con.R               # Secure Connection Manager (Port 5433 / SQLite)
│
├── analytics/                     # Advanced Analytics & Modeling Modules
│   ├── eda_segunda_feb.R          # Exploratory Data Analysis & Outlier Detection
│   ├── motor_colectivo_fase4.R    # Four Factors & Team Possession Normalization
│   ├── motor_jugadores_fase4.R    # Individual Per-40 Metrics & Dispersion (MAD/CV)
│   ├── motor_clustering_fase4.R   # K-Means Archetype Clustering Pipeline
│   └── ml_modelo_predictivo_fase6.R # Logistic Regression & ROC-AUC Validation
│
├── audit/                         # Scientific Validation & QA Audits
│   ├── auditoria_cientifica_fase4.R # Variable Lineage & Integrity Checks
│   ├── auditoria_silhouette.R     # Silhouette Cluster Quality Validation
│   └── auditoria_final_produccion_fase9.R # Pre-Production Sanity Checks
│
└── reports/                       # Pre-Game Tactical Briefs
    ├── generar_informe_scouting.R # Automated NLG Report Generator (Spanish)
    ├── generar_informe_scouting_en.R # Automated NLG Report Generator (English)
    └── scouting_report_match_2471077.md # Sample Scouting Brief
```

---

## 👤 Author & Contact

**Miguel** — Data Analyst | Basketball Analytics  
- **GitHub**: [@miguelo0203](https://github.com/miguelo0203)
- **LinkedIn**: [linkedin.com/in/miguelo0203](https://www.linkedin.com)
- **Live App**: [miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

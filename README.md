# 🏀 SEGUNDA FEB PRO — Elite Basketball Analytics System

> **Plataforma de Inteligencia Cuantitativa, Scouting Avanzado y Predicción ML para la Segunda FEB (España)**

[![R](https://img.shields.io/badge/R-4.6.1-blue.svg)](https://www.r-project.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.0-blue.svg)](https://www.postgresql.org/)
[![Shiny](https://img.shields.io/badge/R%20Shiny-Enterprise-green.svg)](https://shiny.posit.co/)
[![Machine Learning](https://img.shields.io/badge/ML%20Predictive%20AUC-0.9867-brightgreen.svg)]()

---

## 📌 Visión General

**SEGUNDA FEB PRO** es un ecosistema analítico de nivel profesional diseñado para **Directores Deportivos**, **Cuerpos Técnicos** y **Analistas de Baloncesto (Scouts)**. 

Transforma el scraping automatizado de actas oficiales de la Federación Española de Baloncesto (FEB) en un **dashboard interactivo en R Shiny** respaldado por una base de datos **PostgreSQL 16**, modelos de **Clustering K-Means** (arquetipos tácticos), **Regresión Logística** (simulación de partidos con AUC 0.9867) y **Motores Adaptativos de Generación de Lenguaje Natural (NLG)**.

📄 **[Ver Dossier Ejecutivo Completo de Producto (`PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md`)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)**

---

## 🚀 Módulos del Dashboard R Shiny

1. **Team Matchup Engine & Adaptative NLG**:
   - Evaluación de *Pace* (ritmo), *Net Rating* corregido por 100 posesiones y los **Four Factors de Dean Oliver** ($eFG\%$, $TOV\%$, $OREB\%$, $FT Rate$).
   - **Matriz de Cuadrantes de Eficiencia (ORtg vs DRtg)** con eje defensivo invertido (menor es mejor defensa).
   - Generación de informes narrativos tácticos mediante detección de anomalías (*outliers*).

2. **Player Scouting & Dossier Integral**:
   - Asignación de arquetipos K-Means (*3&D Wing*, *Stretch Big*, *Slashing Scorer*, etc.).
   - **Índice de Regularidad**: Clasificación de estabilidad competitiva mediante estadística robusta (Mediana, MAD y Coeficiente de Variación $CV$).
   - **Radar Posicional de Percentiles (0 - 100)** y desglose Per-40 minutos.

3. **Recruitment Finder (Buscador de Mercado)**:
   - Filtro avanzado de talento por puntos/40, eficiencia real ($TS\%$), valoración/40, arquetipo táctico y posición nominal (incluyendo la categoría **Posición Desconocida**).

4. **Predictor & Simulator ML**:
   - Probabilidad de victoria estimada en tiempo real mediante modelo Logístico ($AUC = 0.9867$, Precisión $94.12\%$).
   - Win Probability Gauge y desglose de factores clave diferenciales.

5. **Team Executive Summary (Auditoría Colectiva & HHI)**:
   - Concentración anotadora (**Índice Herfindahl-Hirschman HHI**).
   - Balance de rotación (% minutos titulares vs. banquillo) y ADN estilístico de plantilla (Donut Chart).
   - **Motor Dinámico de Outliers Multivariable**: Renderizado en paralelo de tarjetas descriptivas según desviación $Z$-Score respecto a la media de la liga.

---

## 📁 Arquitectura del Repositorio

```text
.
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md  # Dossier Maestro Ejecutivo de Producto
├── README.md                           # Documentación Oficial de GitHub
├── .gitignore                          # Exclusión de datos binarios y logs
├── app.R                               # Aplicación R Shiny Principal (Servidor & UI)
├── run_shiny_server.R                  # Script Lanzador en Puerto 8080
│
├── analytics/                          # Motores de Ciencia de Datos & Machine Learning
│   ├── motor_clustering_fase4.R        # Algoritmo K-Means & Arquetipos (Silhouette 0.58)
│   ├── ml_modelo_predictivo_fase6.R    # Modelo Predictivo Logístico (AUC 0.9867)
│   ├── motor_jugadores_fase4.R         # Cálculo de Percentiles Posicionales & MAD/CV
│   └── motor_colectivo_fase4.R         # Eficiencias Colectivas y Four Factors
│
├── database/                           # Scripts SQL & Infraestructura PostgreSQL
│   ├── ddl_schema_segunda_feb.sql      # Schema Relacional (8 Tablas Auditadas)
│   ├── get_db_con.R                    # Conector DBI con Cierre Automático
│   ├── auditoria_global.sql            # Scripts de Calidad de Datos
│   └── clean_nulls.sql                 # Limpieza e Imputación de Registros
│
├── shiny_app/                          # Réplica Entorno Web & Batería de Tests Unitarios
│   ├── app.R                           # App Sincronizada
│   ├── test_app_reactivity.R           # Testing Unitario de Consultas Reactivas
│   └── install_shiny_pkgs.R            # Instalador de Dependencias R
│
├── reports/                            # Motor de Generación de Dossieres PDF/HTML
│   └── generar_informe_scouting.R      # Generador de Informes Automatizados
│
└── audit/                              # Certificados de Salud DB & Análisis Matemático
    ├── auditoria_final_produccion_fase9.R # Auditoría de Integridad DB (0 Huérfanos)
    └── auditoria_silhouette.R          # Validación de Clustering K-Means
```

---

## 🛠️ Requisitos e Instalación

### Requisitos Previos
* **R** (versión $\ge 4.6.0$)
* **PostgreSQL** (versión $\ge 16.0$) en puerto `5433`

### Paquetes R Requeridos
```r
install.packages(c("shiny", "bslib", "DBI", "RPostgres", "dplyr", "tidyr", "stringr", "ggplot2", "plotly", "DT", "pROC"))
```

### Ejecución Rápida en Local

1. **Iniciar Servidor PostgreSQL 16**:
   ```powershell
   & 'C:\Program Files\PostgreSQL\16\bin\postgres.exe' -D 'f:\Otro Proyecto\pg_data' -p 5433
   ```

2. **Lanzar Aplicación Shiny**:
   ```powershell
   & 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' 'f:\Otro Proyecto\run_shiny_server.R'
   ```

3. Abrir en el navegador: **`http://127.0.0.1:8080`**

---

## 🔒 Licencia y Uso
Este repositorio contiene la arquitectura de código y análisis cuantitativo para la competición **Segunda FEB**. Los datos de actas son propiedad oficial de la Federación Española de Baloncesto (FEB).

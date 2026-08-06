# 🏀 SEGUNDA FEB — Plataforma de Analítica & Scouting de Baloncesto

> **Plataforma de Inteligencia Cuantitativa, Scouting de Jugadores y Predicción de Partidos para la Segunda FEB (España)**

[![R](https://img.shields.io/badge/R-4.6.1-blue.svg)](https://www.r-project.org/)
[![SQLite](https://img.shields.io/badge/SQLite-Standalone-green.svg)](https://www.sqlite.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.0-blue.svg)](https://www.postgresql.org/)
[![Shiny](https://img.shields.io/badge/R%20Shiny-Cloud-green.svg)](https://shiny.posit.co/)
[![Live App](https://img.shields.io/badge/Web%20App-shinyapps.io-success.svg)](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

---

## 🌐 Aplicación Web en la Nube
🌐 **Accede a la aplicación en directo**: [https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/](https://miguelo0203.shinyapps.io/ComparadorEquiposSegundaFeb/)

---

## 📌 Visión General

**SEGUNDA FEB** es una plataforma interactiva de analítica avanzada diseñada para **Cuerpos Técnicos**, **Directores Deportivos** y **Analistas de Baloncesto**. 

Transforma el scraping de actas oficiales de la Federación Española de Baloncesto (FEB) en un **dashboard en R Shiny** con motor dual de base de datos (**SQLite autónomo** para entorno Cloud / **PostgreSQL 16** para desarrollo local), modelos de **Clustering K-Means** (arquetipos de jugadores), **Regresión Logística** (simulador de partidos) y **Generación de Informes**.

📄 **[Ver Dossier Ejecutivo de Producto (`PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md`)](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md)**

---

## 🚀 Módulos del Dashboard

1. **Comparativa de Equipos**:
   - Evaluación de *Pace* (ritmo), *Net Rating* por 100 posesiones y los **Four Factors de Dean Oliver** ($eFG\%$, $TOV\%$, $OREB\%$, $FT Rate$).
   - **Eficiencia Ofensiva vs Defensiva (ORtg / DRtg)** en matriz interactiva con opción de **Pantalla Completa**.
   - Informe analítico adaptativo del encuentro basado en desviaciones significativas.

2. **Ficha de Jugador**:
   - Clasificación por arquetipos (*Base Organizador*, *Anotador Principal*, *Alero 3&D*, *Tirador Catch & Shoot*, *Pívot Abierto*, *Interior Defensivo*).
   - **Métricas de Estabilidad**: Evaluación de consistencia competitiva mediante estadística robusta (Mediana, MAD y Coeficiente de Variación $CV$).
   - **Radar de Percentiles (0 - 100)** y desglose Per-40 minutos.
   - **Tabla Completa de 16 Estadísticas & Percentiles en la Liga** estilizada con Bootstrap 5 (barras animadas de progreso e iconos por categoría).

3. **Buscador de Jugadores**:
   - Filtro de mercado por anotación, eficacia real ($TS\%$), valoración por 40 min, arquetipo y posición nominal (incluyendo **Posición Desconocida**).

4. **Simulador de Partidos**:
   - Estimación de probabilidades de victoria mediante modelo Logístico ($AUC = 0.9867$, Precisión $94.12\%$).
   - Gráfico de barras de probabilidad y desglose de factores clave diferenciales.

5. **Resumen de Equipo**:
   - Concentración de puntos (**Índice HHI**).
   - Reparto de minutos (% titulares vs. banquillo) y desglose por arquetipo.
   - **Diagnóstico Estadístico del Equipo**: Tarjetas de análisis en paralelo según desviación respecto a la media de la liga.

---

## 📁 Arquitectura del Repositorio

```text
.
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md  # Dossier Ejecutivo de Producto
├── README.md                           # Documentación Oficial
├── .gitignore                          # Exclusión de datos binarios y temporales
├── app.R                               # Aplicación R Shiny Principal
├── segunda_feb_pro.sqlite              # Base de datos autónoma SQLite (1.77 MB)
├── run_shiny_server.R                  # Lanzador local en puerto 8080
│
├── analytics/                          # Motores de Analítica y Machine Learning
│   ├── motor_clustering_fase4.R        # Clustering K-Means & Arquetipos
│   ├── ml_modelo_predictivo_fase6.R    # Modelo Predictivo Logístico
│   ├── motor_jugadores_fase4.R         # Percentiles Posicionales & MAD/CV
│   └── motor_colectivo_fase4.R         # Eficiencias Colectivas y Four Factors
│
├── database/                           # Infraestructura de Datos
│   ├── normalize_names.R               # Normalización de Arquetipos y Catálogos
│   ├── export_to_sqlite.R              # Exportador PostgreSQL a SQLite
│   ├── deploy_to_cloud.R               # Script de Despliegue Automatizado a shinyapps.io
│   ├── ddl_schema_segunda_feb.sql      # Schema Relacional PostgreSQL
│   └── get_db_con.R                    # Conector DBI con Cierre Automático
│
├── shiny_app/                          # Réplica Entorno Web & Tests
│   ├── app.R                           # App Sincronizada
│   └── test_app_reactivity.R           # Test de Consultas Reactivas
│
└── audit/                              # Validación & Certificación
    ├── auditoria_final_produccion_fase9.R # Auditoría de Calidad DB
    └── auditoria_silhouette.R          # Validación de Clustering K-Means
```

---

## 🛠️ Requisitos e Instalación

### Requisitos Previos
* **R** (versión $\ge 4.6.0$)
* Paquetes R: `shiny`, `bslib`, `DBI`, `RSQLite`, `RPostgres`, `dplyr`, `tidyr`, `stringr`, `ggplot2`, `plotly`, `DT`, `pROC`

### Ejecución Local

```powershell
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' 'f:\Otro Proyecto\run_shiny_server.R'
```
Abrir en el navegador: **`http://127.0.0.1:8080`**

---

## 🔒 Licencia y Uso
Este repositorio contiene la arquitectura de código y análisis estadístico para la competición **Segunda FEB**. Los datos de las actas pertenecen a la Federación Española de Baloncesto (FEB).

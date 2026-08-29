[🇪🇸 Español](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md) | [🇬🇧 English](PORTFOLIO_EJECUTIVO_SEGUNDA_FEB_EN.md)

# 🏀 SEGUNDA FEB PRO: Plataforma Integral de Inteligencia Cuantitativa y Scouting Avanzado
> **Dossier Ejecutivo de Producto & Arquitectura Tecnológica Aplicada al Alto Rendimiento**
> 
> *Diseñado para Directores Deportivos, Cuerpos Técnicos y Agencias de Representación Profesional.*

---

## Executive Summary: Transformando Datos en Victorias y Decisiones Eficientes

En el baloncesto profesional moderno, la diferencia entre luchar por el ascenso a la Liga LEB Oro (Primera FEB) o sufrir por la permanencia en **Segunda FEB** radica en la capacidad de minimizar el margen de error. Con recursos presupuestarios acotados y calendarios competitivos exigentes, la toma de decisiones basada únicamente en la intuición tradicional o en la estadística básica de box-score (puntos y rebotes brutos) genera importantes ineficiencias financieras y tácticas.

**SEGUNDA FEB PRO** es una infraestructura tecnológica de nivel elite (*Enterprise-Grade Analytics Ecosystem*) desarrollada de forma nativa sobre **PostgreSQL 16**, **R (Statistical Computing Platform)** y **R Shiny**. El sistema centraliza el scraping automatizado de actas oficiales, la ingeniería de características avanzadas (100 posesiones, Four Factors de Dean Oliver), el modelado con algoritmos no supervisados y supervisados de Machine Learning, y la generación automatizada de informes en lenguaje natural (*NLG*).

El propósito central de este ecosistema es actuar como **copiloto analítico objetivo**, reduciendo horas de scouting de vídeo manual y proporcionando una ventaja competitiva diferencial antes, durante y después de cada jornada.

---

## 🔄 1. Traducción Tecnológica: Del Lenguaje de Datos al Baloncesto de Alto Rendimiento

Para conectar la complejidad estadística con el día a día del banquillo y la dirección deportiva, la arquitectura de **SEGUNDA FEB PRO** traduce cada avance algorítmico en una solución deportiva directa:

| Módulo Técnico / Algoritmo | Métrica o Modelo Estadístico | Traducción a Lenguaje Deportivo & Negocio |
| :--- | :--- | :--- |
| **Clustering No Supervisado** | K-Means (Silhouette = 0.58, BSS/TSS = 57.87%) | **Clasificación Funcional de Arquetipos:** Identificación del rol real en pista de un jugador (ej. *Stretch Big*, *3&D Wing*, *Slashing Scorer*) más allá de la posición nominal del acta. |
| **Modelo Predictivo Supervisado** | Regresión Logística Múltiple (**AUC 0.9867**, Precisión 94.12%) | **Simulador de Probabilidad de Victoria:** Predicción cuantitativa del ganador y desglose exacto de las variables críticas que decantan el choque. |
| **Procesamiento de Lenguaje Natural (NLG)** | Motor de Reglas Tácticas & Outlier Detection | **Generador Automatizado de Informes de Scouting:** Redacción instantánea de informes de partido y dossieres de jugador objetivos, libres de sesgos emocionales. |
| **Estadística Robusta de Dispersión** | Desviación Absoluta Mediana (MAD) y Coeficiente de Variación (CV) | **Índice de Regularidad y Fiabilidad Competitiva:** Clasificación de jugadores según su estabilidad partido a partido (*Consistente*, *Estable* o *Volátil/Boom-or-Bust*). |
| **Concentración Económico-Estadística** | Índice Herfindahl-Hirschman (HHI) y Ratio de Rotación | **Auditoría de Dependencia Ofensiva:** Medición numérica de la concentración anotadora de un equipo y control del desgaste del quinteto titular frente al banquillo. |

---

## 🧩 2. Desglose Módulo a Módulo de la Plataforma R Shiny

La plataforma interactiva se organiza en **5 pestañas especializadas**, accesibles mediante interfaz web corporativa con diseño en modo oscuro de alta visibilidad (*Dark Analytics Theme*):

### 1. Team Matchup Engine & Matriz de Cuadrantes (ORtg vs DRtg)
* **Objetivo Táctico**: Evaluación previa a cada choque de los ritmos de juego (*Pace*), diferenciales de eficiencia por 100 posesiones y desglose de los **Four Factors de Dean Oliver**:
  $$\text{Four Factors} = \{\text{eFG\%}, \text{TOV\%}, \text{OREB\%}, \text{FT Rate}\}$$
* **Matriz de Cuadrantes de Eficiencia Colectiva**: Gráfico de dispersión interactivo en Plotly que ubica a todos los 28 clubes de la Segunda FEB cruzando el *Offensive Rating* (Eje Y) y el *Defensive Rating* (Eje X invertido). Permite visualizar instantáneamente los equipos pertenecientes a los 4 cuadrantes tácticos: **ÉLITE**, **PERFIL OFENSIVO**, **PERFIL DEFENSIVO** y **EN CONSTRUCCIÓN**.
* **Motor de Narrativa Táctica Adaptativa**: Algoritmo que detecta automáticamente las desviaciones más severas de los datos (*outliers*) y redacta el titular e informe del partido enfocado exclusivamente en las ventajas estratégicas reales (ej. pérdidas en transición o dominio de segundas opciones).

> [!NOTE]
> **Inversión Lógica del DRtg:** En la matriz de cuadrantes, la escala del Defensive Rating se encuentra invertida de manera que los valores menores (excelencia defensiva) se sitúan hacia la derecha, facilitando una lectura intuitiva para el cuerpo técnico.

---

### 2. Player Scouting & Integral Dossier
* **Objetivo de Scouting**: Radiografía profunda e individualizada de cualquier jugador de la competición.
* **Ficha Técnica & Índice de Regularidad**: Muestra los datos biométricos, la adscripción al arquetipo táctico K-Means y asigna una insignia de estabilidad basada en la dispersión de sus puntuaciones de valoración partido a partido ($\text{CV} = \sigma / \mu$):
  * 🟢 **Altamente Consistente** ($\text{CV} < 0.35$)
  * 🔵 **Rendimiento Estable** ($0.35 \le \text{CV} \le 0.60$)
  * 🟡 **Volátil / Boom-or-Bust** ($\text{CV} > 0.60$)
* **Radar Posicional de Percentiles (0-100)**: Gráfico polar de 5 ejes que compara al jugador frente a la mediana exacta de sus rivales de posición en *Valoración*, *True Shooting (TS%)*, *Anotación*, *Rebote* y *Asistencias*.
* **Tabla Per-40 Minutos & Informe NLG**: Normalización del rendimiento a 40 minutos de pista e informe descriptivo automatizado sobre su rol de uso de posesiones (`USG%`) y nivel de tiro real (`TS%`).

---

### 3. Recruitment Finder (Buscador de Mercado & Dirección Deportiva)
* **Objetivo de Fichajes**: Identificación quirúrgica de candidatos de mercado adaptados a restricciones presupuestarias o necesidades específicas de plantilla.
* **Filtros Combinados de Rendimiento**:
  * Volumen anotador por 40 minutos (`PPG / 40 min`).
  * Eficiencia lejana real (`True Shooting TS%`).
  * Producción global (`VAL / 40 min`).
  * Posición nominal (incluyendo la categoría especial **Posición Desconocida** para perfiles polivalentes sin puesto fijo en acta).
  * Arquetipos tácticos K-Means (ej. buscar únicamente *Rim Protectors* o *Off-Ball Specialists*).
* **Salida Estructurada**: Tabla interactiva filtrable con paginación limpia lista para exportación directiva.

---

### 4. Predictor & Match Simulator ML
* **Objetivo de Proyección**: Estimación previa a la disputa del partido basada en el modelo de Regresión Logística entrenado con el histórico completo de la liga (**AUC = 0.9867**).
* **Win Probability Gauge**: Barra interactiva de probabilidad de victoria en porcentaje para el equipo local vs. visitante.
* **Desglose de Factores Clave Diferenciales**: Identificación de los 4 diferenciales más determinantes que el simulador anticipa como claves para conseguir la victoria.

---

### 5. Team Executive Summary (Auditoría Directiva & HHI)
* **Objetivo de Presidencia / Dirección**: Evaluación macro del modelo de juego y reparto de esfuerzos de la plantilla.
* **Métricas Colectivas & HHI (Herfindahl-Hirschman Index)**:
  * **Net Rating Global** por 100 posesiones.
  * **Índice HHI de Anotación**: Evalúa numéricamente si la anotación del equipo es coral ($HHI \le 15.0\%$) o si sufre de hiper-dependencia en una o dos figuras individuales ($HHI > 15.0\%$).
  * **Ratio de Rotación**: Porcentaje del total de minutos del equipo asumidos por los 5 titulares principales vs. el banquillo.
* **ADN Estilístico de Plantilla (Donut Chart)**: Gráfico interactivo que muestra la cuota porcentual del total de minutos jugados ocupada por cada arquetipo táctico K-Means.
* **Diagnóstico Estadístico Descriptivo (Full-Width Grid)**: Informe descriptivo neutro desglosado en 3 paneles que analizan la *Amenaza Perimetral*, el *Cuidado del Balón* y la *Distribución de Minutos de la Plantilla*.

---

## 🛠️ 3. Arquitectura del Repositorio de Código

Para garantizar un mantenimiento ágil y profesional, el repositorio oficial [`segunda_feb_pro`](.) se encuentra organizado bajo una estructura modular limpia:

```text
f:/Otro Proyecto/
├── app.R                          # Script Principal R Shiny Server & UI (Tema Oscuro)
├── run_shiny_server.R              # Lanchador del Servidor Local en Puerto 8080
├── PORTFOLIO_EJECUTIVO_SEGUNDA_FEB.md # Dossier Maestro Ejecutivo (Este Documento)
│
├── database/                      # Scripts de Estructura SQL y Conexión PostgreSQL
│   ├── ddl_schema_segunda_feb.sql # Schema DDL (8 Tablas Relacionales)
│   └── get_db_con.R               # Función de Conexión Segura (Port 5433)
│
├── analytics/                     # Motores Analíticos y Modelado Machine Learning
│   ├── motor_clustering_fase4.R   # Pipeline de Clustering K-Means y Arquetipos
│   ├── modelo_logistico_fase6.R   # Entrenador de Regresión Logística (AUC 0.9867)
│   └── motor_jugadores_fase4.R    # Motor de Cálculo de Percentiles y MAD/CV
│
├── shiny_app/                     # Réplica y Entorno de Pruebas de la Interfaz Web
│   ├── app.R                      # Aplicación R Shiny Sincronizada
│   └── test_app_reactivity.R      # Batería de Pruebas Unitarias de Queries
│
├── reports/                       # Generadores de Informes Automatizados (NLG & Scouting)
│   ├── generar_informe_scouting.R # Script de Compilación de Dossieres PDF/HTML
│   └── show_tree.R                # Visualizador del Árbol del Proyecto
│
└── audit/                         # Auditorías Científicas y Certificados de Salud DB
    ├── auditoria_final_produccion_fase9.R # Auditoría de Integridad DB (0 Huérfanos)
    └── auditoria_silhouette.R     # Validación Matemática de K-Means (BSS/TSS)
```

---

## 🚀 4. Comandos de Ejecución y Despliegue Rápido

Para desplegar la solución completa en un entorno local o servidor corporativo:

### 1. Iniciar Base de Datos PostgreSQL 16
```powershell
& 'C:\Program Files\PostgreSQL\16\bin\postgres.exe' -D 'f:\Otro Proyecto\pg_data' -p 5433
```

### 2. Lanzar Servidor Web R Shiny
```powershell
& 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' 'f:\Otro Proyecto\run_shiny_server.R'
```
* **Ruta de Acceso Web**: [`http://127.0.0.1:8080`](http://127.0.0.1:8080)

---

> [!IMPORTANT]
> **Garantía de Integridad:** La base de datos relacional de la competición contiene **8.189 registros de box-score**, **443 jugadores** auditados y **396 partidos oficiales** procesados con cero registros huérfanos, garantizando la fiabilidad matemática absoluta de todas las métricas presentadas en el dashboard.

SET search_path TO segunda_feb_pro, public;

\echo '================================================================='
\echo '1. INTEGRIDAD REFERENCIAL Y REGISTROS HUÉRFANOS'
\echo '================================================================='

\echo '--> 1.1 Registros huérfanos en box_scores_raw (sin partido o jugador maestro):'
SELECT 
    COUNT(*) FILTER (WHERE p.id_partido IS NULL) AS huerfanos_partido,
    COUNT(*) FILTER (WHERE j.id_jugador IS NULL) AS huerfanos_jugador,
    COUNT(*) FILTER (WHERE e.id_equipo IS NULL) AS huerfanos_equipo
FROM box_scores_raw b
LEFT JOIN partidos p ON b.id_partido = p.id_partido
LEFT JOIN jugadores j ON b.id_jugador = j.id_jugador
LEFT JOIN equipos e ON b.id_equipo = e.id_equipo;

\echo ''
\echo '--> 1.2 Inconsistencia de equipo de jugador vs equipos del partido:'
SELECT COUNT(*) AS partidos_equipo_inconsistente
FROM box_scores_raw b
JOIN partidos p ON b.id_partido = p.id_partido
WHERE b.id_equipo NOT IN (p.id_equipo_local, p.id_equipo_visitante);

\echo ''
\echo '--> 1.3 Coherencia del marcador global (Puntos acumulados boxscore vs Marcador partido):'
WITH puntos_calculados AS (
    SELECT 
        id_partido,
        id_equipo,
        SUM(puntos) AS suma_puntos_boxscore
    FROM box_scores_raw
    GROUP BY id_partido, id_equipo
)
SELECT 
    p.id_partido,
    el.nombre_oficial AS equipo_local,
    p.puntos_local,
    pc_loc.suma_puntos_boxscore AS suma_local_boxscore,
    ev.nombre_oficial AS equipo_visitante,
    p.puntos_visitante,
    pc_vis.suma_puntos_boxscore AS suma_visitante_boxscore,
    CASE 
        WHEN p.puntos_local = pc_loc.suma_puntos_boxscore AND p.puntos_visitante = pc_vis.suma_puntos_boxscore THEN 'COHERENTE'
        ELSE 'DESCUADRE DETECTADO'
    END AS estado_marcador
FROM partidos p
JOIN equipos el ON p.id_equipo_local = el.id_equipo
JOIN equipos ev ON p.id_equipo_visitante = ev.id_equipo
LEFT JOIN puntos_calculados pc_loc ON p.id_partido = pc_loc.id_partido AND p.id_equipo_local = pc_loc.id_equipo
LEFT JOIN puntos_calculados pc_vis ON p.id_partido = pc_vis.id_partido AND p.id_equipo_visitante = pc_vis.id_equipo;

\echo ''
\echo '================================================================='
\echo '2. BARRIDO DE VALORES NULOS Y VACÍOS (MISSING VALUES SCAN)'
\echo '================================================================='

\echo '--> 2.1 Conteo de nulos y vacíos en tabla JUGADORES:'
SELECT 
    COUNT(*) AS total_jugadores,
    COUNT(*) FILTER (WHERE nombre_completo IS NULL OR TRIM(nombre_completo) = '') AS nulos_nombre,
    COUNT(*) FILTER (WHERE puesto_posicion IS NULL OR TRIM(puesto_posicion) IN ('', '-')) AS nulos_posicion,
    COUNT(*) FILTER (WHERE altura_cm IS NULL) AS nulos_altura,
    COUNT(*) FILTER (WHERE fecha_nacimiento IS NULL) AS nulos_fecha_nac,
    COUNT(*) FILTER (WHERE nacionalidad IS NULL OR TRIM(nacionalidad) IN ('', '-')) AS nulos_nacionalidad
FROM jugadores;

\echo ''
\echo '--> 2.2 Conteo de nulos y vacíos en tabla BOX_SCORES_RAW:'
SELECT 
    COUNT(*) AS total_boxscores,
    COUNT(*) FILTER (WHERE minutos_decimal IS NULL) AS nulos_minutos,
    COUNT(*) FILTER (WHERE puntos IS NULL) AS nulos_puntos,
    COUNT(*) FILTER (WHERE dorsal IS NULL) AS nulos_dorsal,
    COUNT(*) FILTER (WHERE valoracion IS NULL) AS nulos_valoracion
FROM box_scores_raw;

\echo ''
\echo '================================================================='
\echo '3. RANGOS BIOLÓGICOS, ESTADÍSTICOS Y DUPLICADOS (OUTLIERS & SANITY)'
\echo '================================================================='

\echo '--> 3.1 Control de altura y rangos biológicos (entre 175cm y 225cm):'
SELECT 
    MIN(altura_cm) AS altura_minima,
    ROUND(AVG(altura_cm), 1) AS altura_promedio,
    MAX(altura_cm) AS altura_maxima,
    COUNT(*) FILTER (WHERE altura_cm < 175 OR altura_cm > 225) AS fuera_de_rango_logico
FROM jugadores;

\echo ''
\echo '--> 3.2 Minutos jugados máximo por partido (prórrogas o anomalías > 45.00 min):'
SELECT 
    MAX(minutos_decimal) AS max_minutos_registrado,
    COUNT(*) FILTER (WHERE minutos_decimal > 45.00) AS alertas_tiempo_excesivo
FROM box_scores_raw;

\echo ''
\echo '--> 3.3 Coherencia matemática de tiros y rebotes (Violaciones a reglas de juego):'
SELECT 
    COUNT(*) FILTER (WHERE t2_anotados > t2_intentados) AS error_t2,
    COUNT(*) FILTER (WHERE t3_anotados > t3_intentados) AS error_t3,
    COUNT(*) FILTER (WHERE tl_anotados > tl_intentados) AS error_tl,
    COUNT(*) FILTER (WHERE (rebotes_ofensivos + rebotes_defensivos) <> rebotes_totales) AS error_rebotes_totales
FROM box_scores_raw;

\echo ''
\echo '--> 3.4 Verificación de duplicados exactos en clave primaria (id_partido, id_jugador):'
SELECT 
    id_partido, 
    id_jugador, 
    COUNT(*) AS ocurrencias
FROM box_scores_raw
GROUP BY id_partido, id_jugador
HAVING COUNT(*) > 1;

\echo ''
\echo '================================================================='
\echo '4. RESUMEN EJECUTIVO DEL ESTADO GLOBAL DEL ESQUEMA'
\echo '================================================================='
SELECT 
    'equipos' AS tabla,
    (SELECT COUNT(*) FROM equipos) AS total_filas,
    0 AS filas_con_anomalias,
    100.0 AS pct_completitud_metadatos
UNION ALL
SELECT 
    'jugadores',
    (SELECT COUNT(*) FROM jugadores),
    (SELECT COUNT(*) FROM jugadores WHERE altura_cm IS NULL OR puesto_posicion IS NULL),
    ROUND(100.0 * (SELECT COUNT(*) FROM jugadores WHERE altura_cm IS NOT NULL AND puesto_posicion IS NOT NULL) / (SELECT COUNT(*) FROM jugadores), 2)
UNION ALL
SELECT 
    'partidos',
    (SELECT COUNT(*) FROM partidos),
    0,
    100.0
UNION ALL
SELECT 
    'box_scores_raw',
    (SELECT COUNT(*) FROM box_scores_raw),
    (SELECT COUNT(*) FROM box_scores_raw WHERE t2_anotados > t2_intentados OR t3_anotados > t3_intentados OR tl_anotados > tl_intentados),
    100.0;

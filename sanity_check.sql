SET search_path TO segunda_feb_pro, public;

\echo '================================================================='
\echo '1. CONTEO DE REGISTROS POR TABLA'
\echo '================================================================='
SELECT 'equipos' AS tabla, COUNT(*) AS total_registros FROM equipos
UNION ALL
SELECT 'jugadores', COUNT(*) FROM jugadores
UNION ALL
SELECT 'partidos', COUNT(*) FROM partidos
UNION ALL
SELECT 'box_scores_raw', COUNT(*) FROM box_scores_raw;

\echo ''
\echo '================================================================='
\echo '2. AUDITORÍA DE TIPOS Y MINUTOS DECIMALES'
\echo '================================================================='
SELECT 
    COUNT(*) AS total_filas,
    COUNT(minutos_decimal) AS filas_con_minutos,
    MIN(minutos_decimal) AS min_minutos,
    ROUND(AVG(minutos_decimal), 2) AS avg_minutos,
    MAX(minutos_decimal) AS max_minutos
FROM box_scores_raw;

\echo ''
\echo '================================================================='
\echo '3. MUESTRA DE INTEGRIDAD RELACIONAL (JOIN TRES TABLAS - 5 FILAS)'
\echo '================================================================='
SELECT 
    j.nombre_completo AS jugador,
    e.nombre_oficial AS equipo,
    j.puesto_posicion AS posicion,
    j.altura_cm AS altura,
    b.minutos_decimal AS minutos,
    b.puntos AS puntos,
    b.t3_anotados || '/' || b.t3_intentados AS t3
FROM box_scores_raw b
JOIN jugadores j ON b.id_jugador = j.id_jugador
JOIN equipos e ON b.id_equipo = e.id_equipo
ORDER BY b.puntos DESC, b.minutos_decimal DESC
LIMIT 5;

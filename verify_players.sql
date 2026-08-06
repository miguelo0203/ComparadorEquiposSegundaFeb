SET search_path TO segunda_feb_pro, public;

SELECT 
    id_jugador,
    nombre_completo,
    puesto_posicion,
    altura_cm,
    nacionalidad,
    fecha_nacimiento
FROM jugadores
ORDER BY id_jugador
LIMIT 15;

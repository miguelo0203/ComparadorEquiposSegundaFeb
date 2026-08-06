SET search_path TO segunda_feb_pro, public;

UPDATE segunda_feb_pro.jugadores 
SET puesto_posicion = NULL 
WHERE TRIM(puesto_posicion) = '' OR puesto_posicion = '-';

UPDATE segunda_feb_pro.jugadores 
SET nacionalidad = NULL 
WHERE TRIM(nacionalidad) = '' OR nacionalidad = '-';

SELECT 
  COUNT(*) AS total_jugadores, 
  COUNT(altura_cm) AS con_altura, 
  COUNT(puesto_posicion) AS con_posicion, 
  ROUND(100.0 * COUNT(altura_cm) / COUNT(*), 2) AS pct_altura, 
  ROUND(100.0 * COUNT(puesto_posicion) / COUNT(*), 2) AS pct_posicion 
FROM segunda_feb_pro.jugadores;

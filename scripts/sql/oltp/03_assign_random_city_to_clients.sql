-- Asigna una ciudad aleatoria a cada cliente que no tenga CIUDADID.
-- Usa una lista en memoria para minimizar lecturas repetitivas sobre CIUDAD.
DECLARE
    TYPE t_city_ids IS TABLE OF CIUDAD.CIUDADID%TYPE;
    l_city_ids t_city_ids;
BEGIN
    SELECT CIUDADID BULK COLLECT INTO l_city_ids FROM CIUDAD;

    IF l_city_ids.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'No hay ciudades cargadas en la tabla CIUDAD.');
    END IF;

    FOR rec IN (SELECT CLIENTEID FROM CLIENTES WHERE CIUDADID IS NULL) LOOP
        UPDATE CLIENTES
        SET CIUDADID = l_city_ids(TRUNC(DBMS_RANDOM.VALUE(1, l_city_ids.COUNT + 1)))
        WHERE CLIENTEID = rec.CLIENTEID;
    END LOOP;

    COMMIT;
END;
/

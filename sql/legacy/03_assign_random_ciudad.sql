-- 03_assign_random_ciudad.sql
-- Asigna aleatoriamente una ciudad a cada cliente existente (PL/SQL)
-- Copia legada para compatibilidad; usa `sql/oltp/03_assign_random_city_to_clients.sql` como versión mantenida y comentada.

BEGIN
  FOR c IN (SELECT CLIENTEID FROM CLIENTES) LOOP
    UPDATE CLIENTES SET CIUDADID = (
      SELECT CIUDADID FROM (
        SELECT CIUDADID FROM CIUDAD ORDER BY DBMS_RANDOM.VALUE
      ) WHERE ROWNUM = 1
    ) WHERE CLIENTEID = c.CLIENTEID;
  END LOOP;
  COMMIT;
END;
/

-- Nota: si tienes muchos clientes, este bloque puede tardar; se puede paralelizar o optimizar con otro método.

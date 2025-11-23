-- 02_alter_clientes_add_ciudad.sql
-- Agrega columna CIUDADID a CLIENTES y la FK hacia CIUDAD
-- Copia legada para compatibilidad; usa `sql/oltp/02_add_ciudad_to_clientes.sql` como versión mantenida y comentada.

ALTER TABLE CLIENTES ADD (CIUDADID NUMBER(10));

ALTER TABLE CLIENTES ADD (
  CONSTRAINT FK_CLIENTES_CIUDAD FOREIGN KEY (CIUDADID) REFERENCES CIUDAD(CIUDADID)
);

COMMIT;

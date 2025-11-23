-- 01_create_ciudad.sql
-- Crea la tabla CIUDAD en el esquema transaccional y deja lista la PK/autonumeración.
-- Copia legada para compatibilidad; usa `sql/oltp/01_create_ciudad_table.sql` como versión mantenida y comentada.

CREATE TABLE CIUDAD (
    CIUDADID     NUMBER(10)    PRIMARY KEY,
    NOMBRE       VARCHAR2(150) NOT NULL,
    PROVINCIA    VARCHAR2(150),
    LATITUD      NUMBER(9,6),
    LONGITUD     NUMBER(9,6),
    ZONA_HORARIA VARCHAR2(50)
);

CREATE SEQUENCE SEQ_CIUDAD
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE OR REPLACE TRIGGER TRG_CIUDAD_BI
BEFORE INSERT ON CIUDAD
FOR EACH ROW
BEGIN
  IF :NEW.CIUDADID IS NULL THEN
    :NEW.CIUDADID := SEQ_CIUDAD.NEXTVAL;
  END IF;
END;
/

-- Carga sugerida:
-- 1) Genera insert_ciudad.sql con el ETL (etl/download_ciudades.py --source ./data/raw/ciudades/EC.txt)
-- 2) En Oracle, ejecuta:  @./data/output/ciudades/insert_ciudad.sql

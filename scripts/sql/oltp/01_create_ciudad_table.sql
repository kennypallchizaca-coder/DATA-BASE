-- Crea tabla CIUDAD y objetos de soporte. Pensada para Oracle.
-- Ejecutar con privilegios sobre el esquema transaccional (donde viven CLIENTES).
-- Estructura simple para almacenar nombre/provincia y coordenadas de referencia.

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

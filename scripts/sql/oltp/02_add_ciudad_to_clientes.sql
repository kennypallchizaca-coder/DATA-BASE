-- Agrega la columna CIUDADID a CLIENTES y crea la FK hacia CIUDAD de forma idempotente.
-- Usa diccionario de datos para no fallar si se ejecuta mas de una vez.
DECLARE
    v_column_exists     NUMBER;
    v_constraint_exists NUMBER;
    v_table_exists      NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM USER_TABLES
    WHERE TABLE_NAME = 'CLIENTES';

    IF v_table_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'La tabla CLIENTES no existe en este esquema. Conectate con el propietario o crea un sinonimo.');
    END IF;

    SELECT COUNT(*) INTO v_column_exists
    FROM USER_TAB_COLUMNS
    WHERE TABLE_NAME = 'CLIENTES'
      AND COLUMN_NAME = 'CIUDADID';

    IF v_column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE CLIENTES ADD (CIUDADID NUMBER(10))';
    END IF;

    SELECT COUNT(*) INTO v_constraint_exists
    FROM USER_CONSTRAINTS
    WHERE TABLE_NAME = 'CLIENTES'
      AND CONSTRAINT_NAME = 'FK_CLIENTES_CIUDAD';

    IF v_constraint_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE CLIENTES ADD CONSTRAINT FK_CLIENTES_CIUDAD FOREIGN KEY (CIUDADID) REFERENCES CIUDAD(CIUDADID)';
    END IF;
END;
/

CREATE INDEX IDX_CLIENTES_CIUDAD ON CLIENTES (CIUDADID);
/

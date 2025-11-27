-- Verifica que las tablas base existan en el esquema actual.
-- Evita fallos silenciosos si te conectas con un usuario sin CLIENTES/ORDENES/PRODUCTOS.
DECLARE
    v_missing VARCHAR2(4000);
BEGIN
    FOR t IN (
        SELECT 'CLIENTES' AS tbl FROM dual UNION ALL
        SELECT 'PRODUCTOS' FROM dual UNION ALL
        SELECT 'ORDENES' FROM dual UNION ALL
        SELECT 'DETALLE_ORDENES' FROM dual UNION ALL
        SELECT 'TBL_CANTON' FROM dual UNION ALL
        SELECT 'TBL_PARROQUIA' FROM dual
    ) LOOP
        DECLARE v_cnt NUMBER; BEGIN
            SELECT COUNT(*) INTO v_cnt FROM USER_TABLES WHERE TABLE_NAME = t.tbl;
            IF v_cnt = 0 THEN
                v_missing := v_missing || t.tbl || ', ';
            END IF;
        END;
    END LOOP;

    IF v_missing IS NOT NULL THEN
        v_missing := RTRIM(v_missing, ', ');
        RAISE_APPLICATION_ERROR(
            -20050,
            'Faltan tablas base en este esquema: ' || v_missing ||
            '. Conectate al esquema propietario o crea sinonimos.'
        );
    END IF;
END;
/

-- Plan de ejecucion para construir OLTP enriquecido + DW
SET DEFINE OFF;
SET ECHO ON;
SET FEEDBACK ON;
SET SERVEROUTPUT ON;
WHENEVER SQLERROR CONTINUE;
-- Si las tablas base estan en otro esquema, descomenta y ajusta:
-- ALTER SESSION SET CURRENT_SCHEMA=ESQUEMAORIGINAL;
@scripts/sql/oltp/00_create_base_tables.sql
@scripts/sql/oltp/00_require_base_tables.sql
@scripts/sql/oltp/05_seed_transactional_data.sql
@scripts/sql/oltp/01_create_ciudad_table.sql
@data/output/ciudades/insert_ciudad.sql
@scripts/sql/oltp/02_add_ciudad_to_clientes.sql
@scripts/sql/oltp/03_assign_random_city_to_clients.sql
@scripts/sql/oltp/04_create_province_canton_parish_tables.sql
@scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql
@scripts/sql/etl/load_dw_from_oltp.sql

PROMPT ===== Verificacion rapida =====;
PROMPT Conteo de ciudades en CIUDAD:;
SELECT COUNT(*) AS TOTAL_CIUDADES FROM CIUDAD;
PROMPT Ejemplo de 5 ciudades:
SELECT CIUDADID, NOMBRE, PROVINCIA FROM CIUDAD WHERE ROWNUM <= 5;
PROMPT Conteo en DW_DIM_UBICACION:
SELECT COUNT(*) AS TOTAL_DIM_UBICACION FROM DW_DIM_UBICACION;
PROMPT Top producto mas vendido (si hay datos):
SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 5;
SPOOL OFF;

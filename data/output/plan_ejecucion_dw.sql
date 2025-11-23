-- Plan generado automáticamente por run_full_etl_pipeline.py
-- Ejecuta este archivo en SQL*Plus/SQLcl desde la raíz del repo.

@scripts/sql/oltp/01_create_ciudad_table.sql
@scripts/sql/oltp/02_add_ciudad_to_clientes.sql
@scripts/sql/oltp/03_assign_random_city_to_clients.sql
@scripts/sql/oltp/04_create_province_canton_parish_tables.sql
@scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql
@scripts/sql/etl/load_dw_from_oltp.sql

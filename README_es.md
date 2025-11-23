Guia rapida: ETL y DW con ubicacion (Ecuador)

Que hace el proyecto
- Amplia el esquema de pedidos con ubicacion (tabla CIUDAD y FK en CLIENTES).
- Crea un DW estrella con dimensiones Tiempo, Categoria, Producto y Ubicacion (provincia + ciudad) y hecho DW_FACT_VENTAS.
- Incluye vista `VW_MAS_VENDIDO` para obtener el producto mas vendido por fecha/categoria/provincia/ciudad.
- El plan `data/output/plan_ejecucion_dw.sql` ejecuta todo en Oracle; no cierra la sesion aunque haya errores (`WHENEVER SQLERROR CONTINUE`).
- Los scripts SQL y Python estan comentados para seguir la logica sin depender de este README.

Estructura de carpetas (que hace cada una)
- data/raw/ciudades/: insumos GeoNames (EC.zip/EC.txt y admin1CodesASCII.txt) usados para generar el catalogo de ciudades.
- data/raw/jerarquia/: espacio para CSVs de provincias/cantones/parroquias si los extraes del PDF oficial.
- data/Datos-Geograficos-Ecuador/: PDF de referencia del censo 2016 (listado prov-cantones-parroquias).
- data/output/ciudades/: salidas generadas de ciudades (`ciudades_ec.csv`, `insert_ciudad.sql`).
- data/output/plan_ejecucion_dw.sql: plan unico para correr todo el pipeline; genera log en `data/output/plan_ejecucion_dw.log`.
- scripts/sql/oltp/: DDL/PLSQL para CIUDAD, FK en CLIENTES, asignacion aleatoria de ciudad y jerarquia PROVINCIAS/CANTONES/PARROQUIAS.
- scripts/sql/dw/: esquema estrella del DW y vista `VW_MAS_VENDIDO`.
- scripts/sql/etl/: carga de dimensiones y hechos desde las tablas transaccionales.
- scripts/python/: utilidades para generar el catalogo de ciudades y construir el plan SQL.
- EsquemaOriginal/TABLA-ORIGINAL.sql: referencia del modelo previo sin ubicacion (no se ejecuta por defecto).

Detalle de scripts SQL (OLTP)
- 00_require_base_tables.sql: valida que existan CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES en el esquema actual.
- 01_create_ciudad_table.sql: crea CIUDAD (CIUDADID PK, nombre, provincia, lat/long, zona_horaria) con secuencia y trigger.
- 02_add_ciudad_to_clientes.sql: agrega CIUDADID a CLIENTES, FK `FK_CLIENTES_CIUDAD` e indice.
- 03_assign_random_city_to_clients.sql: bloque PL/SQL que asigna una CIUDADID aleatoria a clientes sin valor.
- 04_create_province_canton_parish_tables.sql: crea PROVINCIAS, CANTONES y PARROQUIAS con PK/FK y triggers de secuencia.

Detalle de scripts SQL (DW/ETL)
- dw/01_dw_star_schema_and_top_product_view.sql: crea dimensiones Tiempo/Categoria/Producto/Ubicacion, hecho DW_FACT_VENTAS y vista `VW_MAS_VENDIDO`.
- etl/load_dw_from_oltp.sql: MERGE de dimensiones (incluye fila DESCONOCIDA para ubicacion) y carga del hecho considerando descuentos; usa provincia desde CIUDAD y enlaza a PROVINCIAS cuando coincide el nombre.

Python (comentado en el codigo)
- download_ecuador_cities.py: descarga/parsing GeoNames EC.zip, filtra feature class P, deduplica y genera CSV + INSERTs para CIUDAD.
- run_full_etl_pipeline.py: arma el plan `data/output/plan_ejecucion_dw.sql` y, salvo que uses `--skip-cities`, regenera el catalogo de ciudades.

Ejecucion end-to-end
1) Generar catalogo de ciudades (sin dependencias extra):
   python .\scripts\python\download_ecuador_cities.py
   # O usando una fuente local:
   python .\scripts\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt

2) Regenerar el plan (opcional si ya existe):
   python .\scripts\python\run_full_etl_pipeline.py
   # Para no regenerar ciudades:
   python .\scripts\python\run_full_etl_pipeline.py --skip-cities

3) Ejecutar en Oracle (SQL*Plus/SQLcl) desde la raiz del repo:
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   El plan crea CIUDAD, carga ciudades, agrega FK/ciudad a CLIENTES, construye provincias/cantones/parroquias, despliega el DW y corre el ETL. El log queda en `data/output/plan_ejecucion_dw.log`.

Consultas utiles
- Producto mas vendido por dia/categoria/provincia/ciudad:
  SELECT fecha, categoria, provincia, ciudad, producto, total_vendido FROM VW_MAS_VENDIDO;

Notas rapidas
- Si tus tablas base estan en otro esquema, descomenta `ALTER SESSION SET CURRENT_SCHEMA=...` en el plan.
- Usa ASCII en nombres de columnas (Anio, Categoria) para evitar problemas de codificacion.
- Los comentarios en los scripts explican cada paso (triggers, MERGE, calculos de descuento, etc.).

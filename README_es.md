Informe: OLTP + DW con ubicacion (Ecuador)

Proposito
- Ampliar el esquema de pedidos con ubicacion (tabla CIUDAD y FK en CLIENTES) y crear un Data Warehouse en estrella con dimensiones Tiempo, Categoria, Producto y Ubicacion (provincia + ciudad).
- Exponer la vista `VW_MAS_VENDIDO` para obtener el producto mas vendido por fecha/categoria/provincia/ciudad.
- Orquestar todo en un solo plan SQL (`data/output/plan_ejecucion_dw.sql`) ejecutable en Oracle, con log en `data/output/plan_ejecucion_dw.log`.

Flujo de alto nivel (pipeline)
1) Validar que existan las tablas base de pedidos (CLIENTES, PRODUCTOS, ORDENES, DETALLE_ORDENES).
2) Crear la tabla CIUDAD (con secuencia y trigger) y cargar el catalogo de ciudades de Ecuador desde GeoNames.
3) Agregar columna CIUDADID a CLIENTES, crear la FK y asignar una ciudad aleatoria a clientes sin valor.
4) Crear la jerarquia geografica PROVINCIAS, CANTONES, PARROQUIAS (vacia hasta que cargues datos externos).
5) Crear el esquema estrella del DW y la vista `VW_MAS_VENDIDO`.
6) Ejecutar ETL: poblar dimensiones (incluyendo fila DESCONOCIDA en ubicacion) y el hecho DW_FACT_VENTAS (considera descuentos).

Estructura de carpetas (que hace cada una)
- data/raw/ciudades/: insumos de GeoNames (EC.zip/EC.txt y admin1CodesASCII.txt) para generar el catalogo de ciudades.
- data/raw/jerarquia/: espacio para CSVs de provincias/cantones/parroquias si los extraes del PDF oficial.
- data/Datos-Geograficos-Ecuador/: PDF de referencia del censo 2016 (listado prov-cantones-parroquias).
- data/output/ciudades/: salidas generadas de ciudades (`ciudades_ec.csv`, `insert_ciudad.sql`).
- data/output/plan_ejecucion_dw.sql: plan unico que encadena todos los scripts; deja el log en `data/output/plan_ejecucion_dw.log`.
- scripts/sql/oltp/: DDL/PLSQL para CIUDAD, FK en CLIENTES, asignacion aleatoria y jerarquia PROVINCIAS/CANTONES/PARROQUIAS.
- scripts/sql/dw/: esquema estrella y vista `VW_MAS_VENDIDO`.
- scripts/sql/etl/: carga de dimensiones y hechos desde el modelo transaccional.
- scripts/python/: utilidades para generar el catalogo de ciudades y construir el plan SQL.
- EsquemaOriginal/TABLA-ORIGINAL.sql: referencia del modelo previo sin ubicacion (no se ejecuta en el plan por defecto).

Detalle de scripts SQL (OLTP)
- 00_create_base_tables.sql: crea CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES con columnas mínimas si no existen, para poder ejecutar el plan sin un esquema previo.
- 00_require_base_tables.sql: valida que existan CLIENTES, PRODUCTOS, ORDENES, DETALLE_ORDENES en el esquema actual.
- 01_create_ciudad_table.sql: crea CIUDAD (CIUDADID PK, nombre, provincia, lat/long, zona_horaria) con secuencia y trigger que autoincrementa.
- 02_add_ciudad_to_clientes.sql: agrega CIUDADID a CLIENTES, crea FK `FK_CLIENTES_CIUDAD` e indice. Idempotente.
- 03_assign_random_city_to_clients.sql: bloque PL/SQL que asigna una CIUDADID aleatoria a clientes sin valor (usa DBMS_RANDOM y lista en memoria).
- 04_create_province_canton_parish_tables.sql: crea PROVINCIAS, CANTONES, PARROQUIAS con PK/FK, secuencias y triggers de autoincremento.
- 05_seed_transactional_data.sql: llena CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES con datos de ejemplo (30+ filas en detalle) solo cuando las tablas están vacias.

Detalle de scripts SQL (DW/ETL)
- dw/01_dw_star_schema_and_top_product_view.sql: crea dimensiones Tiempo, Categoria, Producto, Ubicacion; hecho DW_FACT_VENTAS; vista `VW_MAS_VENDIDO` (top producto por fecha/categoria/provincia/ciudad).
- etl/load_dw_from_oltp.sql: MERGE de dimensiones (incluye fila DESCONOCIDA para ubicacion) y carga del hecho con descuentos; toma provincia desde CIUDAD y enlaza a PROVINCIAS si coincide el nombre. Deja FK no nulas en el hecho.

Scripts Python (comentados en codigo)
- download_ecuador_cities.py: descarga/parsing GeoNames EC.zip, filtra feature class P, deduplica y genera CSV + INSERTs para CIUDAD.
- run_full_etl_pipeline.py: arma el plan `data/output/plan_ejecucion_dw.sql` y, salvo que uses `--skip-cities`, regenera el catalogo de ciudades. El plan usa `WHENEVER SQLERROR CONTINUE` para no cerrar la sesion al primer error.

Plan unico de ejecucion
- Ruta: `data/output/plan_ejecucion_dw.sql`.
- Orden: valida base -> crea CIUDAD -> carga ciudades -> agrega FK y asigna ciudad a clientes -> crea jerarquia geografica -> crea DW + vista -> ejecuta ETL -> consultas de verificacion.
- Personalizacion: si tus tablas base estan en otro esquema, descomenta y ajusta `ALTER SESSION SET CURRENT_SCHEMA=...` al inicio del plan. Si ya tienes las tablas base, no se recrean (TABLA-ORIGINAL no se llama por defecto).

Pasos para usar la aplicación
1) Genera el catálogo de ciudades si `data/output/ciudades/insert_ciudad.sql` no existe o está desactualizado:
   ```
   python .\scripts\python\download_ecuador_cities.py
   ```
   Opcionalmente carga desde un archivo local ya descargado:
   ```
   python .\scripts\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt
   ```
2) Si modificaste scripts o quieres regenerar el plan completo, ejecútalo (usa `--skip-cities` si no quieres volver a generar el catálogo):
   ```
   python .\scripts\python\run_full_etl_pipeline.py
   python .\scripts\python\run_full_etl_pipeline.py --skip-cities
   ```
3) Ejecuta el plan en Oracle (SQL*Plus/SQLcl) desde la raíz del repositorio:
   ```
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   ```
   El log queda en `data/output/plan_ejecucion_dw.log`; la sesión no se cierra aunque haya errores (revisa el log para comprobar cada etapa).

Consultas finales para verificar el cumplimiento del enunciado
- `SELECT COUNT(*) AS total_ciudades FROM CIUDAD;` (≈9827 filas si cargaste GeoNames).
- `SELECT COUNT(*) FROM CLIENTES WHERE CIUDADID IS NULL;` (debe ser 0 tras la asignación aleatoria).
- `SELECT ci.CIUDADID, ci.NOMBRE, ci.PROVINCIA FROM CLIENTES cl JOIN CIUDAD ci ON cl.CIUDADID = ci.CIUDADID WHERE ROWNUM <= 5;` (asegura que cada cliente apunta a una ciudad).
- `SELECT COUNT(*) FROM PROVINCIAS;`, `SELECT COUNT(*) FROM CANTONES;`, `SELECT COUNT(*) FROM PARROQUIAS;` (las tablas están listas para cargar datos jerárquicos, puedes traerlos desde `data/raw/jerarquia` o el PDF del censo).
- `SELECT COUNT(*) FROM DW_DIM_UBICACION;` (debe sumar una fila adicional con `UbicacionID = 0` para el valor `DESCONOCIDA`).
- `SELECT COUNT(*) FROM DW_FACT_VENTAS;` (espera >0 si el detalle de ordenes se sembró y procesó correctamente).
- `SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 10;` (muestra el producto más vendido por combinación fecha/categoría/provincia/ciudad).
- `SELECT Fecha, Categoria, Provincia, Ciudad, Producto, Total_Vendido FROM VW_MAS_VENDIDO WHERE Fecha >= DATE '2024-01-01' AND Categoria IS NOT NULL ORDER BY Fecha, Categoria, Provincia, Ciudad FETCH FIRST 5 ROWS ONLY;` (ejemplo para validar la desagregación por tiempo y ubicación).

Consultas de validacion rapida
- Conteo de ciudades: `SELECT COUNT(*) AS total_ciudades FROM CIUDAD;` (esperado: 9827 si cargaste GeoNames EC).
- Clientes sin ciudad: `SELECT COUNT(*) FROM CLIENTES WHERE CIUDADID IS NULL;` (esperado: 0 tras asignacion).
- Dimension ubicacion: `SELECT COUNT(*) FROM DW_DIM_UBICACION;` (esperado: 9828 incluyendo fila DESCONOCIDA con UbicacionID=0).
- Hecho sin FK nulas: `SELECT COUNT(*) FROM DW_FACT_VENTAS WHERE ProductoID IS NULL OR TiempoID IS NULL OR UbicacionID IS NULL OR CategoriaID IS NULL;` (esperado: 0).
- Vista top producto: `SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 10;` (debera devolver filas si hay ventas cargadas).

Notas y troubleshooting
- Si obtienes ORA-00942 en CLIENTES/PRODUCTOS/ORDENES/DETALLE_ORDENES, cambia el schema con `ALTER SESSION SET CURRENT_SCHEMA=...` o crea sinonimos a las tablas base.
- Si las dimensiones Producto/Categoria/Tiempo quedan en 0, verifica que existan datos en PRODUCTOS y ORDENES/DETALLE_ORDENES y vuelve a correr el plan.
- Para reinicializar CIUDAD, puedes reejecutar `insert_ciudad.sql` (incluye DELETE + INSERTs).

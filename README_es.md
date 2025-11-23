Guia rapida: ETL y DW con ubicacion (Ecuador)

Checklist de requerimientos
- Tabla CIUDAD agregada al esquema de pedidos con CIUDADID como PK y nombre/provincia/coord. Script: `scripts/sql/oltp/01_create_ciudad_table.sql`.
- CIUDAD se carga con la lista de Ecuador generada desde la carpeta data/raw/ciudades (GeoNames EC.zip) → `data/output/ciudades/insert_ciudad.sql`.
- CLIENTES enlazado a CIUDAD y poblado con una ciudad aleatoria (`scripts/sql/oltp/02_add_ciudad_to_clientes.sql` y `03_assign_random_city_to_clients.sql`).
- Hecho para top producto por tiempo/categoria/ubicacion (provincia+ciudad) en el DW y vista `VW_MAS_VENDIDO` (`scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql`).
- Esquema geografico de 3 tablas (PROVINCIAS, CANTONES, PARROQUIAS) basado en el PDF del censo en `data/Datos-Geograficos-Ecuador/` (`scripts/sql/oltp/04_create_province_canton_parish_tables.sql`).
- Proceso ETL que alimenta dimensiones y hecho usando el esquema transaccional (`scripts/sql/etl/load_dw_from_oltp.sql`).

Estructura de carpetas (lista de trabajo)
- data/
  - raw/ciudades/: fuentes GeoNames (EC.zip, admin1CodesASCII.txt). Coloca aqui cualquier EC.txt/zip local.
  - raw/jerarquia/: espacio para CSVs del censo (provincias/cantones/parroquias) antes de cargarlos.
  - Datos-Geograficos-Ecuador/: PDF oficial `CENSO_2016_TTHH_Listado_prov-cantones-parroquias.pdf`.
  - output/ciudades/: resultados del ETL de ciudades (`ciudades_ec.csv`, `insert_ciudad.sql`).
  - output/plan_ejecucion_dw.sql: plan que encadena todos los scripts SQL.
- scripts/sql/oltp/: DDL para CIUDAD, FK en CLIENTES, asignacion aleatoria y jerarquia provincias-cantones-parroquias.
- scripts/sql/dw/: Esquema estrella (dimensiones Tiempo, Categoria, Producto, Ubicacion) y vista VW_MAS_VENDIDO.
- scripts/sql/etl/: Carga dimensional y de hechos desde las tablas transaccionales.
- scripts/python/: Generacion de catalogo de ciudades y creador de plan de ejecucion.
- EsquemaOriginal/TABLA-ORIGINAL.sql: esquema inicial de referencia previo a la ampliacion de ubicacion.

Pasos recomendados
1) Generar catalogo de ciudades (usa GeoNames EC.zip; no necesita librerias externas):
   pwsh
   python .\scripts\python\download_ecuador_cities.py
   # Si ya tienes un EC.txt/EC.zip local:
   python .\scripts\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt

2) Construir plan completo (crea data/output/plan_ejecucion_dw.sql):
   pwsh
   python .\scripts\python\run_full_etl_pipeline.py
   # Saltar regenerar ciudades:
   python .\scripts\python\run_full_etl_pipeline.py --skip-cities

3) Ejecutar en Oracle (SQL*Plus/SQLcl) desde la raiz del repo:
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   El plan incluye, en orden: crear CIUDAD, agregar FK en CLIENTES, asignar ciudades a clientes, crear provincias/cantones/parroquias, desplegar el DW y correr el ETL.

Paso a paso (ejecucion funcional end-to-end)
1) Preparar dependencias: solo Python 3; opcional `requests` para descarga TLS (`python -m pip install --user requests`).
2) Generar ciudades (GeoNames): `python .\scripts\python\download_ecuador_cities.py` → crea `data/output/ciudades/ciudades_ec.csv` e `insert_ciudad.sql`. Con fuente local: `python .\scripts\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt`.
3) Crear plan SQL (orden de ejecucion): `python .\scripts\python\run_full_etl_pipeline.py` → genera `data/output/plan_ejecucion_dw.sql`.
4) Cargar jerarquia prov/canton/parroquia: convierte `data/Datos-Geograficos-Ecuador/CENSO_2016_TTHH_Listado_prov-cantones-parroquias.pdf` a CSV y carga en `PROVINCIAS`, `CANTONES`, `PARROQUIAS` (SQL*Loader o INSERT masivo) antes de correr el ETL para enlazar ubicacion completa.
5) Ejecutar en Oracle con VS Code (SQLTools/Oracle Driver): crea conexion a `localhost:1521`, servicio `XEPDB1`, usuario/clave del esquema dueño de CLIENTES/ORDENES/PRODUCTOS/DETALLE_ORDENES. Abre un editor SQL y ejecuta `@data/output/plan_ejecucion_dw.sql`. El plan crea el esquema base (`EsquemaOriginal/TABLA-ORIGINAL.sql`), valida que las tablas existan, carga ciudades (`@data/output/ciudades/insert_ciudad.sql`), asigna ciudades a clientes, y genera log en `data/output/plan_ejecucion_dw.log`.
6) Validar: revisa el log `data/output/plan_ejecucion_dw.log` y corre `SELECT fecha, categoria, provincia, ciudad, producto, total_vendido FROM VW_MAS_VENDIDO FETCH FIRST 20 ROWS ONLY;`. Si falta ubicacion, verifica que CLIENTES tenga CIUDADID y que `DW_DIM_UBICACION` no este vacia (fuera de la fila DESCONOCIDA).
Tip: si tus tablas base estan en otro esquema, antes de ejecutar el plan activa el esquema con `ALTER SESSION SET CURRENT_SCHEMA=ESQUEMAORIGINAL;` (o crea sinonimos). El plan trae el comentario para descomentar esa linea.

Detalle de scripts SQL (OLTP)
- 01_create_ciudad_table.sql: crea CIUDAD (ciudadid, nombre, provincia, latitud, longitud, zona_horaria) con secuencia y trigger.
- 02_add_ciudad_to_clientes.sql: agrega CIUDADID a CLIENTES y FK FK_CLIENTES_CIUDAD.
- 03_assign_random_city_to_clients.sql: bloque PL/SQL que asigna CIUDADID aleatoria a clientes sin valor.
- 04_create_province_canton_parish_tables.sql: tablas PROVINCIAS, CANTONES y PARROQUIAS con triggers y secuencias.
- base_transactional_schema_reference.sql: referencia del esquema inicial Dim_Producto, Dim_Tiempo, Dim_Pedidos y Fact_Ventas basado en PRODUCTOS/ORDENES/DETALLE_ORDENES.

Detalle de scripts SQL (DW/ETL)
- dw/01_dw_star_schema_and_top_product_view.sql: crea las dimensiones Tiempo, Categoria, Producto, Ubicacion; tabla de hechos DW_FACT_VENTAS; vista VW_MAS_VENDIDO para el producto top por fecha/categoria/ubicacion.
- etl/load_dw_from_oltp.sql: carga dimensiones (incluye fila DESCONOCIDA en ubicacion) y alimenta DW_FACT_VENTAS usando ORDENES, DETALLE_ORDENES, PRODUCTOS, CLIENTES y CIUDAD; calcula MontoTotal considerando DESCUENTO.

Python
- download_ecuador_cities.py: descarga/parsing de GeoNames EC.zip, deduplica ciudades (feature class P), genera CSV e INSERTs listos para CIUDAD.
- run_full_etl_pipeline.py: orquesta la generacion de ciudades y arma el plan_ejecucion_dw.sql que encadena todos los scripts.

Consultas utiles
- Producto mas vendido por dia/categoria/provincia/ciudad:
  SELECT fecha, categoria, provincia, ciudad, producto, total_vendido FROM VW_MAS_VENDIDO;

Notas
- Usa ASCII en nombres de columnas (Anio, Categoria) para evitar problemas de codificacion.
- Las tablas PROVINCIAS/CANTONES/PARROQUIAS pueden poblarse a partir del PDF CENSO_2016_TTHH_Listado_prov-cantones-parroquias.pdf (data/Datos-Geograficos-Ecuador/). Convierte a CSV/INSERTs respetando los codigos y ejecuta con SQL*Loader o INSERT masivo antes del ETL.
- Si tu modelo transaccional cambia nombres de columnas (p. ej. PRECIOUNIT), ajusta los scripts ETL en consecuencia.

Conexion y ejecucion desde VS Code (SQLTools / Oracle)
- Plugin: instala "SQLTools" y "SQLTools Oracle Driver". Crea una conexion con estos datos (ajusta usuario/clave a los tuyos):
  - Hostname: localhost
  - Port: 1521
  - Type: Service Name
  - Service Name: XEPDB1
  - Username: tu_usuario (ej. alexis2)
  - Password: tu_clave
- Guarda la conexion, abre un editor SQL y ejecuta:
  @data/output/plan_ejecucion_dw.sql
- Si prefieres CLI: `sqlplus usuario/clave@localhost:1521/XEPDB1 @data/output/plan_ejecucion_dw.sql`.

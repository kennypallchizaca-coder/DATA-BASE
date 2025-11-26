# Informe operativo detallado

## 1. ¿Qué hace esta aplicación?
Este proyecto reconstruye un ecosistema transaccional completo y lo transforma en un data warehouse listo para análisis. La capa OLTP incluye tablas de clientes, productos, órdenes y detalles más un módulo de ubicación (ciudades y jerarquía oficial). A partir de esos datos, el pipeline crea un esquema estrella (dimensiones de tiempo, categoría, producto y ubicación más la tabla de hechos) y genera la vista `VW_MAS_VENDIDO` que identifica el producto más vendido por fecha, categoría, provincia y ciudad.

El punto central es `scripts/python/run_full_etl_pipeline.py`: descarga catálogos de GeoNames, reconstruye la jerarquía desde `data/Datos-Geograficos-Ecuador`, genera `data/output/plan_ejecucion_dw.sql` y deja todo listo para ejecutarse con `sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql`.

## 2. Flujo completo de ejecución

1. **Descarga y normalización de datos geográficos**:
   - `scripts/python/ciudades/download_ecuador_cities.py` baja (o usa los archivos locales) los dumps de GeoNames (`EC.txt`, `EC.zip`, `admin1CodesASCII.txt`) y genera el catálogo `data/output/ciudades/insert_ciudad.sql`.
   - `scripts/python/jerarquia/build_jerarquia_csv.py` parsea los dumps SQL en `data/Datos-Geograficos-Ecuador/` y crea `data/raw/jerarquia/provincias.csv`, `cantones.csv`, `parroquias.csv`.
   - `scripts/python/jerarquia/generate_jerarquia_inserts.py` consume los CSV y produce `data/output/jerarquia/insert_jerarquia.sql` con DELETE + INSERT idempotente y realineamiento de secuencias.

2. **Plan maestro**:
   - `scripts/python/run_full_etl_pipeline.py` asegura que los catálogos existen (u omite con `--skip-*`), reconstruye la jerarquía si es necesario, y escribe `data/output/plan_ejecucion_dw.sql`.
   - El plan ordena los scripts: crea tablas base, valida su existencia, carga datos semilla humanos, crea CIUDAD y la jerarquía, ejecuta las cargas DW y ETL, e imprime prompts para verificación (`SELECT COUNT(*)` en `CIUDAD` y `DW_DIM_UBICACION`, más `VW_MAS_VENDIDO`).

3. **Ejecución en Oracle**:
   ```sql
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   ```
   El plan garantiza que cada bloque solo se ejecuta si la tabla está vacía, por lo que puedes reordenar o repetir la ejecución sin duplicar datos.

## 3. Componentes fundamentales y qué hace cada archivo

### 3.1 `data/`

- `data/raw/ciudades/`: contiene `admin1CodesASCII.txt` y `EC.zip` (GeoNames) que sirven como fuentes originales.
- `data/raw/jerarquia/`: almacena los CSV generados por `build_jerarquia_csv.py`.
- `data/output/ciudades/insert_ciudad.sql`: INSERTs de ciudades listos para ejecutarse. Se reemplazan cada vez que se regeneran las ciudades.
- `data/output/jerarquia/insert_jerarquia.sql`: limpia e inserta provincias/cantones/parroquias, recronfigura secuencias y mantiene la jerarquía oficial alineada.
- `data/output/plan_ejecucion_dw.sql`: plan maestro generado por `run_full_etl_pipeline.py`. Incluye `WHENEVER SQLERROR CONTINUE`, prompts finales y referencia a cada script OLTP/DW/ETL.
- `data/Datos-Geograficos-Ecuador/`: dumps originales (provincias.sql, cantones.sql, parroquias.sql) que semanticamente definen la jerarquía. Se leen desde `build_jerarquia_csv.py`.

### 3.2 `scripts/python/`

- `run_full_etl_pipeline.py`: orquesta todo. Argumentos clave:
  - `--skip-cities`: mantiene el archivo de ciudades existente y no vuelve a descargar GeoNames.
  - `--skip-jerarquia-csv`: utiliza los CSV jerárquicos actuales sin volver a generarlos.
  - `--source` / `--jerarquia-source`: apuntan a archivos locales para evitar descargas.
  - Imprime métricas finales (cantidad de ciudades, provincias, cantones, parroquias).
- `ciudades/download_ecuador_cities.py`: descarga GeoNames (o usa `--source`), filtra filas para Ecuador, crea CSV y `insert_ciudad.sql`, y responde si ya existen los archivos.
- `jerarquia/build_jerarquia_csv.py`: lee los dumps SQL formateando los `VALUES`, asigna códigos incrementalmente y escribe los CSV que alimentan los inserts.
- `jerarquia/generate_jerarquia_inserts.py`: combina CSV en un script con DELETE/INSERT (y ALTER SEQUENCE) para reiniciar la jerarquía manteniendo idempotencia.

### 3.3 `scripts/sql/oltp/`

- `00_create_base_tables.sql`: crea CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES si están ausentes. Incluye PK/FK básicos.
- `00_require_base_tables.sql`: valida que existan las tablas base antes de ejecutar los siguientes pasos; falla si faltan.
- `05_seed_transactional_data.sql`: inserta 30 clientes reales, 30 productos con precios, 30 órdenes en 2024 y 60 líneas de detalle. Utiliza tablas y loops para mantener datos consistentes (mismo precio desde PRODUCTOS).
- `01_create_ciudad_table.sql`: crea CIUDAD, la secuencia `SEQ_CIUDAD` y trigger `TRG_CIUDAD_BI`; la secuencia puede fallar si ya existe, pero CIUDAD se crea siempre.
- `02_add_ciudad_to_clientes.sql`: agrega la columna `CIUDADID` a CLIENTES y crea el índice necesario.
- `03_assign_random_city_to_clients.sql`: asigna una ciudad existente a cada cliente para poder analizar ubicaciones.
- `04_create_province_canton_parish_tables.sql`: crea PROVINCIAS, CANTONES, PARROQUIAS y secuencias.

### 3.4 `scripts/sql/dw/`

- `01_dw_star_schema_and_top_product_view.sql`: define las dimensiones (TIEMPO, CATEGORIA, PRODUCTO, UBICACION), la tabla de hechos `DW_FACT_VENTAS`, las secuencias necesarias y la vista `VW_MAS_VENDIDO` que usa `ROW_NUMBER()` para reportar el producto más vendido por combinación fecha/categoría/provincia/ciudad.

### 3.5 `scripts/sql/etl/`

- `load_dw_from_oltp.sql`: carga la fila “DESCONOCIDA” en `DW_DIM_UBICACION`, luego realiza `MERGE` para poblar/actualizar:
  - `DW_DIM_TIEMPO`: registra fechas y atributos derivando de `ORDENES`.
  - `DW_DIM_CATEGORIA`: categorías únicas desde `PRODUCTOS`.
  - `DW_DIM_PRODUCTO`: mantiene descripción, precio y FK a categoría.
  - `DW_DIM_UBICACION`: enlaza ciudades con la jerarquía oficial.
  - `DW_FACT_VENTAS`: agrupa por producto/orden/tiempo/ubicación aplicando descuentos y usa las dimensiones anteriores para referenciar (cada `MERGE` evita duplicados).

## 4. Consultas recomendadas para monitoreo

Tras correr el plan, ejecuta las siguientes consultas para verificar consistencia:

```sql
SELECT COUNT(*) AS CLIENTES FROM CLIENTES;
SELECT COUNT(*) AS PRODUCTOS FROM PRODUCTOS;
SELECT COUNT(*) AS ORDENES FROM ORDENES;
SELECT COUNT(*) AS DETALLES FROM DETALLE_ORDENES;
SELECT COUNT(*) AS CIUDADES FROM CIUDAD;
SELECT COUNT(*) AS DIM_UBICACION FROM DW_DIM_UBICACION;
SELECT COUNT(*) AS FACT_VENTAS FROM DW_FACT_VENTAS;
SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 5;
```

Además:

- `SELECT * FROM DW_DIM_TIEMPO ORDER BY FECHA FETCH FIRST 5 ROWS ONLY;`
- `SELECT * FROM DW_DIM_PRODUCTO WHERE ROWNUM <= 5;`
- `SELECT * FROM DW_DIM_CATEGORIA;`
- `SELECT * FROM PROVINCIAS WHERE ROWNUM <= 5;`

Estas consultas confirman que los objetos existen, que hay datos suficientes y que la vista reporta resultados coherentes.

## 5. Resultados esperados

- Al menos 30 filas en `CLIENTES`, `PRODUCTOS`, `ORDENES` y `DETALLE_ORDENES`.
- La tabla `CIUDAD` contiene cientos de filas generadas desde GeoNames (dependiendo del catálogo descargado).
- `DW_DIM_UBICACION` incluye la fila “DESCONOCIDA” (UbicacionID = 0) más las ciudades asignadas.
- `DW_DIM_TIEMPO` contiene fechas únicas de `ORDENES` de 2024 con atributos de año, mes, trimestre y día de semana.
- `DW_DIM_PRODUCTO` mantiene los productos con sus categorías, y `DW_FACT_VENTAS` agrega cantidad y monto total por pedido/ubicación.
- `VW_MAS_VENDIDO` muestra el producto más vendido por día/categoría o provincia/ciudad; se puede filtrar por fecha para análisis.

## 6. Estrategias de mantenimiento

- Para refrescar solo ciudades: `python .\scripts\python\run_full_etl_pipeline.py --skip-jerarquia-csv`.
- Para actualizar jerarquía desde dumps nuevos: reemplaza los archivos en `data/Datos-Geograficos-Ecuador/` y corre `python .\scripts\python\jerarquia\build_jerarquia_csv.py` y luego el pipeline completo.
- Si necesitas adaptar el esquema a otro usuario/esquema, ejecuta `ALTER SESSION SET CURRENT_SCHEMA=...` antes de correr el plan o crea sinónimos.
- Para convertir datos históricos, puedes reemplazar el contenido de `scripts/sql/oltp/05_seed_transactional_data.sql` con instrucciones que importen tus propias CSV (manteniendo la lógica `IF v_count = 0 THEN`).

## 7. Archivo por archivo (resumen rápido)

| Archivo | Función clave |
| --- | --- |
| `scripts/python/run_full_etl_pipeline.py` | Orquesta descargas, jerarquía y plan final. |
| `scripts/python/ciudades/download_ecuador_cities.py` | Descarga/parsea GeoNames y crea `insert_ciudad.sql`. |
| `scripts/python/jerarquia/build_jerarquia_csv.py` | Lee SQL oficiales y produce CSV jerárquicos. |
| `scripts/python/jerarquia/generate_jerarquia_inserts.py` | Une los CSV en un script con DELETE/INSERT y secuencias. |
| `data/output/plan_ejecucion_dw.sql` | Plan maestro que ejecuta OLTP + DW + ETL. |
| `scripts/sql/oltp/00_create_base_tables.sql` | Crea tablas base si faltan. |
| `scripts/sql/oltp/05_seed_transactional_data.sql` | Inserta datos realistas para `CLIENTES`, `PRODUCTOS`, `ORDENES`, `DETALLE_ORDENES`. |
| `scripts/sql/oltp/01_create_ciudad_table.sql` | Crea tabla CIUDAD y trigger. |
| `scripts/sql/oltp/02_add_ciudad_to_clientes.sql` | Agrega columna `CIUDADID`. |
| `scripts/sql/oltp/03_assign_random_city_to_clients.sql` | Imputa ciudad a cada cliente. |
| `scripts/sql/oltp/04_create_province_canton_parish_tables.sql` | Crea tablas geográficas. |
| `data/output/jerarquia/insert_jerarquia.sql` | Inserta jerarquía oficial. |
| `scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql` | Crea dimensiones, hecho y vista `VW_MAS_VENDIDO`. |
| `scripts/sql/etl/load_dw_from_oltp.sql` | Carga las dimensiones y el hecho a partir del OLTP. |

## 8. Advertencias y recomendaciones

- Mantén la carpeta `data/raw` y `data/Datos-Geograficos-Ecuador` actualizadas con los archivos originales para regenerar la jerarquía sin depender de conexiones externas.
- El plan activa `WHENEVER SQLERROR CONTINUE` y no hace rollback automático si hay errores; si necesitas detenerte a la primera excepción, elimina esa línea o controla los errores manualmente.
- Considera incorporar pruebas SQL (por ejemplo, scripts que verifiquen la consistencia de `VW_MAS_VENDIDO`) luego de ejecutar el plan.

Con este informe tienes visibilidad completa de cada componente, qué consultas ejecutar y qué esperar del sistema; sigue estos pasos exactamente para reconstruir el entorno y validar cada capa.

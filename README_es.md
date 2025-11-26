# Informe y manual operativo

## 1. Qué hace el programa
Este proyecto amplía el esquema de pedidos (CLIENTES, PRODUCTOS, ORDENES, DETALLE_ORDENES) con un módulo de ubicación completo (ciudades + jerarquía provincias/cantones/parroquias) y construye un data warehouse en estrella que permite analizar ventas por tiempo, categoría, producto y ubicación. El proceso automatiza:

- La descarga/normalización del catálogo de ciudades (GeoNames) y la creación de `CIUDAD`.
- La extracción de la jerarquía geográfica desde los dumps de `Datos-Geograficos-Ecuador`.
- La creación de tablas geográficas (PROVINCIAS, CANTONES, PARROQUIAS) y del esquema DW (`DW_DIM_TIEMPO`, `DW_DIM_CATEGORIA`, `DW_DIM_PRODUCTO`, `DW_DIM_UBICACION`, `DW_FACT_VENTAS`).
- La vista `VW_MAS_VENDIDO` que reporta el producto más vendido por fecha/categoría/provincia/ciudad.
- El plan maestro (`data/output/plan_ejecucion_dw.sql`) encadena la preparación OLTP y la carga ETL.

El programa se instrumenta a través de `scripts/python/run_full_etl_pipeline.py`, que reconstruye los catálogos, construye el plan SQL y brinda retroalimentación sobre la cantidad de entidades generadas. Su flujo consiste en: validar tablas base ➜ generar ciudades y jerarquía ➜ crear objetos OLTP/DW ➜ ejecutar ETL en la bases de datos.

## 2. Arquitectura de carpetas

### `data/`
- `raw/ciudades/`: datos de GeoNames (`EC.txt`, `EC.zip`, `admin1CodesASCII.txt`). Los utiliza `scripts/python/ciudades/download_ecuador_cities.py` para recrear `ciudades_ec.csv` e `insert_ciudad.sql`.
- `raw/jerarquia/`: CSV actualizados con 25 provincias, 224 cantones y 1399 parroquias. Los genera `scripts/python/jerarquia/build_jerarquia_csv.py` a partir de los dumps SQL.
- `Datos-Geograficos-Ecuador/`: dumps originales (`provincias.sql`, `cantones.sql`, `parroquias.sql`) que sirven como fuente de la jerarquía completa.
- `output/ciudades/`: catálogo listo para insertar en Oracle (`ciudades_ec.csv`, `insert_ciudad.sql`).
- `output/jerarquia/`: script de carga combinado (`insert_jerarquia.sql`) que elimina y vuelve a insertar la jerarquía, realinea secuencias y prepara las tablas.
- `output/plan_ejecucion_dw.sql`: plan maestro con todos los scripts necesarios y consultas de verificación.

- `oltp/`: scripts transaccionales (validación de tablas base, creación de CIUDAD, agregación de FK, jerarquía geográfica y datos semilla).
- `05_seed_transactional_data.sql`: garantiza al menos 50 filas en CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES y debe ejecutarse antes del DW para alimentar dimensiones y el hecho.
- `dw/`: crea el esquema estrella y la vista `VW_MAS_VENDIDO`.
- `etl/`: `load_dw_from_oltp.sql` realiza MERGE de dimensiones y carga de hecho considerando descuentos y ubicaciones desconocidas.

### `scripts/python/`
- `ciudades/download_ecuador_cities.py`: descarga/parses GeoNames y escribe CSV + SQL idempotente.
- `jerarquia/build_jerarquia_csv.py`: parsea los INSERTs de los dumps SQL y construye los CSV necesarios para la jerarquía. Reloadable para actualizaciones futuras.
- `jerarquia/generate_jerarquia_inserts.py`: convierte los CSV (o SQL manuales) en un único script de carga con DELETEs y realineamiento de secuencias.
- `run_full_etl_pipeline.py`: orquesta la regeneración de catálogos, el plan SQL y muestra resultados. Acepta opciones como `--skip-cities`, `--skip-jerarquia-csv`, `--source` y `--jerarquia-source`.

## 3. Manual de operación

### 3.1 Preparación
1. **Fuentes externas**: descargar GeoNames `EC.zip` y `admin1CodesASCII.txt` dentro de `data/raw/ciudades/` (el script los baja automáticamente si no están).
2. **Jerarquía oficial**: mantener `data/Datos-Geograficos-Ecuador` con los archivos SQL originales; no es necesario editarlos.

### 3.2 Generación de catálogos
1. Generar ciudades:
   ```
   python .\scripts\python\ciudades\download_ecuador_cities.py
   ```
   Usa `--source <ruta>` si ya tienes `EC.txt` o `EC.zip` descargado.
2. Generar jerarquía:
   ```
   python .\scripts\python\jerarquia\build_jerarquia_csv.py
   ```
3. Combinar en un plan:
   ```
   python .\scripts\python\run_full_etl_pipeline.py
   python .\scripts\python\run_full_etl_pipeline.py --skip-cities
   ```
   Si los CSV ya están listos, añade `--skip-jerarquia-csv` para ahorrar tiempo.

### 3.3 Ejecución en Oracle
1. Ejecutar el plan:
   ```sql
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   ```
2. Las consultas finales incluidas en el plan permiten verificar rápidamente el número de ciudades, la jerarquía y el top product.

### 3.4 Validación
- `SELECT COUNT(*) AS total_ciudades FROM CIUDAD;`
- `SELECT COUNT(*) FROM CLIENTES WHERE CIUDADID IS NULL;`
- `SELECT COUNT(*) FROM PROVINCIAS;` / `CANTONES` / `PARROQUIAS`.
- `SELECT COUNT(*) FROM DW_DIM_UBICACION;`
- `SELECT COUNT(*) FROM DW_FACT_VENTAS;` y `SELECT SUM(CantidadVendida), SUM(MontoTotal)`.
- `SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 10;`
- Consulta con filtro por fecha/categoría/provincia/ciudad (fecha >= 2024-01-01).

### 3.5 Mantenimiento
- Para regenerar la jerarquía completa, reejecuta `build_jerarquia_csv.py` y luego `run_full_etl_pipeline.py`.
- Para refrescar solo ciudades, ejecuta `download_ecuador_cities.py` y el plan con `--skip-jerarquia-csv`.
- Si modificas la jerarquía manualmente, puedes colocar SQL (`insert_provincias.sql`, `insert_cantones.sql`, `insert_parroquias.sql`) dentro de `data/output/jerarquia/` y el generador los usará directamente.

## 4. Notas y troubleshooting
- Cambia el esquema con `ALTER SESSION SET CURRENT_SCHEMA=...` si recibes ORA-00942 en las tablas base o crea sinónimos.
- El plan usa `WHENEVER SQLERROR CONTINUE` para no detenerse con errores no críticos; revisa la salida o agrega `SPOOL` en Oracle si necesitas un log persistente.
- Si los CSV de jerarquía están vacíos, `generate_jerarquia_inserts.py` crea un archivo con instrucciones para rellenarlos y aborta la carga automática.

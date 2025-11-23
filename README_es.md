Resumen y pasos para implementar ETL y Data Warehouse (Ecuador - ciudades/provincias)

Todos los scripts SQL y el ETL en Python viven ahora en una sola carpeta (`scripts/`) para evitar duplicados y facilitar su ejecución.
Todos los scripts se consolidaron en rutas únicas (`sql/oltp/` y `sql/dw/`) para evitar duplicados y facilitar su ejecución.

Componentes principales
- `data/`: estructura organizada para datos crudos y salidas.
  - `data/raw/ciudades/EC.txt`: padrón de ciudades de Ecuador listo para uso offline.
  - `data/raw/jerarquia/`: PDF del censo y CSVs de provincias/cantones/parroquias que tú proporciones.
  - `data/output/ciudades/`: destino por defecto de los archivos generados por el ETL.
- `scripts/sql/oltp/`: scripts para enriquecer el esquema transaccional con geografía.
  - `01_create_ciudad_table.sql`: DDL independiente para crear `CIUDAD` con su secuencia y trigger.
  - `02_add_ciudad_to_clientes.sql`: agrega `CIUDADID` a `CLIENTES` y crea la FK hacia `CIUDAD`.
  - `03_assign_random_city_to_clients.sql`: bloque PL/SQL que asigna ciudades aleatorias a los clientes existentes.
  - `04_create_province_canton_parish_tables.sql`: tablas jerárquicas `PROVINCIAS`, `CANTONES`, `PARROQUIAS` con sus claves foráneas.
  - `base_transactional_schema_reference.sql`: esquema base de referencia con ejemplos de inserción en dimensiones.
- `scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql`: DDL completo del esquema estrella (tiempo, producto, categoría, ubicación con jerarquía provincia → cantón → parroquia/ciudad), tabla de hechos con medidas y vista `VW_MAS_VENDIDO`.
- `scripts/sql/etl/load_dw_from_oltp.sql`: script ETL en SQL que alimenta las dimensiones (incluyendo el cruce con el censo) y carga la tabla de hechos desde `ORDENES`/`DETALLE_ORDENES`.
- `scripts/python/download_ecuador_cities.py`: ETL ligero para descargar el padrón de ciudades desde carta-natal.es, generar `ciudades_ec.csv` y un archivo de INSERTs para poblar `CIUDAD`. Detecta automáticamente `data/raw/ciudades/EC.txt` si está disponible.
- `scripts/python/run_full_etl_pipeline.py`: envoltorio en Python que genera el catálogo de ciudades y crea un plan `plan_ejecucion_dw.sql` que encadena todos los scripts SQL (OLTP + DW).

### Cómo funciona el código Python (comentado)

- `download_ecuador_cities.py`
  - Función reutilizable `generate_catalog(...)`: recibe el código ISO, rutas de salida y (opcionalmente) un TXT/ZIP local; si no se indica fuente, busca `data/raw/ciudades/<CODE>.txt` y, si no existe, descarga el ZIP oficial y lo decodifica.
  - Normaliza el contenido (detecta delimitadores, encabezados, codificación y coordenadas), lo convierte en objetos `CiudadRow` y exporta tanto a CSV como a un archivo de `INSERT` listo para Oracle.
  - La función `main()` solo parsea argumentos y llama a `generate_catalog`, por lo que otros scripts pueden reutilizar la lógica sin modificarla.
- `run_full_etl_pipeline.py`
  - Usa `generate_catalog` para asegurar que el padrón de ciudades se genere antes de cargar la BD.
  - Construye automáticamente `data/output/plan_ejecucion_dw.sql` con la secuencia recomendada de scripts: crear `CIUDAD`, añadir la FK a `CLIENTES`, asignar ciudades, crear jerarquía geográfica, desplegar el esquema estrella y ejecutar el ETL.
  - No se conecta a la BD: solo deja preparados los artefactos y el plan a ejecutar en SQL*Plus/SQLcl.

Flujo sugerido (ETL → DW)
1. **Descargar y preparar ciudades (fuente carta-natal.es o archivo local)**
   - Requiere Python 3 y el paquete `requests`:

     ```pwsh
     python -m pip install --user requests
     ```

   - Ejecutar el script (genera archivos en `data/output/ciudades/` por defecto):

     ```pwsh
     python .\scripts\python\download_ecuador_cities.py

     # O reutiliza el archivo local EC.txt para evitar descarga (ruta ya incluida por defecto):
     python .\scripts\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt
     ```

   - Parámetros opcionales: `--code` (ISO, default EC), `--csv` y `--sql` para personalizar rutas.
   - Revisa `ciudades_ec.csv` antes de cargar; el script intenta detectar delimitadores y codificaciones, pero conviene validar manualmente.

2. **Crear/popular tabla `CIUDAD`**
   - En tu motor Oracle ejecuta `scripts/sql/oltp/01_create_ciudad_table.sql` o el bloque equivalente en `scripts/sql/oltp/base_transactional_schema_reference.sql`.
   - Carga los datos generados:

     ```pwsh
     sqlplus usuario/clave@tns @.\data\output\ciudades\insert_ciudad.sql
     ```

     (También puedes usar SQL*Loader/External Table apuntando a `ciudades_ec.csv`).

3. **Relacionar clientes con ciudades**
   - Ejecuta los scripts para añadir el campo y asignar valores:

     ```pwsh
     sqlplus usuario/clave@tns @.\scripts\sql\oltp\02_add_ciudad_to_clientes.sql
     sqlplus usuario/clave@tns @.\scripts\sql\oltp\03_assign_random_city_to_clients.sql
     ```

   - Modifica el bloque PL/SQL si prefieres estrategias determinísticas (p.ej. por provincia conocida en otra tabla).

4. **Crear esquema de provincias / cantones / parroquias**
   - Ejecuta `scripts/sql/oltp/04_create_province_canton_parish_tables.sql` para la estructura.
   - Descarga los datos de https://github.com/vfabianfarias/Datos-Geograficos-Ecuador o del PDF oficial del MTOP (https://www.obraspublicas.gob.ec/.../CENSO_2016_TTHH_Listado_prov-cantones-parroquias.pdf).
   - Usa SQL*Loader, external tables o convierte los CSV en INSERTs para poblar cada tabla respetando la jerarquía.

5. **Implementar el Data Warehouse**
   - Asegura que las dimensiones base (`Dim_Producto`, `Dim_Tiempo`, `Dim_Pedidos`) y `Fact_Ventas` estén pobladas.
   - Ejecuta `scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql` para crear `Dim_Categoria`, `Dim_Ubicacion`, la tabla de hechos con medidas y la vista `VW_MAS_VENDIDO`.
   - Corre `scripts/sql/etl/load_dw_from_oltp.sql` para poblar las dimensiones (incluido el lookup de provincia/cantón/parroquia vía censo) y cargar `Fact_Ventas` con `CantidadVendida` y `MontoTotal`.
   - El script espera que `PRODUCTOS` tenga una columna `CATEGORIA`; ajusta nombres o agrega lookups si en tu modelo difiere.

6. **Consultar el producto más vendido**
   - Usa la vista `VW_MAS_VENDIDO` para obtener, por día/categoría/provincia/ciudad, qué producto tuvo la mayor venta (suma de `CantidadVendida`).
   - Ejemplo:

     ```sql
     SELECT fecha, categoria, provincia, ciudad, producto, total_vendido
     FROM VW_MAS_VENDIDO
     WHERE fecha BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
     ```

Esquema estrella (resumen DDL)
- **Dim_Tiempo**: `TiempoID`, `Fecha`, `Año`, `Mes`, `Trimestre`, `DiaSemana`.
- **Dim_Producto** + **Dim_Categoria**: detalle de producto con clave hacia `Dim_Categoria` (derivada de `PRODUCTOS.CATEGORIA`).
- **Dim_Ubicacion**: clave surrogate y jerarquía `Provincia → Cantón → Parroquia/Ciudad` cruzando tablas de censo (`PROVINCIAS`, `CANTONES`, `PARROQUIAS`) con la tabla transaccional `CIUDAD`.
- **Fact_Ventas**: referencias a todas las dimensiones (`ProductoID`, `TiempoID`, `PedidoID`, `UbicacionID`, `CategoriaID`) y medidas `CantidadVendida`, `MontoTotal`.
- **VW_MAS_VENDIDO**: vista que agrega `Fact_Ventas` y devuelve el producto top por corte de tiempo/categoría/ubicación.

Notas
- El script `download_ecuador_cities.py` solo genera archivos locales; no ejecuta INSERTs en Oracle. Valida los datos antes de cargarlos.
- Si necesitas automatizar la carga directa (usando `cx_Oracle` o `oracledb`), indícalo para extender el script con conexión y ejecución segura.
- Para provincias/cantones/parroquias se recomienda normalizar mayúsculas/minúsculas y códigos para facilitar joins con `CIUDAD` o `Dim_Ubicacion`.
- `scripts/sql/oltp/base_transactional_schema_reference.sql` incluye ejemplos de inserción en las dimensiones base; adapta las fuentes (`PRODUCTOS`, `ORDENES`, `DETALLE_ORDENES`) según tu esquema transaccional real.
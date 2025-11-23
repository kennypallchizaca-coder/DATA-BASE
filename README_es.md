Resumen y pasos para implementar ETL y Data Warehouse (Ecuador - ciudades/provincias)

Componentes principales
- `data/`: estructura organizada para datos crudos y salidas.
  - `data/raw/ciudades/EC.txt`: padrón de ciudades de Ecuador listo para uso offline.
  - `data/raw/jerarquia/`: PDF del censo y CSVs de provincias/cantones/parroquias que tú proporciones.
  - `data/output/ciudades/`: destino por defecto de los archivos generados por el ETL.
- `sql/oltp/`: scripts para enriquecer el esquema transaccional con geografía.
  - `01_create_ciudad_table.sql`: DDL independiente para crear `CIUDAD` con su secuencia y trigger.
  - `02_add_ciudad_to_clientes.sql`: agrega `CIUDADID` a `CLIENTES` y crea la FK hacia `CIUDAD`.
  - `03_assign_random_city_to_clients.sql`: bloque PL/SQL que asigna ciudades aleatorias a los clientes existentes.
  - `04_create_province_canton_parish_tables.sql`: tablas jerárquicas `PROVINCIAS`, `CANTONES`, `PARROQUIAS` con sus claves foráneas.
  - `base_transactional_schema_reference.sql`: esquema base de referencia con ejemplos de inserción en dimensiones.
- `sql/dw/01_dw_star_schema_and_top_product_view.sql`: DDL completo del esquema estrella (tiempo, producto, categoría, ubicación con jerarquía provincia → cantón → parroquia/ciudad), tabla de hechos con medidas y vista `VW_MAS_VENDIDO`.
- `sql/legacy/`: nombres originales preservados solo para compatibilidad; usa los scripts mantenidos y comentados en `sql/oltp/` y `sql/dw/` para nuevas implementaciones.
- `etl/sql/load_dw_from_oltp.sql`: script ETL en SQL que alimenta las dimensiones (incluyendo el cruce con el censo) y carga la tabla de hechos desde `ORDENES`/`DETALLE_ORDENES`.
- `etl/python/download_ecuador_cities.py`: ETL ligero para descargar el padrón de ciudades desde carta-natal.es, generar `ciudades_ec.csv` y un archivo de INSERTs para poblar `CIUDAD`. Detecta automáticamente `data/raw/ciudades/EC.txt` si está disponible.

Flujo sugerido (ETL → DW)
1. **Descargar y preparar ciudades (fuente carta-natal.es o archivo local)**
   - Requiere Python 3 y el paquete `requests`:

     ```pwsh
     python -m pip install --user requests
     ```

   - Ejecutar el script (genera archivos en `data/output/ciudades/` por defecto):

     ```pwsh
     python .\etl\python\download_ecuador_cities.py

     # O reutiliza el archivo local EC.txt para evitar descarga (ruta ya incluida por defecto):
     python .\etl\python\download_ecuador_cities.py --source .\data\raw\ciudades\EC.txt
     ```

   - Parámetros opcionales: `--code` (ISO, default EC), `--csv` y `--sql` para personalizar rutas.
   - Revisa `ciudades_ec.csv` antes de cargar; el script intenta detectar delimitadores y codificaciones, pero conviene validar manualmente.

2. **Crear/popular tabla `CIUDAD`**
   - En tu motor Oracle ejecuta `sql/oltp/01_create_ciudad_table.sql` o el bloque equivalente en `sql/oltp/base_transactional_schema_reference.sql`.
   - Carga los datos generados:

     ```pwsh
     sqlplus usuario/clave@tns @.\data\output\ciudades\insert_ciudad.sql
     ```

     (También puedes usar SQL*Loader/External Table apuntando a `ciudades_ec.csv`).

3. **Relacionar clientes con ciudades**
   - Ejecuta los scripts para añadir el campo y asignar valores:

     ```pwsh
     sqlplus usuario/clave@tns @.\sql\oltp\02_add_ciudad_to_clientes.sql
     sqlplus usuario/clave@tns @.\sql\oltp\03_assign_random_city_to_clients.sql
     ```

   - Modifica el bloque PL/SQL si prefieres estrategias determinísticas (p.ej. por provincia conocida en otra tabla).

4. **Crear esquema de provincias / cantones / parroquias**
   - Ejecuta `sql/oltp/04_create_province_canton_parish_tables.sql` para la estructura.
   - Descarga los datos de https://github.com/vfabianfarias/Datos-Geograficos-Ecuador o del PDF oficial del MTOP (https://www.obraspublicas.gob.ec/.../CENSO_2016_TTHH_Listado_prov-cantones-parroquias.pdf).
   - Usa SQL*Loader, external tables o convierte los CSV en INSERTs para poblar cada tabla respetando la jerarquía.

5. **Implementar el Data Warehouse**
   - Asegura que las dimensiones base (`Dim_Producto`, `Dim_Tiempo`, `Dim_Pedidos`) y `Fact_Ventas` estén pobladas.
   - Ejecuta `sql/dw/01_dw_star_schema_and_top_product_view.sql` para crear `Dim_Categoria`, `Dim_Ubicacion`, la tabla de hechos con medidas y la vista `VW_MAS_VENDIDO`.
   - Corre `etl/sql/load_dw_from_oltp.sql` para poblar las dimensiones (incluido el lookup de provincia/cantón/parroquia vía censo) y cargar `Fact_Ventas` con `CantidadVendida` y `MontoTotal`.
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
- `sql/oltp/base_transactional_schema_reference.sql` incluye ejemplos de inserción en las dimensiones base; adapta las fuentes (`PRODUCTOS`, `ORDENES`, `DETALLE_ORDENES`) según tu esquema transaccional real.
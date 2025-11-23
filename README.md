# Order & DW extensions (Ecuador)

This repository contains SQL and ETL artifacts to extend a basic order schema with Ecuadorian city/province coverage and a full star-schema for reporting the top-selling product by time, category, and location. Legacy duplicate SQL files were removed so only the canonical, organized scripts under `sql/oltp/` and `sql/dw/` remain.

## What is included
- **data/**: Organized layout for sources and outputs.
  - `data/raw/ciudades/EC.txt`: Offline Ecuador city catalog.
  - `data/raw/jerarquia/`: Census PDF and (user-provided) CSVs for province/canton/parish hierarchies.
  - `data/output/ciudades/`: Default destination for generated CSV/SQL inserts.
- **sql/oltp/**: Scripts to enrich the transactional system with geography.
  - `01_create_ciudad_table.sql`: Creates `CIUDAD` with PK + sequence/trigger.
  - `02_add_ciudad_to_clientes.sql`: Adds the `CIUDADID` foreign key to `CLIENTES`.
  - `03_assign_random_city_to_clients.sql`: PL/SQL block to seed existing clients with random cities.
  - `04_create_province_canton_parish_tables.sql`: Geography hierarchy tables (`PROVINCIAS`, `CANTONES`, `PARROQUIAS`).
  - `base_transactional_schema_reference.sql`: Original base schema with example dimension inserts.
- **sql/dw/01_dw_star_schema_and_top_product_view.sql**: Complete DW star-schema DDL (time, product, category, location with province → cantón → parroquia/ciudad), fact table with measures, and `VW_MAS_VENDIDO` view for “most sold product.”
- **etl/sql/load_dw_from_oltp.sql**: End-to-end ETL in SQL to hydrate dimensions (including census lookup) and load the fact table from transactional `ORDENES`/`DETALLE_ORDENES`.
- **etl/python/download_ecuador_cities.py**: Helper ETL to download the city catalog from https://carta-natal.es/descargas/coordenadas.php, generate a CSV, and emit `INSERT` statements for `CIUDAD`. It auto-detects the offline `data/raw/ciudades/EC.txt` when present.

## Quickstart (ETL → load → DW)
1. **Install ETL dependency**
   ```bash
   python -m pip install --user requests
   ```

2. **Download and prepare cities**
   ```bash
   # Online download (default):
   python ./etl/python/download_ecuador_cities.py

   # Offline path is picked automatically if data/raw/ciudades/EC.txt exists,
   # or pass a custom TXT/ZIP file explicitly:
   python ./etl/python/download_ecuador_cities.py --source ./data/raw/ciudades/EC.txt
   ```
   The script writes `ciudades_ec.csv` and `insert_ciudad.sql` to `data/output/ciudades/` by default. Use `--code`, `--csv`, or `--sql` to customize.

3. **Create and populate `CIUDAD`**
   - Run the DDL in `sql/oltp/01_create_ciudad_table.sql` (or the `CIUDAD` block in `sql/oltp/base_transactional_schema_reference.sql` if you prefer a single script).
   - Load the generated inserts:
     ```bash
     sqlplus user/pass@tns @./data/output/ciudades/insert_ciudad.sql
     ```

4. **Link customers to cities**
   ```bash
   sqlplus user/pass@tns @./sql/oltp/02_add_ciudad_to_clientes.sql
   sqlplus user/pass@tns @./sql/oltp/03_assign_random_city_to_clients.sql
   ```
   Edit the PL/SQL if you need deterministic assignments instead of randomness.

5. **Create province/canton/parish hierarchy**
   ```bash
   sqlplus user/pass@tns @./sql/oltp/04_create_province_canton_parish_tables.sql
   ```
   Populate from the datasets at https://github.com/vfabianfarias/Datos-Geograficos-Ecuador or the MTOP census PDF (2016).

6. **Build the DW layer and “most sold” view**
   ```bash
   sqlplus user/pass@tns @./sql/dw/01_dw_star_schema_and_top_product_view.sql
   sqlplus user/pass@tns @./etl/sql/load_dw_from_oltp.sql
   ```
   Ensure transactional tables (`PRODUCTOS`, `CLIENTES`, `ORDENES`, `DETALLE_ORDENES`) are populated first. The ETL performs the census lookup to bind `CLIENTES` → `CIUDAD` → `PROVINCIA/CANTON/PARROQUIA` before loading the fact table.

7. **Query the most sold product**
   ```sql
   SELECT fecha, categoria, provincia, ciudad, producto, total_vendido
   FROM VW_MAS_VENDIDO
   WHERE fecha BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
   ```

## Star schema (DDL overview)
- **Dim_Tiempo**: `TiempoID`, `Fecha`, `Año`, `Mes`, `Trimestre`, `DiaSemana`.
- **Dim_Producto** + **Dim_Categoria**: Product details enriched with a foreign key to `Dim_Categoria` (derived from `PRODUCTOS.CATEGORIA`).
- **Dim_Ubicacion**: Surrogate key plus hierarchy `Provincia → Cantón → Parroquia/Ciudad`, joining census tables (`PROVINCIAS`, `CANTONES`, `PARROQUIAS`) with the transactional `CIUDAD` list.
- **Fact_Ventas**: References all dimensions (`ProductoID`, `TiempoID`, `PedidoID`, `UbicacionID`, `CategoriaID`) and measures `CantidadVendida` and `MontoTotal`.
- **VW_MAS_VENDIDO**: View that aggregates `Fact_Ventas` and returns the top-selling product per time/category/location slice.

## Notes
- The ETL only generates files; it does not connect to the database. Review the CSV/SQL before loading.
- `Dim_Ubicacion` is populated from `CIUDAD`; adjust joins if you already have province/canton mappings.
- All sequences/triggers are provided for simple autonumbering. Feel free to swap for identity columns if your Oracle version supports them.

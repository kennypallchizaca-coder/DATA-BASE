# Order & DW extensions (Ecuador)

This repository contains SQL and ETL artifacts to extend a basic order schema with Ecuadorian city/province coverage and a small star-schema for reporting the top-selling product by time, category, and location.

## What is included
- **data/**: Folderized layout for sources and outputs.
  - `data/raw/ciudades/EC.txt`: Offline Ecuador city catalog.
  - `data/raw/jerarquia/`: Census PDF and (user-provided) CSVs for province/canton/parish hierarchies.
  - `data/output/ciudades/`: Default destination for generated CSV/SQL inserts.
- **sql/01_create_ciudad.sql**: Standalone DDL for the transactional `CIUDAD` table (PK + sequence/trigger).
- **sql/TABLA.sql**: Base warehouse dimensions (`Dim_Producto`, `Dim_Tiempo`, `Dim_Pedidos`), `Fact_Ventas`, and the transactional `CIUDAD` table with sequence/trigger for auto-IDs.
- **sql/02_alter_clientes_add_ciudad.sql**: Adds `CIUDADID` to `CLIENTES` and creates the foreign key.
- **sql/03_assign_random_ciudad.sql**: PL/SQL block that assigns a random city to every existing client.
- **sql/04_create_prov_cant_parro.sql**: Minimal hierarchy tables for `PROVINCIAS`, `CANTONES`, `PARROQUIAS` with their sequences and triggers.
- **sql/05_dw_schema_and_most_sold.sql**: Adds `Dim_Categoria`, `Dim_Ubicacion` (province/city), aggregated fact table, and the `VW_MAS_VENDIDO` view for “most sold product.”
- **etl/download_ciudades.py**: Helper ETL to download the city catalog from https://carta-natal.es/descargas/coordenadas.php, generate a CSV, and emit `INSERT` statements for `CIUDAD`. It auto-detects the offline `data/raw/ciudades/EC.txt` when present.

## Quickstart (ETL → load → DW)
1. **Install ETL dependency**
   ```bash
   python -m pip install --user requests
   ```

2. **Download and prepare cities**
   ```bash
   # Online download (default):
   python ./etl/download_ciudades.py

   # Offline path is picked automatically if data/raw/ciudades/EC.txt exists,
   # or pass a custom TXT/ZIP file explicitly:
   python ./etl/download_ciudades.py --source ./data/raw/ciudades/EC.txt
   ```
   The script writes `ciudades_ec.csv` and `insert_ciudad.sql` to `data/output/ciudades/` by default. Use `--code`, `--csv`, or `--sql` to customize.

3. **Create and populate `CIUDAD`**
   - Run the DDL in `sql/01_create_ciudad.sql` (or the `CIUDAD` block in `sql/TABLA.sql` if you prefer a single script).
   - Load the generated inserts:
     ```bash
     sqlplus user/pass@tns @./data/output/ciudades/insert_ciudad.sql
     ```

4. **Link customers to cities**
   ```bash
   sqlplus user/pass@tns @./sql/02_alter_clientes_add_ciudad.sql
   sqlplus user/pass@tns @./sql/03_assign_random_ciudad.sql
   ```
   Edit the PL/SQL if you need deterministic assignments instead of randomness.

5. **Create province/canton/parish hierarchy**
   ```bash
   sqlplus user/pass@tns @./sql/04_create_prov_cant_parro.sql
   ```
   Populate from the datasets at https://github.com/vfabianfarias/Datos-Geograficos-Ecuador or the MTOP census PDF (2016).

6. **Build the DW layer and “most sold” view**
   ```bash
   sqlplus user/pass@tns @./sql/05_dw_schema_and_most_sold.sql
   ```
   Ensure transactional tables (`PRODUCTOS`, `CLIENTES`, `ORDENES`, `DETALLE_ORDENES`) are populated first.

7. **Query the most sold product**
   ```sql
   SELECT fecha, categoria, provincia, ciudad, producto, total_vendido
   FROM VW_MAS_VENDIDO
   WHERE fecha BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
   ```

## Notes
- The ETL only generates files; it does not connect to the database. Review the CSV/SQL before loading.
- `Dim_Ubicacion` is populated from `CIUDAD`; adjust joins if you already have province/canton mappings.
- All sequences/triggers are provided for simple autonumbering. Feel free to swap for identity columns if your Oracle version supports them.

# Informe operativo completo

## 1. Resumen ejecutivo
Este repositorio automatiza la construcción de un entorno OLTP enriquecido (CLIENTES, PRODUCTOS, ORDENES, DETALLE_ORDENES, CIUDAD y jerarquía geográfica) y su transformación posterior en un Data Warehouse en estrella. El flujo se centra en `scripts/python/run_full_etl_pipeline.py`, que genera catálogos de ciudades y jerarquía, crea un plan SQL (`data/output/plan_ejecucion_dw.sql`) y prepara todos los artefactos que deben ejecutarse en Oracle para que el DW quede poblado con datos de prueba realistas y coherentes.

## 2. Objetivos y alcance

- **Objetivo principal**: disponer de un pipeline reproducible que reconstruya desde cero el esquema transaccional y produzca dimensiones/factos listos para análisis de ventas.
- **Ámbito**: el informe cubre la preparación de datos, creación de tablas, carga de datos semilla (≥30 filas por tabla), armado del esquema estrella, vista de top producto y el ETL hacia las tablas DW.
- **Indicadores**: al ejecutar el plan se espera contar con al menos 30 clientes/productos/órdenes, jerarquía geográfica consistente, dimensiones DW llenas y la vista `VW_MAS_VENDIDO` reflejando el producto más vendido por provincia-ciudad-fecha.

## 3. Arquitectura del repositorio

### 3.1 `data/`

- `raw/ciudades/`: descargas oficiales de GeoNames (`EC.txt`, `EC.zip`, `admin1CodesASCII.txt`). Se usan para regenerar `ciudades_ec.csv`.
- `raw/jerarquia/`: CSV de provincias/cantones/parroquias, reconstruidos desde los dumps SQL oficiales ubicados en `data/Datos-Geograficos-Ecuador/`.
- `output/ciudades/`: contiene el CSV procesado y `insert_ciudad.sql`.
- `output/jerarquia/`: script combinado de jerarquía (`insert_jerarquia.sql`) con DELETE/INSERT idempotente y realineamiento de secuencias.
- `output/plan_ejecucion_dw.sql`: plan maestro que encadena todos los scripts, prompts de validación y comandos finales.
- `Datos-Geograficos-Ecuador/`: dumps originales (`provincias.sql`, `cantones.sql`, `parroquias.sql`) usados como fuente de jerarquía.

### 3.2 `scripts/`

- `python/`:
  - `run_full_etl_pipeline.py`: descarga catálogos, construye la jerarquía, escribe el plan SQL y reporta métricas de generación.
  - `ciudades/download_ecuador_cities.py`: obtiene GeoNames (local o remoto) y escribe CSV/SQL de CIUDAD.
  - `jerarquia/build_jerarquia_csv.py`: extrae de los dumps SQL la jerarquía y escribe CSV.
  - `jerarquia/generate_jerarquia_inserts.py`: empaqueta los CSV en un único script con DELETE/INSERT y secuencias.

- `sql/oltp/`:
  - `00_create_base_tables.sql`: crea CLIENTES, PRODUCTOS, ORDENES y DETALLE_ORDENES si no existen.
  - `00_require_base_tables.sql`: valida su existencia antes de continuar.
  - `05_seed_transactional_data.sql`: inserta 30 clientes/productos/órdenes y 60 líneas de detalle con datos realistas (nombres, emails, precios, fechas 2024).
  - `01_create_ciudad_table.sql`, `02_add_ciudad_to_clientes.sql`, `03_assign_random_city_to_clients.sql`: habilitan CIUDAD y asignan ciudades a clientes.
  - `04_create_province_canton_parish_tables.sql` + `data/output/jerarquia/insert_jerarquia.sql`: crean y cargan la jerarquía geográfica oficial.

- `sql/dw/` y `sql/etl/`:
  - `dw/01_dw_star_schema_and_top_product_view.sql`: define dimensiones, hechos, secuencias y la vista `VW_MAS_VENDIDO`.
  - `etl/load_dw_from_oltp.sql`: inserta la fila "DESCONOCIDA", carga/actualiza dimensiones y hechos con `MERGE`.

## 4. Flujo completo de ejecución

1. **Regeneración de catálogos**:
   ```powershell
   python .\scripts\python\run_full_etl_pipeline.py
   ```
   Opciones útiles:
   - `--skip-cities`: usa `insert_ciudad.sql` existente.
   - `--skip-jerarquia-csv`: evita recalcular los CSV jerárquicos.
   - `--source` / `--jerarquia-source`: rutas locales con los datos base ya descargados.

2. **Plan maestro** (`data/output/plan_ejecucion_dw.sql`):
   - Crea las tablas base y valida su existencia.
   - Ejecuta `05_seed_transactional_data.sql` antes de construir la jerarquía.
   - Crea CIUDAD, carga ciudades y asigna referencias.
   - Construye jerarquía y llena DW.
   - Ejecuta `load_dw_from_oltp.sql` para poblar dimensiones y hechos.
   - Incluye prompts para verificar ciudades, DW_DIM_UBICACION y VW_MAS_VENDIDO.

3. **Ejecución en Oracle**:
   ```sql
   sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
   ```
   El plan es idempotente: evita reinsertar si ya hay filas y solo recrea objetos faltantes.

## 5. Datos y resultados esperados

- **Clientes**: 30 filas con nombres/especialidades latinas, emails y teléfonos representativos. Cada cliente aparece en `CLIENTES`.
- **Productos**: 30 productos premium + domésticos (laptops, muebles, hogar, deportes). Los precios se usan en `DETALLE_ORDENES`.
- **Órdenes**: 30 pedidos distribuidos durante 2024, con descuentos variados (0-15%).
- **Detalle de órdenes**: 60 líneas asociadas a 30 órdenes, cada una ligando `PRODUCTOS` con cantidades y precios capturados de la tabla original.
- **DW**: `DW_DIM_TIEMPO`, `DW_DIM_CATEGORIA`, `DW_DIM_PRODUCTO`, `DW_DIM_UBICACION`, `DW_FACT_VENTAS` llenas via `MERGE`.
- **Vista VW_MAS_VENDIDO**: reporta el producto más vendido por fecha/categoría/provincia/ciudad según los hechos cargados.

## 6. Validación y métricas

- Ejecutar las siguientes consultas tras correr el plan:
  ```sql
  SELECT COUNT(*) FROM CLIENTES;
  SELECT COUNT(*) FROM PRODUCTOS;
  SELECT COUNT(*) FROM ORDENES;
  SELECT COUNT(*) FROM DETALLE_ORDENES;
  SELECT COUNT(*) FROM DW_DIM_UBICACION;
  SELECT COUNT(*) FROM DW_FACT_VENTAS;
  SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 5;
  ```
- Asegurar que los conteos de CLIENTES/PRODUCTOS/ORDENES/DETALLE_ORDENES sean ≥ 30.
- Verificar que `DW_DIM_UBICACION` incluya la fila “DESCONOCIDA” (UbicacionID = 0) y las ciudades asignadas.
- Confirmar que `VW_MAS_VENDIDO` muestra resultados con provincia, ciudad y producto coherentes.
- El plan ya imprime prompts con conteos de CIUDAD y DW_DIM_UBICACION, facilitando esta validación manual.

## 7. Observaciones técnicas

- La generación de jerarquía mantiene todas las provincias/cantones/parroquias actualizadas desde los dumps originales y se puede regenerar ejecutando `build_jerarquia_csv.py` seguido de `run_full_etl_pipeline.py`.
- Las cargas DW usan `MERGE` para evitar duplicados y aplicar actualizaciones si cambian precios o categorías.
- Las secuencias están definidas en `dw/01_dw_star_schema...` y en los scripts OLTP (ej. `SEQ_CIUDAD`). Al repetir el plan se preservan los valores anteriores con `NOCACHE/NOCYCLE`.
- El plan activa `WHENEVER SQLERROR CONTINUE` pero se puede quitar si se desea detener ante la primera falla.

## 8. Riesgos y dependencias

- Requiere una instancia Oracle accesible y privilegios para crear tablas, secuencias y triggers en el esquema destino.
- Depende de que `data/raw/ciudades` y `data/raw/jerarquia` contengan los datos oficiales o se haya descargado previamente (`download_ecuador_cities.py` gestiona GeoNames si faltan).
- Si CIUDAD se ejecuta en otro esquema, conviene usar `ALTER SESSION SET CURRENT_SCHEMA=...` antes de ejecutar el plan.
- Los scripts asumen que `productos` y `clientes` usan tipos `NUMBER(10)` y `VARCHAR2`; adaptarlos antes si el esquema difiere.

## 9. Próximos pasos sugeridos

1. Automatizar la ejecución del plan vía CI/CD conectando con una base Oracle de pruebas.
2. Añadir scripts de verificación automatizada (unitarias o de integración) que validen la vista `VW_MAS_VENDIDO` tras cada carga.
3. Externalizar datos de clientes/productos a CSV o a un conector para facilitar la entrada de nuevas fuentes reales.

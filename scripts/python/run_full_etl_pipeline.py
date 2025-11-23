#!/usr/bin/env python3
"""Orquesta la generación del catálogo de ciudades y el plan SQL completo.

Este script está pensado para ejecutarse una sola vez y dejar listos:
- Los archivos CSV/SQL con el catálogo de ciudades (fuente carta-natal.es o
  `data/raw/ciudades/EC.txt`).
- Un plan de ejecución `data/output/plan_ejecucion_dw.sql` que encadena los
  scripts SQL del esquema transaccional y del Data Warehouse en el orden
  sugerido.

No se conecta a la base de datos: solo genera artefactos y deja claro qué
scripts ejecutar en SQL*Plus/SQLcl.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List

from download_ecuador_cities import (
    DEFAULT_CODE,
    DEFAULT_CSV,
    DEFAULT_SQL,
    PROJECT_ROOT,
    generate_catalog,
    local_source_path,
)

PLAN_FILE = PROJECT_ROOT / "data" / "output" / "plan_ejecucion_dw.sql"
SQL_STEPS: List[str] = [
    "@scripts/sql/oltp/01_create_ciudad_table.sql",
    "@scripts/sql/oltp/02_add_ciudad_to_clientes.sql",
    "@scripts/sql/oltp/03_assign_random_city_to_clients.sql",
    "@scripts/sql/oltp/04_create_province_canton_parish_tables.sql",
    "@scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql",
    "@scripts/sql/etl/load_dw_from_oltp.sql",
]


def build_plan_file(path: Path) -> Path:
    """Escribe un script SQL*Plus que encadena todos los pasos del DW."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        fh.write("-- Plan generado automáticamente por run_full_etl_pipeline.py\n")
        fh.write("-- Ejecuta este archivo en SQL*Plus/SQLcl desde la raíz del repo.\n\n")
        for step in SQL_STEPS:
            fh.write(step + "\n")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera catálogo de ciudades y plan SQL del DW")
    parser.add_argument(
        "--code", default=DEFAULT_CODE, help="Código ISO del país; EC por defecto usa el padrón local"
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=None,
        help="Ruta TXT/ZIP local. Si no se pasa, intenta usar data/raw/ciudades/<code>.txt y, de no existir, descarga.",
    )
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="Ruta de salida para el CSV de ciudades")
    parser.add_argument("--sql", type=Path, default=DEFAULT_SQL, help="Ruta de salida para los INSERTs de ciudades")
    parser.add_argument(
        "--plan-path", type=Path, default=PLAN_FILE, help="Ruta donde guardar el plan concatenado de SQL"
    )
    args = parser.parse_args()

    source = args.source
    if source is None:
        candidate = local_source_path(args.code)
        if candidate.exists():
            source = candidate

    total = generate_catalog(code=args.code, csv_path=args.csv, sql_path=args.sql, source_path=source)
    plan_path = build_plan_file(args.plan_path)

    print("Catálogo generado:")
    print(f"  - {total} ciudades -> {args.csv}")
    print(f"  - INSERTs SQL     -> {args.sql}")
    print("Plan de ejecución SQL listo:")
    print(f"  - {plan_path}")
    print("Ejecuta el plan en SQL*Plus/SQLcl y tendrás todas las tablas/pasos del enunciado.")


if __name__ == "__main__":
    main()

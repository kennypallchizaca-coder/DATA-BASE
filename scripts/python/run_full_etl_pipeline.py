"""
Pipeline que prepara todos los artefactos para el DW:
- Genera el catalogo de ciudades (CSV + INSERTs) usando GeoNames.
- Crea un plan SQL (@file) que encadena los scripts OLTP + DW + ETL.

No se conecta a la BD. Ejecuta el plan resultante en SQL*Plus/SQLcl desde la raiz del repo:
    sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List

from jerarquia.build_jerarquia_csv import build_geo_csv
from ciudades.download_ecuador_cities import COUNTRY_CODE, generate_catalog
from jerarquia.generate_jerarquia_inserts import generate_jerarquia_sql

ROOT = Path(__file__).resolve().parents[2]
CITY_INSERT_SQL = ROOT / "data" / "output" / "ciudades" / "insert_ciudad.sql"
JERARQUIA_SQL = ROOT / "data" / "output" / "jerarquia" / "insert_jerarquia.sql"

SQL_SEQUENCE = [
    # Garantiza que las tablas base se creen y luego se validen antes de continuar.
    "scripts/sql/oltp/00_create_base_tables.sql",
    "scripts/sql/oltp/00_require_base_tables.sql",
    "scripts/sql/oltp/05_seed_transactional_data.sql",
    "scripts/sql/oltp/01_create_ciudad_table.sql",
    str(CITY_INSERT_SQL.relative_to(ROOT)),
    "scripts/sql/oltp/02_add_ciudad_to_clientes.sql",
    "scripts/sql/oltp/03_assign_random_city_to_clients.sql",
    "scripts/sql/oltp/04_create_province_canton_parish_tables.sql",
    str(JERARQUIA_SQL.relative_to(ROOT)),
    "scripts/sql/dw/01_dw_star_schema_and_top_product_view.sql",
    "scripts/sql/etl/load_dw_from_oltp.sql",
]


def build_plan_file(output_path: Path, sql_paths: List[str]) -> Path:
    """Genera el archivo @plan con los scripts SQL en orden."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as fh:
        fh.write("-- Plan de ejecucion para construir OLTP enriquecido + DW\n")
        fh.write("SET DEFINE OFF;\n")
        fh.write("SET ECHO ON;\n")
        fh.write("SET FEEDBACK ON;\n")
        fh.write("SET SERVEROUTPUT ON;\n")
        fh.write("WHENEVER SQLERROR CONTINUE;\n")
        fh.write("-- Si las tablas base estan en otro esquema, descomenta y ajusta:\n")
        fh.write("-- ALTER SESSION SET CURRENT_SCHEMA=ESQUEMAORIGINAL;\n")
        for script in sql_paths:
            fh.write(f"@{Path(script).as_posix()}\n")
        fh.write("\nPROMPT ===== Verificacion rapida =====;\n")
        fh.write("PROMPT Conteo de ciudades en CIUDAD:;\n")
        fh.write("SELECT COUNT(*) AS TOTAL_CIUDADES FROM CIUDAD;\n")
        fh.write("PROMPT Ejemplo de 5 ciudades:\n")
        fh.write("SELECT CIUDADID, NOMBRE, PROVINCIA FROM CIUDAD WHERE ROWNUM <= 5;\n")
        fh.write("PROMPT Conteo en DW_DIM_UBICACION:\n")
        fh.write("SELECT COUNT(*) AS TOTAL_DIM_UBICACION FROM DW_DIM_UBICACION;\n")
        fh.write("PROMPT Top producto mas vendido (si hay datos):\n")
        fh.write("SELECT * FROM VW_MAS_VENDIDO WHERE ROWNUM <= 5;\n")
    return output_path


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepara la ejecucion completa del DW (ciudades + SQL).")
    parser.add_argument("--skip-cities", action="store_true", help="No generar el catalogo de ciudades.")
    parser.add_argument("--source", type=Path, help="Ruta local a EC.txt/EC.zip para evitar descarga.")
    parser.add_argument(
        "--jerarquia-source",
        type=Path,
        help="Directorio que contiene provincias.csv/cantones.csv/parroquias.csv para la jerarquia.",
    )
    parser.add_argument(
        "--skip-jerarquia-csv",
        action="store_true",
        help="Omitir la regeneracion de los CSV jerarquicos (usa los archivos existentes).",
    )
    parser.add_argument("--code", default=COUNTRY_CODE, help="Codigo ISO de pais, default EC.")
    parser.add_argument("--plan-output", type=Path, default=ROOT / "data" / "output" / "plan_ejecucion_dw.sql")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = _parse_args(argv)

    city_result = None
    if not args.skip_cities:
        city_result = generate_catalog(code=args.code, source=args.source)
    elif not CITY_INSERT_SQL.exists():
        raise FileNotFoundError(
            f"No se encontro el archivo de insert de ciudades en {CITY_INSERT_SQL}. "
            "Ejecuta sin --skip-cities o genera el archivo manualmente."
        )

    if not args.skip_jerarquia_csv:
        build_geo_csv()

    jerarquia_result = generate_jerarquia_sql(args.jerarquia_source)
    plan_file = build_plan_file(args.plan_output, SQL_SEQUENCE)

    print("Plan generado correctamente.")
    if city_result:
        print(
            f"Ciudades generadas: {city_result['total_ciudades']} "
            f"(CSV: {city_result['csv']}, SQL: {city_result['sql']})"
        )
    if jerarquia_result:
        if jerarquia_result["status"] == "ok":
            print(
                "Jerarquía cargada:"
                f" provincias={jerarquia_result['provincias']},"
                f" cantones={jerarquia_result['cantones']},"
                f" parroquias={jerarquia_result['parroquias']}"
            )
        else:
            print(
                "No se encontraron CSV de jerarquía. "
                f"Se dejó el archivo {jerarquia_result['sql']} con instrucciones."
            )
    print(f"Plan SQL: {plan_file}")
    print("Ejecutar desde la raiz del repo: sqlplus usuario/clave@tns @data/output/plan_ejecucion_dw.sql")


if __name__ == "__main__":
    main(sys.argv[1:])

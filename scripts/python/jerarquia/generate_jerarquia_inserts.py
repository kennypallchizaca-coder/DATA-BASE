"""
Combina los datos de jerarquia (provincias/cantones/parroquias) en un unico SQL
para poblar las tablas de geografia e incluye ajustes para las secuencias.
"""

from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path
from textwrap import dedent
from typing import Iterable, List, Optional

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SOURCE_DIR = ROOT / "data" / "raw" / "jerarquia"
OUTPUT_DIR = ROOT / "data" / "output" / "jerarquia"
OUTPUT_FILE = OUTPUT_DIR / "insert_jerarquia.sql"
MANUAL_SQL_DIRS = (
    OUTPUT_DIR,
    ROOT / "data" / "output" / "ciudades",
)
MANUAL_SQL_FILES = (
    "insert_provincias.sql",
    "insert_cantones.sql",
    "insert_parroquias.sql",
)


@dataclass
class Province:
    provinciaid: int
    codigo: str
    nombre: str


@dataclass
class Canton:
    cantonid: int
    provinciaid: int
    codigo: str
    nombre: str


@dataclass
class Parroquia:
    parroquiaid: int
    cantonid: int
    codigo: str
    nombre: str


def _root_dir() -> Path:
    return ROOT


def _load_csv(path: Path, required_columns: Iterable[str]) -> List[dict[str, str]]:
    if not path.exists():
        return []

    with path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        if not reader.fieldnames:
            return []
        header = {name.strip().upper() for name in reader.fieldnames}
        missing = [col for col in required_columns if col.upper() not in header]
        if missing:
            raise ValueError(f"Faltan columnas en {path}: {', '.join(missing)}")
        rows: list[dict[str, str]] = []
        for raw_row in reader:
            normalized = {name.strip().upper(): (value or "").strip() for name, value in raw_row.items()}
            rows.append(normalized)
        return rows


def _escape(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _generate_sequence_alignment_block() -> str:
    return dedent(
        """\
        DECLARE
            v_target  NUMBER;
            v_current NUMBER;
        BEGIN
            SELECT NVL(MAX(PROVINCIAID), 0) INTO v_target FROM PROVINCIAS;
            SELECT SEQ_PROVINCIA.NEXTVAL INTO v_current FROM DUAL;
            WHILE v_current <= v_target LOOP
                SELECT SEQ_PROVINCIA.NEXTVAL INTO v_current FROM DUAL;
            END LOOP;

            SELECT NVL(MAX(CANTONID), 0) INTO v_target FROM CANTONES;
            SELECT SEQ_CANTON.NEXTVAL INTO v_current FROM DUAL;
            WHILE v_current <= v_target LOOP
                SELECT SEQ_CANTON.NEXTVAL INTO v_current FROM DUAL;
            END LOOP;

            SELECT NVL(MAX(PARROQUIAID), 0) INTO v_target FROM PARROQUIAS;
            SELECT SEQ_PARROQUIA.NEXTVAL INTO v_current FROM DUAL;
            WHILE v_current <= v_target LOOP
                SELECT SEQ_PARROQUIA.NEXTVAL INTO v_current FROM DUAL;
            END LOOP;
        END;
        /
        """
    )


def _collect_manual_sql() -> list[Path]:
    available: list[Path] = []
    for filename in MANUAL_SQL_FILES:
        for directory in MANUAL_SQL_DIRS:
            candidate = directory / filename
            if candidate.exists() and candidate.stat().st_size > 0:
                available.append(candidate)
                break
        else:
            return []
    return available


def _combine_manual_sql(paths: list[Path], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as fh:
        fh.write("-- Jerarquia importada desde scripts manuales\n")
        for path in paths:
            content = path.read_text(encoding="utf-8")
            fh.write(f"-- Combinando {path.name}\n")
            fh.write(content)
            if not content.endswith("\n"):
                fh.write("\n")


def _build_sql_from_csv(provinces: list[Province], cantons: list[Canton], parroquias: list[Parroquia]) -> list[str]:
    lines: list[str] = [
        "-- Jerarquia generada automaticamente desde CSV",
        "DELETE FROM PARROQUIAS;",
        "DELETE FROM CANTONES;",
        "DELETE FROM PROVINCIAS;",
        "COMMIT;",
    ]

    for province in provinces:
        lines.append(
            "INSERT INTO PROVINCIAS (PROVINCIAID, CODIGO, NOMBRE) "
            f"VALUES ({province.provinciaid}, {_escape(province.codigo)}, {_escape(province.nombre)});"
        )

    lines.append("")

    for canton in cantons:
        lines.append(
            "INSERT INTO CANTONES (CANTONID, PROVINCIAID, CODIGO, NOMBRE) "
            f"VALUES ({canton.cantonid}, {canton.provinciaid}, {_escape(canton.codigo)}, {_escape(canton.nombre)});"
        )

    lines.append("")

    for parish in parroquias:
        lines.append(
            "INSERT INTO PARROQUIAS (PARROQUIAID, CANTONID, CODIGO, NOMBRE) "
            f"VALUES ({parish.parroquiaid}, {parish.cantonid}, {_escape(parish.codigo)}, {_escape(parish.nombre)});"
        )

    lines.append("COMMIT;")
    lines.append("")
    lines.append(_generate_sequence_alignment_block().strip())
    return lines


def generate_jerarquia_sql(
    source: Optional[Path] = None,
    output: Optional[Path] = None,
) -> dict[str, Optional[Path] | str | int]:
    source_dir = source or DEFAULT_SOURCE_DIR
    if source is not None and not source_dir.exists():
        raise FileNotFoundError(f"No se encontro el directorio de jerarquia: {source_dir}")

    source_dir.mkdir(parents=True, exist_ok=True)
    output_path = output or OUTPUT_FILE

    manual_paths = _collect_manual_sql()
    if manual_paths:
        _combine_manual_sql(manual_paths, output_path)
        return {
            "status": "ok",
            "sql": output_path,
            "provincias": None,
            "cantones": None,
            "parroquias": None,
            "source": source_dir,
        }

    provincias_rows = _load_csv(source_dir / "provincias.csv", ("CODIGO", "NOMBRE"))
    cantones_rows = _load_csv(source_dir / "cantones.csv", ("CODIGO", "PROVINCIA_CODIGO", "NOMBRE"))
    parroquias_rows = _load_csv(source_dir / "parroquias.csv", ("CODIGO", "CANTON_CODIGO", "NOMBRE"))

    if not provincias_rows or not cantones_rows or not parroquias_rows:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8") as fh:
            fh.write("-- No se encontraron archivos de jerarquia validos.\n")
            fh.write(f"-- Agrega provincias.csv, cantones.csv y parroquias.csv en {source_dir}\n")
        return {"status": "missing", "sql": output_path, "source": source_dir}

    provinces: list[Province] = []
    province_map: dict[str, int] = {}
    province_id = 1
    for row in sorted(provincias_rows, key=lambda item: item["CODIGO"]):
        codigo = row["CODIGO"]
        nombre = row["NOMBRE"]
        if not codigo or not nombre or codigo in province_map:
            continue
        province_map[codigo] = province_id
        provinces.append(Province(provinciaid=province_id, codigo=codigo, nombre=nombre))
        province_id += 1

    cantons: list[Canton] = []
    canton_map: dict[str, int] = {}
    canton_id = 1
    for row in sorted(cantones_rows, key=lambda item: item["CODIGO"]):
        codigo = row["CODIGO"]
        nombre = row["NOMBRE"]
        provincia_codigo = row["PROVINCIA_CODIGO"]
        province_id_ref = province_map.get(provincia_codigo)
        if not codigo or not nombre or not province_id_ref:
            continue
        canton_map[codigo] = canton_id
        cantons.append(Canton(cantonid=canton_id, provinciaid=province_id_ref, codigo=codigo, nombre=nombre))
        canton_id += 1

    parroquias: list[Parroquia] = []
    parroquia_id = 1
    for row in sorted(parroquias_rows, key=lambda item: item["CODIGO"]):
        codigo = row["CODIGO"]
        nombre = row["NOMBRE"]
        canton_codigo = row["CANTON_CODIGO"]
        canton_id_ref = canton_map.get(canton_codigo)
        if not codigo or not nombre or not canton_id_ref:
            continue
        parroquias.append(Parroquia(parroquiaid=parroquia_id, cantonid=canton_id_ref, codigo=codigo, nombre=nombre))
        parroquia_id += 1

    sql_lines = _build_sql_from_csv(provinces, cantons, parroquias)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as fh:
        fh.write("\n".join(sql_lines))
        fh.write("\n")

    return {
        "status": "ok",
        "sql": output_path,
        "provincias": len(provinces),
        "cantones": len(cantons),
        "parroquias": len(parroquias),
        "source": source_dir,
    }


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Genera los INSERTs de jerarquia geografica desde CSV.")
    parser.add_argument("--source", type=Path, help="Directorio con provincias/cantones/parroquias.")
    parser.add_argument(
        "--output",
        type=Path,
        help="Ruta de salida del SQL combinado (por defecto data/output/jerarquia/insert_jerarquia.sql).",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> None:
    args = _parse_args(argv)
    result = generate_jerarquia_sql(source=args.source, output=args.output)
    if result["status"] == "ok":
        provincias = result["provincias"] or "manual"
        cantones = result["cantones"] or "manual"
        parroquias = result["parroquias"] or "manual"
        print(
            f"Jerarquia generada: provincias={provincias}, "
            f"cantones={cantones}, parroquias={parroquias}. SQL: {result['sql']}"
        )
    else:
        print(
            "No se encontraron datos de jerarquia. "
            f"Coloca los CSV en {result['source']} y vuelve a ejecutar."
        )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Descarga o lee la lista de ciudades de Ecuador y genera archivos CSV/SQL.

El módulo se separa en funciones reutilizables para permitir que otros
scripts (p.ej. un orquestador ETL) lo llamen de forma programática sin
tener que recrear la lógica de CLI.
"""

from __future__ import annotations

import argparse
import csv
import io
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional
from urllib.parse import urljoin
from zipfile import ZipFile

DESCARGAS_URL = "https://carta-natal.es/descargas/coordenadas.php"
DEFAULT_ZIP_PATTERN = "https://carta-natal.es/descargas/ciudades/{code}.zip"
DEFAULT_CODE = "EC"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
RAW_CITY_DIR = RAW_DIR / "ciudades"
OUTPUT_DIR = DATA_DIR / "output" / "ciudades"
DEFAULT_CSV = OUTPUT_DIR / "ciudades_ec.csv"
DEFAULT_SQL = OUTPUT_DIR / "insert_ciudad.sql"


def local_source_path(code: str) -> Path:
    """Devuelve la ruta del TXT local asociado al código ISO solicitado."""
    return RAW_CITY_DIR / f"{code.upper()}.txt"


@dataclass
class CiudadRow:
    ciudadid: int
    nombre: str
    provincia: str
    latitud: Optional[float]
    longitud: Optional[float]
    zona_horaria: str


def find_download_url(html: str, code: str) -> str:
    pattern = re.compile(r'href="([^\"]+{code}[^\"]+)"[^>]*>[^<]*Descargar archivo\s+{code}'.format(code=code), re.IGNORECASE)
    match = pattern.search(html)
    if match:
        return urljoin(DESCARGAS_URL, match.group(1))
    return DEFAULT_ZIP_PATTERN.format(code=code.upper())


def decode_bytes(raw: bytes) -> str:
    for encoding in ("utf-8", "latin-1", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", errors="ignore")


def sniff_delimiter(sample: str) -> str:
    for delimiter in (";", ",", "|", "\t"):
        if delimiter in sample:
            return delimiter
    return ";"


def normalize_float(value: str) -> Optional[float]:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    value = value.replace(",", ".")
    try:
        return float(value)
    except ValueError:
        return None


def read_zip_payload(payload: bytes, code: str) -> str:
    with ZipFile(io.BytesIO(payload)) as zf:
        names = zf.namelist()
        if not names:
            raise RuntimeError("El ZIP está vacío")
        target = next((n for n in names if n.lower().startswith(code.lower())), names[0])
        with zf.open(target) as fh:
            return decode_bytes(fh.read())


def load_from_source(source: Path, code: str) -> str:
    """
    Lee datos desde un archivo local. Si es ZIP, extrae el primer archivo (o el que
    comience con el código ISO). Si es texto plano, lo decodifica.
    """

    payload = source.read_bytes()
    if source.suffix.lower() == ".zip":
        return read_zip_payload(payload, code)
    return decode_bytes(payload)


def parse_ciudades(text: str) -> List[dict]:
    cleaned_lines = [line for line in text.splitlines() if line.strip()]
    if not cleaned_lines:
        return []
    sample = "\n".join(cleaned_lines[:10])
    delimiter = sniff_delimiter(sample)
    reader = csv.reader(io.StringIO("\n".join(cleaned_lines)), delimiter=delimiter)
    rows = list(reader)
    if not rows:
        return []

    header = [col.strip().lower() for col in rows[0]]
    def looks_like_header(cols: Iterable[str]) -> bool:
        return any(col.isalpha() for col in cols)

    has_header = looks_like_header(header)
    data_rows = rows[1:] if has_header else rows
    if not has_header:
        header = [f"col_{idx}" for idx in range(len(rows[0]))]

    def get_index(*candidates: str) -> Optional[int]:
        lowered = [col.lower() for col in header]
        for candidate in candidates:
            if candidate in lowered:
                return lowered.index(candidate)
        return None

    idx_city = get_index("ciudad", "city", "poblacion", "nombre", "localidad") or 0
    idx_prov = get_index("estado", "provincia", "region", "departamento", "state")
    idx_lat = get_index("lat", "latitud", "latitude")
    idx_lon = get_index("lon", "longitud", "longitude")
    idx_tz = get_index("zona", "timezone", "tz", "gmt")

    parsed: List[dict] = []
    for row in data_rows:
        if idx_city >= len(row):
            continue
        nombre = row[idx_city].strip().title()
        if not nombre:
            continue
        provincia = row[idx_prov].strip().title() if idx_prov is not None and idx_prov < len(row) else ""
        latitud = normalize_float(row[idx_lat]) if idx_lat is not None and idx_lat < len(row) else None
        longitud = normalize_float(row[idx_lon]) if idx_lon is not None and idx_lon < len(row) else None
        zona = row[idx_tz].strip() if idx_tz is not None and idx_tz < len(row) else ""
        parsed.append({
            "nombre": nombre,
            "provincia": provincia,
            "latitud": latitud,
            "longitud": longitud,
            "zona_horaria": zona,
        })
    return parsed


def to_sql_literal(value: Optional[str]) -> str:
    if value is None:
        return "NULL"
    escaped = value.replace("'", "''")
    return f"'{escaped}'"


def write_csv(rows: List[CiudadRow], path: Path) -> None:
    fieldnames = ["ciudadid", "nombre", "provincia", "latitud", "longitud", "zona_horaria"]
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "ciudadid": row.ciudadid,
                "nombre": row.nombre,
                "provincia": row.provincia,
                "latitud": row.latitud or "",
                "longitud": row.longitud or "",
                "zona_horaria": row.zona_horaria,
            })


def write_sql(rows: List[CiudadRow], path: Path) -> None:
    with path.open("w", encoding="utf-8") as fh:
        fh.write("-- INSERTS generados automáticamente para la tabla CIUDAD\n")
        fh.write("-- Revisar antes de ejecutar\n\n")
        for row in rows:
            fh.write(
                "INSERT INTO CIUDAD (CIUDADID, NOMBRE, PROVINCIA, LATITUD, LONGITUD, ZONA_HORARIA) "
                f"VALUES ({row.ciudadid}, {to_sql_literal(row.nombre)}, {to_sql_literal(row.provincia)}, "
                f"{row.latitud if row.latitud is not None else 'NULL'}, {row.longitud if row.longitud is not None else 'NULL'}, "
                f"{to_sql_literal(row.zona_horaria)});\n"
            )


def generate_catalog(
    code: str = DEFAULT_CODE,
    csv_path: Path = DEFAULT_CSV,
    sql_path: Path = DEFAULT_SQL,
    source_path: Optional[Path] = None,
) -> int:
    """Genera archivos CSV/SQL con el catálogo de ciudades.

    Args:
        code: Código ISO del país (EC por defecto).
        csv_path: Ruta de salida para el CSV normalizado.
        sql_path: Ruta de salida para el archivo de INSERTs.
        source_path: Ruta local (TXT o ZIP) opcional; si no se pasa se
            detecta `data/raw/ciudades/<code>.txt` y, si no existe, se
            descarga desde carta-natal.es.

    Returns:
        Número de filas generadas.
    """

    country_code = code.upper()

    selected_source = source_path
    if selected_source is None:
        candidate = local_source_path(country_code)
        if candidate.exists():
            selected_source = candidate

    if selected_source:
        text = load_from_source(selected_source, country_code)
    else:
        import requests

        session = requests.Session()
        html = session.get(DESCARGAS_URL, timeout=30).text
        download_url = find_download_url(html, country_code)
        payload = session.get(download_url, timeout=60)
        payload.raise_for_status()
        text = read_zip_payload(payload.content, country_code)

    parsed = parse_ciudades(text)
    if not parsed:
        raise RuntimeError("No se pudo interpretar el contenido descargado")

    rows = [
        CiudadRow(idx + 1, item["nombre"], item["provincia"], item["latitud"], item["longitud"], item["zona_horaria"])
        for idx, item in enumerate(parsed)
    ]

    csv_path.parent.mkdir(parents=True, exist_ok=True)
    sql_path.parent.mkdir(parents=True, exist_ok=True)
    write_csv(rows, csv_path)
    write_sql(rows, sql_path)
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Descarga y prepara catálogo de ciudades de Ecuador")
    parser.add_argument("--code", default=DEFAULT_CODE, help="Código ISO del país (default: EC)")
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="Ruta de salida para el CSV")
    parser.add_argument("--sql", type=Path, default=DEFAULT_SQL, help="Ruta de salida para el archivo SQL")
    parser.add_argument(
        "--source",
        type=Path,
        help="Ruta local (TXT o ZIP) para usar en lugar de descargar desde carta-natal.es",
    )
    args = parser.parse_args()

    count = generate_catalog(code=args.code, csv_path=args.csv, sql_path=args.sql, source_path=args.source)
    print(f"Se generaron {count} registros en {args.csv} y {args.sql}")


if __name__ == "__main__":
    main()

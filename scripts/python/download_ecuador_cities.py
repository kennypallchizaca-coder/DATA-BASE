"""
Genera el catalogo de ciudades de Ecuador a partir del dump de GeoNames (EC.zip).
Produce dos archivos en data/output/ciudades/:
 - ciudades_ec.csv
 - insert_ciudad.sql (INSERTs listos para Oracle)

El script busca primero un archivo local (data/raw/ciudades/EC.txt o EC.zip).
Si no existe, descarga EC.zip y admin1CodesASCII.txt para enriquecer la provincia.
"""

from __future__ import annotations

import argparse
import csv
import io
import sys
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional

COUNTRY_CODE = "EC"
GEONAMES_ZIP_URL = "https://download.geonames.org/export/dump/{code}.zip"
GEONAMES_ADMIN1_URL = "https://download.geonames.org/export/dump/admin1CodesASCII.txt"


@dataclass
class CityRow:
    ciudadid: Optional[int]
    nombre: str
    provincia: Optional[str]
    latitud: Optional[float]
    longitud: Optional[float]
    zona_horaria: Optional[str]


def _root_dir() -> Path:
    return Path(__file__).resolve().parents[2]


def download_file(url: str, dest: Path) -> Path:
    """Descarga un archivo binario y lo guarda en dest."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url) as resp, open(dest, "wb") as fh:
        fh.write(resp.read())
    return dest


def load_admin1_lookup(raw_dir: Path) -> dict[str, str]:
    """
    Devuelve un diccionario code->nombre para provincias (admin1).
    Usa cache local; si no existe descarga el archivo.
    """
    path = raw_dir / "admin1CodesASCII.txt"
    if not path.exists():
        download_file(GEONAMES_ADMIN1_URL, path)

    lookup: dict[str, str] = {}
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                lookup[parts[0]] = parts[1]
    return lookup


def _iter_geonames_lines_from_zip(path: Path) -> Iterable[str]:
    with zipfile.ZipFile(path, "r") as zf:
        target = next(
            (
                n
                for n in zf.namelist()
                if n.lower().endswith(f"{path.stem.lower()}.txt")
            ),
            None,
        )
        if target is None:
            target = next((n for n in zf.namelist() if n.lower().endswith(".txt")), None)
        if target is None:
            raise ValueError(f"No se encontro archivo .txt dentro de {path}")
        with zf.open(target) as fh:
            for line in io.TextIOWrapper(fh, encoding="utf-8"):
                yield line


def _iter_geonames_lines_from_txt(path: Path) -> Iterable[str]:
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            yield line


def parse_geonames(source: Path, country_code: str, admin_lookup: dict[str, str]) -> List[CityRow]:
    """
    Filtra filas de GeoNames (clase P) y devuelve CityRow.
    GeoNames separa por tabs; la columna admin1 (parts[10]) contiene el codigo de provincia.
    """
    if source.suffix.lower() == ".zip":
        lines = _iter_geonames_lines_from_zip(source)
    else:
        lines = _iter_geonames_lines_from_txt(source)

    rows: List[CityRow] = []
    for line in lines:
        parts = line.strip().split("\t")
        if len(parts) < 19:
            continue

        feature_class = parts[6]
        if feature_class != "P":  # solo lugares poblados
            continue

        province_code = parts[10].strip()
        province_key = f"{country_code}.{province_code}" if province_code else ""
        province_name = admin_lookup.get(province_key, province_code or None)

        try:
            lat = float(parts[4])
            lon = float(parts[5])
        except ValueError:
            lat = lon = None

        rows.append(
            CityRow(
                ciudadid=None,
                nombre=parts[1].strip(),
                provincia=province_name,
                latitud=lat,
                longitud=lon,
                zona_horaria=parts[17].strip() or None,
            )
        )

    return rows


def deduplicate(rows: List[CityRow]) -> List[CityRow]:
    """Elimina duplicados por nombre+provincia para evitar ciudades repetidas."""
    seen = set()
    unique: List[CityRow] = []
    for row in rows:
        key = (row.nombre.lower(), (row.provincia or "").lower())
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)
    return unique


def write_csv(rows: List[CityRow], path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["ciudadid", "nombre", "provincia", "latitud", "longitud", "zona_horaria"])
        for row in rows:
            writer.writerow(
                [
                    row.ciudadid,
                    row.nombre,
                    row.provincia,
                    row.latitud,
                    row.longitud,
                    row.zona_horaria,
                ]
            )
    return path


def _sql_value(value: Optional[str | float]) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    return str(value)


def write_sql_inserts(rows: List[CityRow], path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        fh.write("-- Inserts generados automaticamente para la tabla CIUDAD\n")
        fh.write("DELETE FROM CIUDAD;\n")
        for row in rows:
            fh.write(
                "INSERT INTO CIUDAD (CIUDADID, NOMBRE, PROVINCIA, LATITUD, LONGITUD, ZONA_HORARIA) "
                f"VALUES ({row.ciudadid}, {_sql_value(row.nombre)}, {_sql_value(row.provincia)}, "
                f"{_sql_value(row.latitud)}, {_sql_value(row.longitud)}, {_sql_value(row.zona_horaria)});\n"
            )
        fh.write("COMMIT;\n")
    return path


def generate_catalog(
    code: str = COUNTRY_CODE,
    source: Optional[Path] = None,
    csv_output: Optional[Path] = None,
    sql_output: Optional[Path] = None,
) -> dict[str, str | int | Path]:
    root = _root_dir()
    raw_dir = root / "data" / "raw" / "ciudades"
    raw_dir.mkdir(parents=True, exist_ok=True)

    if source is None:
        # Preferir archivos locales para evitar descarga si ya existen.
        candidate_txt = raw_dir / f"{code}.txt"
        candidate_zip = raw_dir / f"{code}.zip"
        if candidate_txt.exists():
            source = candidate_txt
        elif candidate_zip.exists():
            source = candidate_zip
        else:
            url = GEONAMES_ZIP_URL.format(code=code)
            source = download_file(url, candidate_zip)
    else:
        source = Path(source)
        if not source.exists():
            raise FileNotFoundError(f"No se encontro el archivo de ciudades: {source}")

    admin_lookup = load_admin1_lookup(raw_dir)
    rows = parse_geonames(source, code, admin_lookup)
    rows = deduplicate(rows)
    # Orden estable: provincia -> nombre.
    rows.sort(key=lambda r: (r.provincia or "", r.nombre))

    for idx, row in enumerate(rows, start=1):
        row.ciudadid = idx

    csv_path = csv_output or (root / "data" / "output" / "ciudades" / f"ciudades_{code.lower()}.csv")
    sql_path = sql_output or (root / "data" / "output" / "ciudades" / "insert_ciudad.sql")

    write_csv(rows, csv_path)
    write_sql_inserts(rows, sql_path)

    return {"total_ciudades": len(rows), "csv": csv_path, "sql": sql_path, "source": source}


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Genera catalogo de ciudades de Ecuador desde GeoNames.")
    parser.add_argument("--code", default=COUNTRY_CODE, help="Codigo ISO del pais (default EC).")
    parser.add_argument("--source", type=Path, help="Ruta a EC.txt/EC.zip local para evitar descarga.")
    parser.add_argument("--csv", type=Path, help="Ruta de salida para el CSV.")
    parser.add_argument("--sql", type=Path, help="Ruta de salida para los INSERTs SQL.")
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> None:
    args = _parse_args(argv)
    result = generate_catalog(code=args.code, source=args.source, csv_output=args.csv, sql_output=args.sql)
    print(
        f"Ciudades procesadas: {result['total_ciudades']}\n"
        f"CSV: {result['csv']}\n"
        f"SQL: {result['sql']}\n"
        f"Fuente: {result['source']}"
    )


if __name__ == "__main__":
    main(sys.argv[1:])

"""Crea los CSV de provincias/cantones/parroquias a partir de los scripts SQL incluidos."""

from __future__ import annotations

import csv
import re
from collections import defaultdict, OrderedDict
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parents[3]
SQL_DIR = ROOT / "data" / "Datos-Geograficos-Ecuador"
OUTPUT_DIR = ROOT / "data" / "raw" / "jerarquia"


def _extract_rows(path: Path, expected_columns: int) -> List[List[str]]:
    text = path.read_text(encoding="latin-1")
    marker = "VALUES"
    idx = text.upper().find(marker)
    if idx == -1:
        raise ValueError(f"No se encontro la clausula VALUES en {path}")
    body = text[idx + len(marker) :].strip()
    body = body.rstrip(";")
    fragments = re.split(r"\),\s*", body)
    rows: List[List[str]] = []
    for fragment in fragments:
        fragment = fragment.strip()
        if fragment.endswith(")"):
            fragment = fragment[:-1]
        if fragment.startswith("("):
            fragment = fragment[1:]
        if not fragment:
            continue
        reader = csv.reader([fragment], delimiter=",", quotechar="'", skipinitialspace=True)
        parsed = next(reader)
        if len(parsed) != expected_columns:
            continue
        rows.append([value.strip() for value in parsed])
    return rows


def build_geo_csv() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    provinces = _extract_rows(SQL_DIR / "provincias.sql", 2)
    cantons = _extract_rows(SQL_DIR / "cantones.sql", 3)
    parishes = _extract_rows(SQL_DIR / "parroquias.sql", 3)

    provinces_map: OrderedDict[int, str] = OrderedDict()
    for prov_id_str, name in provinces:
        prov_id = int(prov_id_str)
        provinces_map[prov_id] = name

    canton_order: List[tuple[str, str, str]] = []
    canton_by_id: dict[int, tuple[str, str]] = {}
    province_counters: defaultdict[int, int] = defaultdict(int)

    for canton_id_str, name, province_id_str in cantons:
        canton_id = int(canton_id_str)
        province_id = int(province_id_str)
        province_code = f"{province_id:02d}"
        province_counters[province_id] += 1
        canton_code = f"{province_code}{province_counters[province_id]:02d}"
        canton_by_id[canton_id] = (canton_code, province_code)
        canton_order.append((canton_code, province_code, name))

    parish_order: List[tuple[str, str, str]] = []
    parish_counters: defaultdict[str, int] = defaultdict(int)
    for _, name, canton_id_str in parishes:
        canton_id = int(canton_id_str)
        if canton_id not in canton_by_id:
            continue
        canton_code, _ = canton_by_id[canton_id]
        parish_counters[canton_code] += 1
        parish_code = f"{canton_code}{parish_counters[canton_code]:02d}"
        parish_order.append((parish_code, canton_code, name))

    with (OUTPUT_DIR / "provincias.csv").open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["CODIGO", "NOMBRE"])
        for prov_id, name in provinces_map.items():
            writer.writerow([f"{prov_id:02d}", name])

    with (OUTPUT_DIR / "cantones.csv").open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["CODIGO", "PROVINCIA_CODIGO", "NOMBRE"])
        for code, province_code, name in canton_order:
            writer.writerow([code, province_code, name])

    with (OUTPUT_DIR / "parroquias.csv").open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["CODIGO", "CANTON_CODIGO", "NOMBRE"])
        for code, canton_code, name in parish_order:
            writer.writerow([code, canton_code, name])

    print(
        f"CSV generados: provincias={len(provinces_map)}, cantones={len(canton_order)}, parroquias={len(parish_order)}"
    )


if __name__ == "__main__":
    build_geo_csv()

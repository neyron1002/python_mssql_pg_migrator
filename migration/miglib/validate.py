"""validate.py - Validacion integral origen (MSSQL) vs destino (PostgreSQL), 100% Python.

Sin sqlcmd/psql/CSV: introspecciona el esquema DESTINO (autoritativo) una sola vez
y aplica EL MISMO conjunto de metricas a ambos motores, comparando en memoria:

  - rowcount        -> nro de filas por tabla (deben coincidir exactamente)
  - sum:<col>       -> SUMA de cada columna numerica EXACTA (int2/4/8, numeric/money).
                       float/double (InvoiceDetail.Quantity) se EXCLUYE en ambos lados.
  - pkmin/pkmax:<c> -> MIN/MAX del PK entero -> preservacion 1:1 de identificadores.

El plan (columnas sumables + PK enteros + escala numerica) sale del esquema PG, asi
que ambos reportes son simetricos por construccion. La suma se compara como Decimal
(por valor, no por representacion): en MSSQL se castea a decimal(38, <escala PG>)
para no truncar ni desbordar; en PG se suma como numeric exacto.

Las 24 VISTAS quedan fuera (solo tablas base). Devuelve True si todo cuadra.

(Archivo en ASCII puro a proposito.)
"""
from __future__ import annotations

import csv
import os
from decimal import Decimal

from . import config

# Tipos PG considerados numericos EXACTOS (sumables). float/real -> NO.
_PG_SUMMABLE = ("smallint", "integer", "bigint", "numeric")


# ------------------------------------------------------------------- plan (PG)
def _pg_plan(pg):
    """[(tabla, [(col, scale)...] sumables, [pk_entero...])] desde el esquema PG."""
    tables = [r[0] for r in pg.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name"
    ).fetchall()]
    plan = []
    for t in tables:
        cols = pg.execute(
            "SELECT column_name, data_type, COALESCE(numeric_scale, 0) "
            "FROM information_schema.columns "
            "WHERE table_schema='public' AND table_name=%s ORDER BY ordinal_position",
            (t,)).fetchall()
        summ = [(name, int(scale)) for (name, dtype, scale) in cols if dtype in _PG_SUMMABLE]
        pk = [r[0] for r in pg.execute(
            "SELECT a.attname FROM pg_index i "
            "JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) "
            "JOIN pg_class cl ON cl.oid = i.indrelid "
            "JOIN pg_namespace n ON n.oid = cl.relnamespace "
            "JOIN pg_type ty ON ty.oid = a.atttypid "
            "WHERE n.nspname='public' AND cl.relname=%s AND i.indisprimary "
            "AND ty.typname IN ('int2','int4','int8') ORDER BY a.attnum",
            (t,)).fetchall()]
        plan.append((t, summ, pk))
    return plan


def _norm(v):
    """Normaliza un valor de metrica a Decimal, o '(empty)' para MIN/MAX de tabla vacia."""
    if v is None:
        return "(empty)"
    return Decimal(v)


# ------------------------------------------------------------------ reporte PG
def _pg_report(pg, plan):
    rep = {}
    for t, summ, pk in plan:
        select = ["count(*)"]
        labels = ["rowcount"]
        for name, _scale in summ:
            select.append("COALESCE(SUM(%s::numeric), 0)" % config.qi(name))
            labels.append("sum:" + name)
        for name in pk:
            select.append("MIN(%s)" % config.qi(name))
            labels.append("pkmin:" + name)
            select.append("MAX(%s)" % config.qi(name))
            labels.append("pkmax:" + name)
        row = pg.execute("SELECT %s FROM %s" % (", ".join(select), config.qi(t))).fetchone()
        for metric, val in zip(labels, row):
            rep[(t, metric)] = _norm(val)
    return rep


# --------------------------------------------------------------- reporte MSSQL
def _mssql_report(mssql, plan):
    rep = {}
    cur = mssql.cursor()
    for t, summ, pk in plan:
        select = ["COUNT_BIG(*)"]
        labels = ["rowcount"]
        for name, scale in summ:
            # castear a decimal con la MISMA escala del destino: exacto y sin desborde
            select.append("COALESCE(SUM(CAST([%s] AS decimal(38,%d))), 0)" % (name, scale))
            labels.append("sum:" + name)
        for name in pk:
            select.append("MIN([%s])" % name)
            labels.append("pkmin:" + name)
            select.append("MAX([%s])" % name)
            labels.append("pkmax:" + name)
        try:
            cur.execute("SELECT %s FROM [dbo].[%s]" % (", ".join(select), t))
            row = cur.fetchone()
        except Exception as e:  # noqa: BLE001 - tabla ausente/ilegible en el origen
            rep[(t, "ERROR")] = str(e).splitlines()[0][:140]
            continue
        for metric, val in zip(labels, row):
            rep[(t, metric)] = _norm(val)
    return rep


# ------------------------------------------------------------------- comparacion
def _compare(src, tgt):
    src_tbls = {k[0] for k in src}
    tgt_tbls = {k[0] for k in tgt}
    common = sorted(src_tbls & tgt_tbls)
    only_src = sorted(src_tbls - tgt_tbls)
    only_tgt = sorted(tgt_tbls - src_tbls)

    mismatches = []  # (tbl, metric, src, tgt, motivo)
    for key in sorted(set(src) | set(tgt)):
        tbl, metric = key
        if tbl in only_src or tbl in only_tgt:
            continue  # se reporta a nivel tabla
        sv, tv = src.get(key), tgt.get(key)
        if metric == "ERROR":
            mismatches.append((tbl, metric, str(sv), "-", "error leyendo el ORIGEN"))
            continue
        if sv is None:
            mismatches.append((tbl, metric, "-", str(tv), "metrica ausente en ORIGEN"))
        elif tv is None:
            mismatches.append((tbl, metric, str(sv), "-", "metrica ausente en DESTINO"))
        elif sv != tv:
            reason = "diff=%s" % (abs(sv - tv)) if isinstance(sv, Decimal) and isinstance(tv, Decimal) \
                else "texto distinto"
            mismatches.append((tbl, metric, str(sv), str(tv), reason))
    return common, only_src, only_tgt, mismatches


def _print_report(common, only_src, only_tgt, mismatches):
    bad = sorted({m[0] for m in mismatches})
    print("=" * 72)
    print("VALIDACION INTEGRAL  -  origen(MSSQL) vs destino(PostgreSQL)")
    print("=" * 72)
    print("Tablas en comun        : %d" % len(common))
    print("Tablas OK              : %d" % (len(common) - len(bad)))
    print("Tablas con discrepancia: %d" % len(bad))
    if only_src:
        print("\n[!] Solo en ORIGEN (no migradas): %s" % ", ".join(only_src))
    if only_tgt:
        print("\n[!] Solo en DESTINO (extra):      %s" % ", ".join(only_tgt))

    if mismatches:
        print("\n[X] %d discrepancia(s):" % len(mismatches))
        print("  %-34s %-22s %14s %14s  motivo"
              % ("tabla", "metrica", "origen", "destino"))
        print("  " + "-" * 100)
        for tbl, metric, sv, tv, reason in mismatches:
            print("  %-34.34s %-22.22s %14.14s %14.14s  %s" % (tbl, metric, sv, tv, reason))

    ok = not mismatches and not only_src and not only_tgt
    print("\n" + ("RESULTADO: PASS - migracion integra"
                  if ok else "RESULTADO: FAIL - revisar discrepancias arriba"))
    return ok


# ------------------------------------------------------------- detalle (--detail)
def _detail_rows(plan, src, tgt):
    """Filas granulares (una por tabla+metrica) origen vs destino, con estado.

    Devuelve [(tabla, metrica, origen, destino, estado)] para TODAS las metricas
    del plan (no solo las que discrepan) -> evidencia completa por tabla.
    """
    rows = []
    for t, summ, pk in plan:
        metrics = ["rowcount"]
        metrics += ["sum:" + name for name, _ in summ]
        for name in pk:
            metrics += ["pkmin:" + name, "pkmax:" + name]
        for metric in metrics:
            sv = src.get((t, metric))
            tv = tgt.get((t, metric))
            if (t, "ERROR") in src:
                estado = "ERROR-ORIGEN"
            elif sv is None or tv is None:
                estado = "AUSENTE"
            elif sv == tv:
                estado = "OK"
            else:
                estado = "DIFF"
            rows.append((t, metric,
                         "-" if sv is None else str(sv),
                         "-" if tv is None else str(tv),
                         estado))
    return rows


def _print_detail(plan, detail_rows):
    """Resumen legible por-tabla en consola (una linea por tabla base)."""
    by_tbl = {}
    for t, metric, sv, tv, estado in detail_rows:
        d = by_tbl.setdefault(t, {"rc": ("?", "?"), "sums": [0, 0],
                                  "pkmin": None, "pkmax": None, "diff": False})
        if estado in ("DIFF", "AUSENTE", "ERROR-ORIGEN"):
            d["diff"] = True
        if metric == "rowcount":
            d["rc"] = (sv, tv)
        elif metric.startswith("sum:"):
            d["sums"][1] += 1
            if estado == "OK":
                d["sums"][0] += 1
        elif metric.startswith("pkmin:"):
            d["pkmin"] = tv
        elif metric.startswith("pkmax:"):
            d["pkmax"] = tv

    print("\n" + "=" * 72)
    print("DETALLE POR TABLA  (origen=destino)")
    print("=" * 72)
    print("  %-38s %-21s %-9s %-17s %s"
          % ("tabla", "filas", "sumas", "PK rango", "estado"))
    print("  " + "-" * 96)
    for t in sorted(by_tbl):
        d = by_tbl[t]
        so, st = d["rc"]
        filas = ("%s = %s" % (so, st)) if so == st else ("%s != %s" % (so, st))
        sums = ("%d/%d" % (d["sums"][0], d["sums"][1])) if d["sums"][1] else "-"
        if d["pkmin"] not in (None, "(empty)"):
            pkr = "%s..%s" % (d["pkmin"], d["pkmax"])
        else:
            pkr = "-"
        estado = "DIFF" if d["diff"] else "OK"
        print("  %-38.38s %-21s %-9s %-17.17s %s" % (t, filas, sums, pkr, estado))


def _write_csv(detail_rows, path):
    """Vuelca todas las metricas (evidencia archivable) a un CSV."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["tabla", "metrica", "origen", "destino", "estado"])
        for row in detail_rows:
            w.writerow(row)
    return path


def _out_dir():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # migration/
    return os.path.join(here, "out")


# ------------------------------------------------------------------------- API
def validate(detail=False):
    """Genera ambos reportes, compara e imprime. Devuelve True si todo cuadra.

    Con detail=True imprime ademas una tabla por-tabla (filas/sumas/PK, siempre,
    haya o no discrepancias) y vuelca todas las metricas a out/validation_report.csv
    como evidencia archivable.
    """
    pg = config.connect_pg()
    try:
        plan = _pg_plan(pg)
        tgt = _pg_report(pg, plan)
    finally:
        pg.close()

    mssql = config.connect_mssql()
    try:
        src = _mssql_report(mssql, plan)
    finally:
        mssql.close()

    common, only_src, only_tgt, mismatches = _compare(src, tgt)
    ok = _print_report(common, only_src, only_tgt, mismatches)

    if detail:
        rows = _detail_rows(plan, src, tgt)
        _print_detail(plan, rows)
        csv_path = _write_csv(rows, os.path.join(_out_dir(), "validation_report.csv"))
        print("\n==> Evidencia detallada (%d metricas) escrita en: %s"
              % (len(rows), csv_path))
    return ok

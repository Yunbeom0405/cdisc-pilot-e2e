"""Trial design domains (TA, TE, TV, TI, TS) for SDTMIG 3.4.

Starting point is the PHUSE TestDataFactory trial design datasets (SDTMIG 3.2),
adapted to SDTMIG 3.4 / SDTM v2.0 and CDISC CT 2026-03-27. TA, TE, TV and TI have
no structural change between 3.2 and 3.4 and pass through as-is. TS changes:

- AGESPAN removed (no longer a TSPARMCD term in current CT).
- SDTIGVER / SDTMVER added.
- TSPARM text aligned to current CT (INDIC, TINDTP).
- TSVALCD / TSVCDREF / TSVCDVER populated for every CDISC-coded value.
- TTYPE TSSEQ renumbered 1-3 (source skipped 3).
- PCLAS value left blank: the source class (NDF-RT, retired) does not fit xanomeline.

TV changes (study VISITNUM scheme): telephone visits 8.1-11.1 -> 8.5-11.5 so that
unscheduled visits can take previous visit + .1; 501 is the CRF's Adverse Event Follow-up
visit (source label 'Rash followup'), so the unused 101 AE FOLLOW-UP row is dropped.

Source files (MIT license): github.com/phuse-org/phuse-scripts, data/sdtm/TDF_SDTM_v1.0.
Place ta/te/tv/ti/ts.xpt in data/source/tdf/.

Run from project root: python python/trial_design.py
"""
from pathlib import Path

import pandas as pd
import pyreadstat

SRC = Path("data/source/tdf")
OUT = Path("data/derived/sdtm")
CT_VER = "2026-03-27"
LABELS = {"ta": "Trial Arms", "te": "Trial Elements", "tv": "Trial Visits",
          "ti": "Trial Inclusion/Exclusion Criteria", "ts": "Trial Summary"}

# CDISC CT codes for coded TS values
TS_CODES = {
    ("TBLIND", "DOUBLE BLIND"): "C15228",
    ("TCNTRL", "PLACEBO"): "C49648",
    ("TPHASE", "PHASE II TRIAL"): "C15601",
    ("TTYPE", "SAFETY"): "C49667",
    ("TTYPE", "EFFICACY"): "C49666",
    ("TTYPE", "PHARMACOKINETIC"): "C49663",
    ("SEXPOP", "BOTH"): "C49636",
    ("TINDTP", "TREATMENT"): "C49656",
    ("INTMODEL", "PARALLEL"): "C82639",
    ("STYPE", "INTERVENTIONAL"): "C98388",
    ("INTTYPE", "DRUG"): "C1909",
    ("ROUTE", "TRANSDERMAL"): "C38305",
    ("DOSFRQ", "QD"): "C25473",
    ("DOSU", "mg"): "C28253",
    ("ADDON", "N"): "C49487",
    ("RANDOM", "Y"): "C49488",
    ("ADAPT", "N"): "C49487",
    ("HLTSUBJI", "N"): "C49487",
}

TSPARM_CT = {
    "INDIC": "Trial Disease/Condition Indication",
    "TINDTP": "Trial Intent Type",
}


def read(name):
    df, meta = pyreadstat.read_xport(SRC / f"{name}.xpt", encoding="latin1")
    return df, meta


def write(df, meta, name):
    labels = [meta.column_names_to_labels.get(c, c) for c in df.columns]
    pyreadstat.write_xport(df, OUT / f"{name}.xpt", table_name=name.upper(),
                           file_label=LABELS[name], column_labels=labels,
                           file_format_version=5)


def build_ts(ts):
    ts = ts[ts.TSPARMCD != "AGESPAN"].copy()

    ts.loc[ts.TSPARMCD == "TTYPE", "TSSEQ"] = range(1, (ts.TSPARMCD == "TTYPE").sum() + 1)
    ts["TSPARM"] = ts.TSPARMCD.map(TSPARM_CT).fillna(ts.TSPARM)
    ts.loc[ts.TSPARMCD == "PCLAS", ["TSVAL", "TSVALCD", "TSVCDREF"]] = ""

    for (parm, val), code in TS_CODES.items():
        hit = (ts.TSPARMCD == parm) & (ts.TSVAL == val)
        assert hit.sum() == 1, (parm, val)
        ts.loc[hit, ["TSVALCD", "TSVCDREF", "TSVCDVER"]] = [code, "CDISC", CT_VER]

    new = pd.DataFrame({
        "STUDYID": "CDISCPILOT01", "DOMAIN": "TS", "TSSEQ": 1.0,
        "TSPARMCD": ["SDTIGVER", "SDTMVER"],
        "TSPARM": ["SDTM IG Version", "SDTM Version"],
        "TSVAL": ["3.4", "2.0"],
    })
    return pd.concat([ts, new], ignore_index=True).fillna("")


def build_tv(tv):
    tv = tv[tv.VISITNUM != 101].copy()
    tel = tv.VISIT.str.endswith("(T)")
    tv.loc[tel, "VISITNUM"] = tv.loc[tel, "VISITNUM"].round() + 0.5
    tv.loc[tv.VISITNUM == 501, "VISIT"] = "AE FOLLOW-UP"
    return tv


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ["ta", "te", "tv", "ti", "ts"]:
        df, meta = read(name)
        if name == "ts":
            df = build_ts(df)
        if name == "tv":
            df = build_tv(df)
        write(df, meta, name)
        print(f"{name}: {len(df)} records")

    out, _ = pyreadstat.read_xport(OUT / "ts.xpt")
    assert "AGESPAN" not in set(out.TSPARMCD)
    assert not out.duplicated(["TSPARMCD", "TSSEQ"]).any()
    assert (out.TSVCDREF == "CDISC").sum() == len(TS_CODES)


if __name__ == "__main__":
    main()

"""Generate EDC/IRT-style raw data for CDISCPILOT01 from the Pilot SDTM package.

Subjects, visit dates, events and dispositions come from the Pilot SDTM so that the
SDTM rebuilt from this raw layer can be compared against the Pilot. Fields the CRF
collects but the Pilot does not ship (birth date, consent date, initials, substance use)
are simulated with a fixed seed. Planted data issues are listed in docs/RAW-GEN-NOTES.md.

Run from the project root:  python python/generate_raw.py
"""
import random
from pathlib import Path

import pandas as pd
from faker import Faker

SRC = Path("data/source/cdisc-pilot/updated-pilot-submission-package/900172/m5/"
           "datasets/cdiscpilot01/tabulations/sdtm")
OUT = Path("raw")
random.seed(1609)
fake = Faker()
Faker.seed(1609)


def read(name):
    df = pd.read_sas(SRC / f"{name}.xpt", encoding="latin1")
    return df.fillna("") if name != "ex" else df


def edc_date(iso):
    """ISO 8601 (possibly partial) -> EDC display format 'DD MON YYYY' / 'UN MON YYYY'."""
    if not iso:
        return ""
    y, m, d = (iso.split("-") + ["", ""])[:3]
    mon = pd.Timestamp(int(y), int(m), 1).strftime("%b").upper() if m else "UNK"
    return f"{d or 'UN'} {mon} {y}"


def irt_ts(iso):
    return f"{iso}T{random.randint(8, 16):02d}:{random.randint(0, 59):02d}:{random.randint(0, 59):02d}"


def subject(usubjid):
    return usubjid[3:]  # '01-701-1015' -> '701-1015'


def folder(visitnum, visit):
    if visit.startswith("UNSCHEDULED"):
        return f"UNS{visitnum:g}"
    if "(T)" in visit:
        return f"V{int(visitnum)}T"
    return {3.5: "V3E", 101: "V501"}.get(visitnum, f"V{int(visitnum)}")


dm, sv, sc, ae, mh, ds, ex = (read(n) for n in ("dm", "sv", "sc", "ae", "mh", "ds", "ex"))
relrec, suppds = read("relrec"), read("suppds")
OUT.mkdir(exist_ok=True)

# --- visits: one row per visit folder -------------------------------------------------
visits = pd.DataFrame({
    "SUBJECT": sv.USUBJID.map(subject),
    "FOLDER": [folder(n, v) for n, v in zip(sv.VISITNUM, sv.VISIT)],
    "VISIT_DATE": sv.SVSTDTC.map(edc_date),
})
scr1 = sv[sv.VISITNUM == 1].set_index("USUBJID").SVSTDTC

# --- dm: Visit 1 identification, consent, demographics (CRF p7) ----------------------
ORIGIN = {"WHITE": "CA", "BLACK OR AFRICAN AMERICAN": "AF", "ASIAN": "EA",
          "AMERICAN INDIAN OR ALASKA NATIVE": "O"}
rows = []
for r in dm.itertuples():
    v1 = pd.Timestamp(scr1[r.USUBJID])
    consent = v1 - pd.Timedelta(days=random.choice([0, 0, 0, 1, 2, 5, 7]))
    # birthday falls in the year before consent so that AGE at consent == Pilot AGE
    birth = consent - pd.DateOffset(years=int(r.AGE)) - pd.Timedelta(days=random.randint(1, 364))
    rows.append({
        "SUBJECT": subject(r.USUBJID), "SITE": r.SITEID, "FOLDER": "V1",
        "INITIALS": fake.first_name()[0] + random.choice(["-", fake.first_name()[0]]) + fake.last_name()[0],
        "VISIT_DATE": edc_date(v1.date().isoformat()),
        "CONSENT_DATE": edc_date(consent.date().isoformat()),
        "BIRTH_DATE": edc_date(birth.date().isoformat()),
        "SEX": r.SEX,
        "ORIGIN": "HP" if r.ETHNIC == "HISPANIC OR LATINO" else ORIGIN[r.RACE],
    })
dm_raw = pd.DataFrame(rows)

# --- sc_su: education, smoking, alcohol (CRF p8) -------------------------------------
edu = sc.set_index("USUBJID").SCORRES
rows = []
for r in dm.itertuples():
    smoker = random.random()  # < .15 current, < .40 former, else never
    cig = lambda: str(random.choice([5, 10, 10, 20, 20, 30])) if smoker < .15 else "0"
    rows.append({
        "SUBJECT": subject(r.USUBJID), "FOLDER": "V1",
        "VISIT_DATE": edc_date(scr1[r.USUBJID]),
        "EDU_YEARS": edu.get(r.USUBJID, str(random.randint(8, 18))),
        "SMOK_NOT_OBTAINED": "",
        "CIGARETTES_DAY": cig(),
        "CIGARS_DAY": "L" if smoker < .02 else "0",
        "PIPES_DAY": "0",
        "SMOK_YEARS": str(random.randint(5, 50)) if smoker < .40 else "0",
        "SMOK_QUIT_MMYY": (f"{random.randint(1, 12):02d}/{random.randint(75, 99):02d}"
                           if .15 <= smoker < .40 else ""),
        "ALC_NOT_OBTAINED": "",
        "BEER_WEEK": random.choice(["0", "0", "0", "L", "2", "6"]),
        "WINE_WEEK": random.choice(["0", "0", "L", "1", "3", "7"]),
        "SPIRITS_WEEK": random.choice(["0", "0", "0", "0", "L", "2"]),
    })
sc_su = pd.DataFrame(rows)

# --- ae: Pre-existing Conditions and Study Adverse Events log (CRF p121-123) ---------
SER = {"AESDTH": "1", "AESLIFE": "2", "AESDISAB": "3", "AESHOSP": "4",
       "AESCONG": "5", "AESCAN": "6", "AESOD": "7"}
SEV = {"MILD": "1", "MODERATE": "2", "SEVERE": "3"}
REL = {"NONE": "1", "REMOTE": "2", "POSSIBLE": "3", "PROBABLE": "4", "": ""}
ae_rows = [{
    "SUBJECT": subject(r.USUBJID), "FOLDER": "AELOG", "RECORDED_DATE": edc_date(r.MHDTC),
    "EVENT_CODE": r.MHSPID,
    "DESCRIPTION": r.MHLLT, "ONSET_DATE": "", "STOP_DATE": "", "SEVERITY": SEV.get(r.MHSEV, ""),
    "SERIOUS": "N", "SERIOUS_CODES": "", "RELATIONSHIP": "",
    "MEDDRA_LLT": r.MHLLT, "MEDDRA_PT": r.MHDECOD, "MEDDRA_HLT": r.MHHLT,
    "MEDDRA_HLGT": r.MHHLGT, "MEDDRA_SOC": r.MHBODSYS,
} for r in mh[mh.MHCAT == "SIGNIFICANT PRE-EXISTING CONDITION"].itertuples()]
ae_rows += [{
    "SUBJECT": subject(r.USUBJID), "FOLDER": "AELOG", "RECORDED_DATE": edc_date(r.AEDTC),
    "EVENT_CODE": r.AESPID,
    "DESCRIPTION": r.AETERM, "ONSET_DATE": edc_date(r.AESTDTC), "STOP_DATE": edc_date(r.AEENDTC),
    "SEVERITY": SEV[r.AESEV], "SERIOUS": r.AESER,
    "SERIOUS_CODES": ",".join(c for v, c in SER.items() if getattr(r, v) == "Y"),
    "RELATIONSHIP": REL[r.AEREL],
    "MEDDRA_LLT": r.AELLT, "MEDDRA_PT": r.AEDECOD, "MEDDRA_HLT": r.AEHLT,
    "MEDDRA_HLGT": r.AEHLGT, "MEDDRA_SOC": r.AESOC,
} for r in ae.itertuples()]
ae_raw = pd.DataFrame(ae_rows)

# --- ds_summary: Patient Summary, Visit 13 or Early Termination (CRF p106 / p139) -----
REASON = {"COMPLETED": "1", "ADVERSE EVENT": "3", "DEATH": "4", "LACK OF EFFICACY": "8",
          "LOST TO FOLLOW-UP": "11", "WITHDRAWAL BY SUBJECT": "13", "PHYSICIAN DECISION": "22",
          "STUDY TERMINATED BY SPONSOR": "18"}
ae_link = relrec.assign(CODE=relrec.RELID.str[-3:]).groupby("USUBJID").CODE.first()
entcrit = suppds.set_index("USUBJID").QVAL
death = dm.set_index("USUBJID").DTHDTC
rows = []
for r in ds[(ds.DSCAT == "DISPOSITION EVENT") & (ds.DSDECOD != "SCREEN FAILURE")].itertuples():
    if r.DSDECOD == "PROTOCOL VIOLATION":
        code = "14" if r.DSTERM == "PROTOCOL ENTRY CRITERIA NOT MET" else "243"
    else:
        code = REASON[r.DSDECOD]
    rows.append({
        "SUBJECT": subject(r.USUBJID), "FOLDER": "V13" if r.VISITNUM == 13 else "ET",
        "VISIT_NO": f"{r.VISITNUM:g}", "VISIT_DATE": edc_date(r.DSSTDTC), "REASON": code,
        "REASON_SPECIFY": r.DSTERM if code in ("13", "22") else "",
        "AE_CODE": ae_link.get(r.USUBJID, "") if code in ("3", "4") else "",
        "DEATH_DATE": edc_date(death[r.USUBJID]) if code == "4" else "",
        "ENTRY_CRITERION": entcrit.get(r.USUBJID, "") if code == "14" else "",
    })
ds_raw = pd.DataFrame(rows)

# --- ex_dosage: kit dispensed + daily prescribed patches (CRF p25, p49/p58/p73/p90) ---
# Blinded: every arm gets the same patch counts; which patch is active comes from IRT.
PATCHES = {3: (0, 1), 4: (1, 1), 12: (0, 1)}  # VISITNUM -> (25-cm2, 50-cm2) per day
last_dose = ex.groupby("USUBJID").EXENDTC.max()
ex = ex.sort_values(["USUBJID", "EXSTDTC"])
rows = []
for r in ex.itertuples():
    n25, n50 = PATCHES[int(r.VISITNUM)]
    is_last = r.EXENDTC == last_dose[r.USUBJID]
    rows.append({
        "SUBJECT": subject(r.USUBJID), "FOLDER": f"V{int(r.VISITNUM)}",
        "VISIT_DATE": edc_date(r.EXSTDTC), "KIT_NUMBER": f"K{random.randint(10000, 99999)}",
        "PATCH25_PER_DAY": n25, "PATCH50_PER_DAY": n50,
        "LAST_DOSE_DATE": edc_date(r.EXENDTC) if is_last else "",
    })
ex_raw = pd.DataFrame(rows)

# --- irt_randomization: IxRS transfer (not a CRF form) --------------------------------
kit_v3 = ex_raw[ex_raw.FOLDER == "V3"].set_index("SUBJECT").KIT_NUMBER
sf = ds[ds.DSDECOD == "SCREEN FAILURE"].set_index("USUBJID").DSSTDTC
rows, rand_no = [], {}
for r in dm.sort_values("RFXSTDTC").itertuples():
    randomized = r.ARM != "Screen Failure"
    if randomized:
        rand_no[r.SITEID] = rand_no.get(r.SITEID, 0) + 1
    rows.append({
        "SITE_ID": r.SITEID, "SUBJECT_ID": r.SUBJID,
        "SCREENING_DATETIME": irt_ts(scr1[r.USUBJID]),
        "SUBJECT_STATUS": "Randomized" if randomized else "Screen Failed",
        "SCREEN_FAIL_DATETIME": "" if randomized else irt_ts(sf[r.USUBJID]),
        "RANDOMIZATION_DATETIME": irt_ts(r.RFXSTDTC) if randomized else "",
        "RANDOMIZATION_NUMBER": f"R{r.SITEID}-{rand_no[r.SITEID]:03d}" if randomized else "",
        "TREATMENT_ARM": r.ARM if randomized else "",
        "KIT_NUMBER": kit_v3.get(subject(r.USUBJID), "") if randomized else "",
    })
irt = pd.DataFrame(rows).sort_values(["SITE_ID", "SUBJECT_ID"])

# --- planted issues (see docs/RAW-GEN-NOTES.md) ---------------------------------------
aes = ae_raw[ae_raw.ONSET_DATE != ""]
dup = aes.iloc[[40]]                                        # P1 duplicate entry
ae_raw = pd.concat([ae_raw, dup])
ae_raw.loc[aes.index[[10, 11]], "SERIOUS"] = "No"          # P2 Y/N variants
ae_raw.loc[aes.index[aes.SERIOUS == "Y"][0], "SERIOUS"] = "yes"
ae_raw.loc[aes.index[5], "DESCRIPTION"] = aes.DESCRIPTION.iloc[5].lower() + "  "  # P3
sc_su.loc[3, "EDU_YEARS"] = sc_su.EDU_YEARS[3] + " yrs"     # P4 unit typed into number field
dm_raw.loc[7, "BIRTH_DATE"] = "UN UNK " + dm_raw.BIRTH_DATE[7][-4:]  # P5 partial birth date
for i in (12, 13):                                          # P6 information not obtained
    sc_su.loc[i, ["SMOK_NOT_OBTAINED", "CIGARETTES_DAY", "CIGARS_DAY", "PIPES_DAY",
                  "SMOK_YEARS", "SMOK_QUIT_MMYY"]] = ["X", "", "", "", "", ""]

ae_raw = ae_raw.sort_values(["SUBJECT", "EVENT_CODE"], kind="stable")

# --- self-check: blinded patch counts + IRT arm must reproduce Pilot EXDOSE -----------
mg = {"Placebo": (0, 0), "Xanomeline Low Dose": (0, 54), "Xanomeline High Dose": (27, 54)}
arm = irt.set_index(irt.SITE_ID + "-" + irt.SUBJECT_ID).TREATMENT_ARM
dose = [mg[arm[s]][0] * a + mg[arm[s]][1] * b
        for s, a, b in zip(ex_raw.SUBJECT, ex_raw.PATCH25_PER_DAY, ex_raw.PATCH50_PER_DAY)]
assert all(abs(d - p) < 1e-6 for d, p in zip(dose, ex.EXDOSE)), "EX dose rule broken"
assert (dm_raw.ORIGIN == "HP").sum() == (dm.ETHNIC == "HISPANIC OR LATINO").sum()
assert len(ae_raw) == len(ae) + (mh.MHCAT == "SIGNIFICANT PRE-EXISTING CONDITION").sum() + 1

for name, df in [("dm", dm_raw), ("sc_su", sc_su), ("ae", ae_raw), ("ds_summary", ds_raw),
                 ("ex_dosage", ex_raw), ("visits", visits), ("irt_randomization", irt)]:
    df.to_csv(OUT / f"{name}.csv", index=False)
    print(f"{name:18} {len(df):5} rows")

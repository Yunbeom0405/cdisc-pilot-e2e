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
        return "UNS"  # the EDC does not number unscheduled visits
    if "(T)" in visit:
        return f"V{int(visitnum)}T"
    return {3.5: "V3E", 101: "V501"}.get(visitnum, f"V{int(visitnum)}")  # Pilot 101 = CRF Visit 501


dm, sv, sc, ae, mh, ds, ex = (read(n) for n in ("dm", "sv", "sc", "ae", "mh", "ds", "ex"))
vs, qs, lb = (read(n) for n in ("vs", "qs", "lb"))
relrec, suppds = read("relrec"), read("suppds")
OUT.mkdir(exist_ok=True)

# --- visits: one row per visit folder -------------------------------------------------
visits = pd.DataFrame({
    "SUBJECT": sv.USUBJID.map(subject),
    "FOLDER": [folder(n, v) for n, v in zip(sv.VISITNUM, sv.VISIT)],
    "VISIT_DATE": sv.SVSTDTC.map(edc_date),
})
# the visit where a subject terminated early is filed under the ET folder, with the
# visit number written in the header ("Early Termination Visit ___")
et = ds[(ds.DSCAT == "DISPOSITION EVENT") & ~ds.DSDECOD.isin(["SCREEN FAILURE", "COMPLETED"])]
et = {(r.USUBJID, r.VISITNUM) for r in et.itertuples() if r.VISITNUM not in (13, "")}
is_et = [(u, n) in et for u, n in zip(sv.USUBJID, sv.VISITNUM)]
visits.loc[is_et, "FOLDER"] = "ET"
visits["VISIT_NO"] = ["" if not e else f"{n:g}" for e, n in zip(is_et, sv.VISITNUM)]
scr1 = sv[sv.VISITNUM == 1].set_index("USUBJID").SVSTDTC


def raw_folder(usubjid, visitnum, visit):
    """CRF folder of a Pilot record, ET-aware (same rule as visits.csv)."""
    return "ET" if (usubjid, visitnum) in et else folder(visitnum, visit)


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
ex = ex.sort_values(["USUBJID", "EXSTDTC"])
rows = []
for r in ex.itertuples():
    n25, n50 = PATCHES[int(r.VISITNUM)]
    rows.append({
        "SUBJECT": subject(r.USUBJID), "FOLDER": f"V{int(r.VISITNUM)}",
        "VISIT_DATE": edc_date(r.EXSTDTC), "KIT_NUMBER": f"K{random.randint(10000, 99999)}",
        "PATCH25_PER_DAY": n25, "PATCH50_PER_DAY": n50,
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

# ===== 1-5b additions. Separate RNG so the files above stay byte-identical. ===========
rng = random.Random(1610)

# --- final_dose: Study Drug Therapy - Date of Final Dose (CRF p105 V13 / p138 ET) -----
final_dose = ds_raw[["SUBJECT", "FOLDER", "VISIT_NO", "VISIT_DATE"]].copy()
# end of the subject's last dosing interval; blank where the Pilot has no end date
last_end = ex.groupby("USUBJID").EXENDTC.last()
final_dose["FINAL_DOSE_DATE"] = [edc_date(last_end.get("01-" + s, "") or "")
                                 for s in final_dose.SUBJECT]
final_dose.loc[final_dose.FOLDER == "V13", "VISIT_NO"] = ""

# --- mh_ad_onset: Alzheimer's disease onset date (CRF p12) ---------------------------
pdx = mh[mh.MHCAT == "PRIMARY DIAGNOSIS"]
mh_ad = pd.DataFrame({
    "SUBJECT": pdx.USUBJID.map(subject), "FOLDER": "V1", "VISIT_DATE": pdx.MHDTC.map(edc_date),
    "AD_ONSET_DATE": pdx.MHSTDTC.map(edc_date),
})

# --- mh_history: Significant Historical Diagnosis (CRF p14-15), vendor MedDRA coded --
hx = mh[mh.MHCAT == "HISTORICAL DIAGNOSIS"].sort_values(["USUBJID", "MHSEQ"])
mh_hx = pd.DataFrame({
    "SUBJECT": hx.USUBJID.map(subject), "FOLDER": "V1", "VISIT_DATE": hx.MHDTC.map(edc_date),
    "LINE": hx.groupby("USUBJID").cumcount().values,
    "DIAGNOSIS": hx.MHLLT, "DATE_RECOVERED": hx.MHSTDTC.map(edc_date),
    "MEDDRA_LLT": hx.MHLLT, "MEDDRA_PT": hx.MHDECOD, "MEDDRA_HLT": hx.MHHLT,
    "MEDDRA_HLGT": hx.MHHLGT, "MEDDRA_SOC": hx.MHBODSYS,
})


# --- vital signs: three CRF forms (weight/height, heart rate & BP table, temperature) --
def vs_key(d):
    return pd.DataFrame({"SUBJECT": d.USUBJID.map(subject),
                         "FOLDER": [raw_folder(u, n, v) for u, n, v in zip(d.USUBJID, d.VISITNUM, d.VISIT)],
                         "VISIT_DATE": d.VSDTC.map(edc_date)}, index=d.index)


def pick(test):
    d = vs[vs.VSTESTCD == test]
    k = vs_key(d)
    return k.assign(VAL=d.VSORRES.values, UNIT=d.VSORRESU.values, LOC=d.VSLOC.values)


wt, ht = pick("WEIGHT"), pick("HEIGHT")
keys = ["SUBJECT", "FOLDER", "VISIT_DATE"]
vs_wt_ht = (wt.rename(columns={"VAL": "WEIGHT", "UNIT": "WEIGHT_UNIT"}).drop(columns="LOC")
            .merge(ht.rename(columns={"VAL": "HEIGHT", "UNIT": "HEIGHT_UNIT"}).drop(columns="LOC"),
                   on=keys, how="outer"))
UNIT_BOX = {"LB": "lb", "kg": "kg", "IN": "in", "cm": "cm", "F": "F", "C": "C"}
for c in ("WEIGHT_UNIT", "HEIGHT_UNIT"):
    vs_wt_ht[c] = vs_wt_ht[c].fillna("").map(lambda u: UNIT_BOX.get(u, u))
vs_wt_ht = vs_wt_ht.fillna("")

bp = vs[vs.VSTESTCD.isin(["PULSE", "SYSBP", "DIABP"])]
bp = bp.assign(**vs_key(bp)).pivot_table(
    index=keys + ["VSTPTNUM", "VSPOS"], columns="VSTESTCD", values="VSORRES", aggfunc="first").reset_index()
vs_bp = pd.DataFrame({
    **{k: bp[k] for k in keys},
    "ROW": bp.VSTPTNUM.map({815: 0, 816: 1, 817: 2}),
    "TIMING_CODE": bp.VSTPTNUM.map(lambda x: f"{x:g}"),
    "POSITION": bp.VSPOS.map({"SUPINE": "SU", "STANDING": "ST"}),
    "HEART_RATE": bp.PULSE, "SYSTOLIC": bp.SYSBP, "DIASTOLIC": bp.DIABP,
}).fillna("").sort_values(keys + ["ROW"])

tp = pick("TEMP")
vs_temp = tp.rename(columns={"VAL": "TEMPERATURE", "UNIT": "TEMP_UNIT"})
vs_temp["TEMP_METHOD"] = vs_temp.pop("LOC").map({"EAR": "E", "ORAL CAVITY": "PO"}).fillna("")


# --- questionnaires: MMSE (p10), ADAS-Cog (p26 etc.), CIBIC+ (p60 etc.) --------------
def qs_wide(cat, items, names):
    d = qs[(qs.QSCAT == cat) & qs.QSTESTCD.isin(items)]
    d = d.assign(SUBJECT=d.USUBJID.map(subject),
                 FOLDER=[raw_folder(u, n, v) for u, n, v in zip(d.USUBJID, d.VISITNUM, d.VISIT)],
                 VISIT_DATE=d.QSDTC.map(edc_date))
    w = d.pivot_table(index=keys, columns="QSTESTCD", values="QSORRES", aggfunc="first")
    w = w.reindex(columns=items).rename(columns=dict(zip(items, names))).reset_index().fillna("")
    w.insert(3, "NOT_OBTAINED", "")
    return w.sort_values(keys)


qs_mmse = qs_wide("MINI-MENTAL STATE", [f"MMITM0{i}" for i in range(1, 7)],
                  [f"ITEM{i}" for i in range(1, 7)])
qs_adas = qs_wide("ALZHEIMER'S DISEASE ASSESSMENT SCALE", [f"ACITM{i:02d}" for i in range(1, 15)],
                  [f"ITEM{i:02d}" for i in range(1, 15)])
ci = qs[qs.QSTESTCD == "CIBIC"]
qs_cibic = pd.DataFrame({
    "SUBJECT": ci.USUBJID.map(subject),
    "FOLDER": [raw_folder(u, n, v) for u, n, v in zip(ci.USUBJID, ci.VISITNUM, ci.VISIT)],
    "VISIT_DATE": ci.QSDTC.map(edc_date), "NOT_OBTAINED": "",
    "CIBIC": ci.QSSTRESN.map(lambda x: f"{x:g}"),
}).sort_values(keys)

# --- lab_results: central lab transfer (not a CRF form) -----------------------------
# Vendor conventions: own test codes, requisition visit labels, patient id without dash,
# conventional and SI results side by side, record status for corrected results.
BATTERY = {"CHEMISTRY": "CHEM", "HEMATOLOGY": "HEMA", "URINALYSIS": "URIN", "OTHER": "SPEC", "": "SPEC"}
tests = lb.drop_duplicates("LBTESTCD").sort_values(["LBCAT", "LBTESTCD"])
vcode = {t: f"{BATTERY[c]}{i:03d}" for i, (t, c) in enumerate(zip(tests.LBTESTCD, tests.LBCAT), 1)}
REQ = {1: "SCRN", 3: "BASE", 4: "WK02", 5: "WK04", 6: "WK04+1D", 7: "WK06", 8: "WK08", 9: "WK12",
       10: "WK16", 11: "WK20", 12: "WK24", 13: "WK26", 201: "RETR", 3.5: "WK02-1D"}
FLAG = {"NORMAL": "N", "HIGH": "H", "LOW": "L", "ABNORMAL": "A", "": ""}
lb = lb.sort_values(["USUBJID", "LBDTC", "LBTESTCD"])
acc = {}
lab = pd.DataFrame({
    "PROTOCOL": "LZZT", "SITE_ID": lb.USUBJID.str[3:6],
    "PATIENT_ID": lb.USUBJID.str[3:].str.replace("-", ""),
    "REQ_VISIT": [REQ.get(n, "UNSCH") for n in lb.VISITNUM],
    "COLLECTION_DT": lb.LBDTC,
    "ACCESSION": [acc.setdefault((u, d), f"A{len(acc) + 100001}") for u, d in zip(lb.USUBJID, lb.LBDTC)],
    "BATTERY": lb.LBCAT.map(BATTERY), "TEST_CODE": lb.LBTESTCD.map(vcode), "TEST_NAME": lb.LBTEST,
    "RESULT": lb.LBORRES, "UNITS": lb.LBORRESU.replace("NO UNITS", ""),
    "REF_LOW": lb.LBORNRLO, "REF_HIGH": lb.LBORNRHI, "ABN_FLAG": lb.LBNRIND.map(FLAG),
    "RESULT_SI": lb.LBSTRESC, "UNITS_SI": lb.LBSTRESU.replace("NO UNITS", ""),
    "REF_LOW_SI": lb.LBSTNRLO.map(lambda x: "" if x == "" else "0" if abs(x) < 1e-9 else f"{x:g}"),  # Pilot stores 0 as 5.4e-79
    "REF_HIGH_SI": lb.LBSTNRHI.map(lambda x: "" if x == "" else f"{x:g}"),
    "STATUS": "FINAL",
})

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

i = vs_temp.index[(vs_temp.TEMP_UNIT == "F")][20]              # P7 unit box not checked
vs_temp.loc[i, "TEMP_UNIT"] = ""
i = vs_bp.index[(vs_bp.ROW == 0) & (vs_bp.SYSTOLIC != "")][30]   # P8 systolic/diastolic swapped
vs_bp.loc[i, ["SYSTOLIC", "DIASTOLIC"]] = vs_bp.loc[i, ["DIASTOLIC", "SYSTOLIC"]].values
j = lab.index[(lab.TEST_CODE == vcode["ALT"])][50]             # P9 corrected result
old = lab.loc[[j]].assign(RESULT=str(int(float(lab.RESULT[j])) * 10), STATUS="CANCELLED")
lab = pd.concat([lab, old]).sort_values(["PATIENT_ID", "COLLECTION_DT", "TEST_CODE", "STATUS"])
i = qs_adas.index[qs_adas.FOLDER == "V8"][7]                     # P10 information not obtained
qs_adas.loc[i, "NOT_OBTAINED"] = "X"
qs_adas.loc[i, [f"ITEM{k:02d}" for k in range(1, 15)]] = ""
mh_ad.loc[mh_ad.index[12], "AD_ONSET_DATE"] = "UN UNK " + mh_ad.AD_ONSET_DATE.iloc[12][-4:]  # P11

ae_raw = ae_raw.sort_values(["SUBJECT", "EVENT_CODE"], kind="stable")

# --- self-check: blinded patch counts + IRT arm must reproduce Pilot EXDOSE -----------
mg = {"Placebo": (0, 0), "Xanomeline Low Dose": (0, 54), "Xanomeline High Dose": (27, 54)}
arm = irt.set_index(irt.SITE_ID + "-" + irt.SUBJECT_ID).TREATMENT_ARM
dose = [mg[arm[s]][0] * a + mg[arm[s]][1] * b
        for s, a, b in zip(ex_raw.SUBJECT, ex_raw.PATCH25_PER_DAY, ex_raw.PATCH50_PER_DAY)]
assert all(abs(d - p) < 1e-6 for d, p in zip(dose, ex.EXDOSE)), "EX dose rule broken"
assert (dm_raw.ORIGIN == "HP").sum() == (dm.ETHNIC == "HISPANIC OR LATINO").sum()
assert len(ae_raw) == len(ae) + (mh.MHCAT == "SIGNIFICANT PRE-EXISTING CONDITION").sum() + 1

assert (final_dose.FINAL_DOSE_DATE != "").sum() == 248
assert len(vs_bp) * 3 >= (vs.VSTESTCD.isin(["PULSE", "SYSBP", "DIABP"])).sum()
assert not lab.duplicated(["ACCESSION", "TEST_CODE", "STATUS"]).any()

for name, df in [("dm", dm_raw), ("sc_su", sc_su), ("ae", ae_raw), ("ds_summary", ds_raw),
                 ("ex_dosage", ex_raw), ("visits", visits), ("irt_randomization", irt),
                 ("final_dose", final_dose), ("mh_ad_onset", mh_ad), ("mh_history", mh_hx),
                 ("vs_wt_ht", vs_wt_ht), ("vs_bp", vs_bp), ("vs_temp", vs_temp),
                 ("qs_mmse", qs_mmse), ("qs_adas", qs_adas), ("qs_cibic", qs_cibic),
                 ("lab_results", lab)]:
    df.to_csv(OUT / f"{name}.csv", index=False)
    print(f"{name:18} {len(df):5} rows")

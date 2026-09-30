# Raw Data Generation Notes

The CDISC Pilot package ships SDTM and ADaM only — there is no raw/EDC layer. The files in
`raw/` were designed and generated for this project by `python/generate_raw.py` so that SDTM
can be built the way it is in practice: from CRF-shaped exports plus external vendor files.

- **Subjects, dates, events and dispositions** are reverse-mapped from the Pilot SDTM, so the
  rebuilt SDTM can be reconciled against the Pilot record by record.
- **Fields collected on the CRF but absent from the Pilot** (initials, consent date, birth date,
  substance use) are simulated with a fixed seed (`1609`); reruns give identical files. Files added
  for the second batch of domains use a separate seed (`1610`) so the earlier files do not change.
- **Data issues are planted by hand, not by random rates** (see below), so each one is a known
  case the SDTM programs must handle.

Source data © CDISC. Learning/portfolio use only; not related to any regulatory submission.

## Files

Export conventions follow a typical EDC: one CSV per form, codes as printed on the CRF,
dates as `DD MON YYYY` (unknown parts as `UN` / `UNK`). `SUBJECT` is `<site>-<subject>`.

| File | CRF source | Rows | Maps to | Notes |
|---|---|---|---|---|
| `dm.csv` | p7 Visit 1 — identification, consent, demographics | 306 | DM, DS (consent) | `ORIGIN`: CA, AF, EA, AS, HP, O. `INITIALS` not submitted |
| `sc_su.csv` | p8 Visit 1 — education, smoking, alcohol | 306 | SC, SU | Dose fields hold `0`, `L` or a whole number; `*_NOT_OBTAINED` = `X` when checked |
| `ae.csv` | p121–123 Pre-existing Conditions and Study AE log | 2,050 | AE, MH | Includes MedDRA coding columns (`MEDDRA_*`) as delivered by the coding vendor |
| `ds_summary.csv` | p106 Visit 13 / p139 Early Termination Patient Summary | 254 | DS | `REASON` uses CRF codes (1, 3, 4, 8, 9, 11, 13, 14, 18, 22, 243) |
| `ex_dosage.csv` | p25, p49, p58, p73, p90 — kit and daily prescribed patches | 591 | EX | Blinded patch counts |
| `final_dose.csv` | p105 Visit 13 / p138 Early Termination — Date of Final Dose | 254 | EX, DM | Blank for 6 subjects (last interval has no end date in the Pilot) |
| `visits.csv` | Visit date on each visit's identification page | 3,559 | SV | Folders: `V3E` ambulatory ECG, `V8T` telephone, `ET` early termination (`VISIT_NO` = number written on the page), `UNS` unscheduled (not numbered by the EDC) |
| `mh_ad_onset.csv` | p12 Alzheimer's disease onset date | 254 | MH | Primary diagnosis |
| `mh_history.csv` | p14–15 Significant Historical Diagnosis | 706 | MH | `DATE_RECOVERED` is often partial; MedDRA columns from the coding vendor |
| `vs_wt_ht.csv` | Weight / Height page | 2,050 | VS | Unit checkbox as collected (`lb`/`kg`, `in`/`cm`) |
| `vs_bp.csv` | Heart rate and blood pressure table | 8,208 | VS | One row per table row: timing code 815/816/817, position `SU`/`ST` |
| `vs_temp.csv` | Temperature page | 2,720 | VS | Unit `F`/`C`; method `PO`, `E` (others unused in this study) |
| `qs_mmse.csv` | p10 Mini-Mental State (Visit 1) | 254 | QS | Six item scores; total is not entered (DNDE) |
| `qs_adas.csv` | ADAS-Cog pages | 818 | QS | Items 1–14; item 10 in seconds; no total on the CRF |
| `qs_cibic.csv` | CIBIC+ pages | 562 | QS | Box code 1–7 |
| `lab_results.csv` | *Not a CRF form* — central lab transfer | 59,581 | LB | Vendor test codes, requisition visit labels, conventional and SI results, record `STATUS` |
| `irt_randomization.csv` | *Not a CRF form* — IxRS transfer | 306 | DM (ARM), DS | ISO date-times; subject key split into `SITE_ID` + `SUBJECT_ID` |

### Design decisions a mapper needs

- **Treatment arm is not on the CRF.** Every arm records the same patch counts (blinding). The dose
  comes from the IxRS arm: Placebo — both patches placebo; Low dose — 50 cm² active (54 mg),
  25 cm² placebo; High dose — 50 cm² (54 mg) + 25 cm² (27 mg) active.
- **Randomization and screen failure** come only from `irt_randomization.csv`
  (`SUBJECT_STATUS`, `RANDOMIZATION_DATETIME`, `SCREEN_FAIL_DATETIME`).
- **Last dose date** is collected once, on the Date of Final Dose page at Visit 13 or Early
  Termination (`final_dose.csv`), not on the dosing pages.
- **Visit numbers are not in the raw data for ET and unscheduled visits.** ET pages carry the number
  written by the site (`VISIT_NO`); unscheduled visits are only `UNS` + date, so SDTM has to place them
  after the previous visit.
- **Lab data come from the central lab**, not the EDC. The lab uses its own test codes and visit labels
  (`SCRN`, `WK02`, `UNSCH`), a patient id without the dash (`7011015`), and sends both conventional and
  SI results. Corrected results arrive as a new `FINAL` record plus the old one marked `CANCELLED`.
- **Vital-sign units are as checked on the CRF** (mostly pounds, inches, Fahrenheit). SDTM keeps them in
  `--ORRES/--ORRESU` and converts to kg, cm and C in `--STRESN/--STRESU`.
- **Out of scope**: NPI-X, DAD and Hachinski are annotated on the aCRF but not exported.
- **MH vs AE** share one log. Pre-existing conditions have no onset date and were recorded at
  Visit 1 → MH. Every row with an onset date is an AE, including 65 events that started after
  consent but before the first dose (AE collection starts at consent).
- **Same event, several rows**: the log is re-recorded at later visits (`RECORDED_DATE` differs).
  `EVENT_CODE` alone is not a unique key.
- **Treatment vs study disposition**: `ds_summary` holds one reason per subject. Subjects who stop
  early may still attend the Week 24 retrieval visit (`V201` in `visits.csv`), so treatment
  disposition and study disposition can differ.

## Planted issues

| # | File | Issue | Where | Expected handling |
|---|---|---|---|---|
| P1 | `ae.csv` | Exact duplicate row (re-entry) | 701-1115, E11 | Remove before sequencing |
| P2 | `ae.csv` | Y/N variants: `No` ×2, `yes` ×1 | `SERIOUS` | Standardize to `Y`/`N` |
| P3 | `ae.csv` | Lower case + trailing spaces in verbatim term | 701-1023 E09 | Upcase and strip `AETERM` |
| P4 | `sc_su.csv` | Unit typed into numeric field (`"12 yrs"`) | 701-1033 `EDU_YEARS` | Strip text, flag in QC |
| P5 | `dm.csv` | Partial birth date `UN UNK 1945` | 701-1097 | Partial `BRTHDTC`; AGE handling |
| P6 | `sc_su.csv` | Smoking "Information not obtained" checked | 701-1133, 701-1145 | `SUSTAT = 'NOT DONE'` |
| P7 | `vs_temp.csv` | Temperature unit box not checked | one row | Keep `VSORRES`, `VSORRESU` null, no standard value; site query |
| P8 | `vs_bp.csv` | Systolic and diastolic entered in each other's field | one supine row | Keep as collected; flag in QC (systolic < diastolic) |
| P9 | `lab_results.csv` | Corrected result: `CANCELLED` + `FINAL` record | one ALT result | Use `FINAL` only |
| P10 | `qs_adas.csv` | ADAS-Cog "Information not obtained" checked | one Visit 8 page | `QSTESTCD = 'QSALL'`, `QSSTAT = 'NOT DONE'` |
| P11 | `mh_ad_onset.csv` | Partial onset date `UN UNK yyyy` | one subject | Partial `MHSTDTC` |

Issues that come from the Pilot itself (kept, not planted):

- 705-1199 E06 appears twice with identical CRF fields; the Pilot rows differ only in `AEOUT`,
  which the CRF does not collect.
- 26 AE onset dates are partial (`UN MAY 2013`, `UN UNK 2013`).
- Free-text `REASON_SPECIFY` entries for codes 13 and 22 (e.g. `CAREGIVER BURDEN`).
- Unscheduled visits (`UNS` folder) need a `VISITNUM` rule (MT.VISIT: previous visit + .1).
- Some single blood-pressure/pulse values and ADAS-Cog items are blank in the Pilot; they stay blank.
- A few lab results are reported with an operator (`<0.2`, `<40`).

# Pinnacle 21 review

P21 Community, engine FDA 2508.1, SDTMIG 3.4, CT 2026-03-27. MedDRA and SNOMED are not configured (licensed).
Second run (after the SV and LB fixes): 0 errors, 55,033 warnings, 1 reject (no define.xml yet; with define.xml the counts are the same and the reject is gone). The first run had 69,554 warnings. Report: `output/validation/p21/p21-sdtm.xlsx`.

## Warnings and decisions

| Rule | Found | Domain | Cause | Decision |
|---|---|---|---|---|
| SD2239 | 21,430 | VS | Time points are in VSTPT, but VSDTC has no time, so supine and standing readings share one date | Keep |
| SD1445 | 762 | VS | Standing blood pressure and pulse have two time points (1 and 3 minutes), each with a baseline flag; the rule ignores the time point | Keep |
| CT2002 | 1,817 | LB | LBSTRESU not in CT: `fmol(Fe)` (MCH, 1,809) and `1` (HbA1c fraction, 8). `GI/L`, `TI/L` and HCT `1` were fixed (16,245 before) | Keep, no CT value |
| CT2002 | 13,181 | LB | LBORRESU not in CT: `MILL/uL`, `THOU/uL`, `pg/mL`, `uIU/mL` | Keep, as collected |
| CT2002 | 12,963 | QS | QSCAT `ALZHEIMER'S DISEASE ASSESSMENT SCALE` and `MINI-MENTAL STATE` are not in the extensible codelist | Keep |
| SD0026, SD0029 | 636 | LB | Morphology results have no unit | Keep |
| SD0065 | 0 | LB | Fixed: lab-only unscheduled visits now have an SV record (7 added, 3,566 total); was 93 | Done |
| SD1201 | 266 | AE, MH | AE log rows re-recorded at later visits (same AESPID, different AEDTC); the Pilot has 230 AE groups | Keep |
| SD1132 | 36 | AE | AESER is N but a seriousness criterion is Y | Keep, as collected |
| SD0021, SD0022, SD0031 | 3,200 | AE, EX, MH | Ongoing events have no end date; history has an end date only | Keep |
| SD1209 | 6 | DM | No final dose date recorded | Keep |
| SD0027, SD0036, SD1320 | 15 | VS | NOT DONE measurements keep the unit; one temperature has no unit | Keep |
| SD1331 | 2 | AE | Start `2013-07` is after collection date `2013-06-22` | Keep, as collected |
| SD0057, SD1076, SD1083 | 160 | all | Expected variables not collected (AEACN, MedDRA codes, SVOCCUR, AEDY) | Keep |
| TS rules | 36 | TS | Optional trial summary parameters missing | Later |
| SD1111, SD1321, SD1485 | 3 | Global | No SE, SUPPAE or LC datasets | Keep |

## LB standard units

LBORRESU stays as collected. LBSTRESU comes from the SI units sent with the lab data; only the spelling changes to the CT submission value.

| Before | CT value | Records |
|---|---|---|
| `GI/L` | `10^9/L` (synonym) | 10,829 |
| `TI/L` | `10^12/L` (synonym) | 1,809 |
| `1` | `L/L` | 1,798 |
| `fmol(Fe)` | no CT value | 1,809 |

## ADaM

P21 Community, engine FDA 2508.1, ADaM-IG 1.3, ADaM CT 2026-03-27. 10 datasets, 0 errors, 1,536 warnings. Report: `output/validation/p21/p21-adam.xlsx` (data only) and `p21-adam-define.xlsx` (data and define.xml). The Details sheet lists at most 1,000 records per rule, so counts below come from the Dataset Summary.

First run had 5,152 warnings and a missing define.xml reject; AD0133C (3,616) was fixed, see below.

| Rule | Found | Dataset | Cause | Decision |
|---|---|---|---|---|
| AD0133C | 3,616 | ADLBH | BASO and EOS lower limit was 5.4E-79 instead of 0, so R2A1LO was Inf | Fixed, now 0 |
| AD0154 | 1,518 | ADVS | Lying and both standing positions are all baseline for the Week 0 visit; no BASETYPE to tell them apart | Keep |
| AD0018 | 5 | ADSL, ADMH, ADQSADAS, ADQSCIBC, ADTTE, ADAE | Label differs from the standard (ITTFL, STARTDT, AOCCFL) | Keep |
| AD0047 | 8 | ADAE | MedDRA code variables not present (licensed dictionary) | Keep |
| AD0509 | 1 | ADSL | DISONSDT label has no "Start Date" | Keep |
| AD1024-AD1026 | 3 | Global | DM, AE, EX not given to the ADaM run | Keep |

### AD0133C

The Pilot stores a lower limit of 0 as 5.39761E-79 for BASO and EOS. It reached `raw/lab_results.csv` through `python/generate_raw.py`, then LBSTNRLO, A1LO and R2A1LO = AVAL / A1LO = Inf (3,566 records). SAS and R both passed the value on, so they matched. Fixed in the raw generator (values below 1E-9 written as 0); SDTM and ADaM were rerun.

## define.xml

`python/make_define.py` builds Define-XML 2.1 from the spec workbooks and the XPT headers (`define/sdtm/define.xml`, `define/adam/define.xml`). It stops if the spec and an XPT file disagree on variable names or order. P21 Community has no define generator in its CLI, so the XML is written directly.

Validating the data together with define.xml (`p21-sdtm-define.xlsx`, `p21-adam-define.xlsx`) checks the spec against the data. It found the following; all were fixed in the spec or program, none in the data except ADURU.

| Rule | Found | Dataset | Cause | Fix |
|---|---|---|---|---|
| SD0037 | ~95,000 | LB | Unit codelist had 14 terms, data uses about 22 | Added 18 terms from the CT file; 6 without a CT value are marked extended |
| SD0037 | 1,124 | QS | CIBIC+ test code ACGC0101 and its name missing from the codelists | Added |
| SD1063 | 5 | TA, TE, TV, TI, TS | Trial design datasets not in the spec | Added to the spec |
| SD1230 | 3 | QS | ADAS-Cog QSORRES typed integer, data has decimals | Typed float |
| SD1230 | 2 | ADQSADAS | AVAL for ACITM01 typed integer, data has 7.3 and 8.33 | Typed float |
| SD0037 | 508 | ADTTE | PARAMCD codelist also attached to PARAM | Removed from PARAM |
| SD0059 | 30 | ADaM | Date variables typed `date`, but SAS dates are numbers | Written as integer in define.xml |
| CT2002, SD0037 | 717 | ADAE | ADURU was `DAY`, CT submission value is `DAYS` | Program changed (SAS and R), ADAE rerun |

Result: SDTM has no new issues with define.xml. ADaM is at the 1,536 warnings above. Spec and define.xml now agree with the data.

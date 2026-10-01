# QC Log

Every discrepancy found during QC is logged here: what differed, why, and how it was resolved.
Cause categories:

- **Language** - SAS and R behave differently for the same logic
- **Interpretation** - the spec allowed more than one reading
- **Bug** - one of the programs was wrong

---

## 1-5 SDTM: SAS vs R cross-language comparison

| | |
|---|---|
| Date | 2026-09-30 |
| Production | `sas/sdtm/dm.sas`, `ae.sas`, `ds.sas` -> `data/derived/sdtm/` |
| Independent | `r/sdtm/dm.R`, `ae.R`, `ds.R` ({sdtm.oak}) -> `data/derived/sdtm-r/` |
| Method | `r/sdtm/compare.R` - {diffdf} by key, report in `output/validation/sdtm-r-vs-sas.txt` |

### First run

| Domain | Result |
|---|---|
| DM | Match |
| AE | Match |
| DS | 1120 vs 1120 rows. Differences in DSSCAT (434), EPOCH (57), and 2 each in DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT, DSSTDTC |
| SUPPDS | 2 records with a different IDVARVAL |
| RELREC | 65 DS-side records with a different IDVARVAL |

### Finding 1 - EPOCH: blank vs missing (Language / Bug in R)

- **What:** 55 DS records had EPOCH = FOLLOW-UP in R and SCREENING in SAS. All belonged to subjects with a blank RFXSTDTC or RFXENDTC.
- **Why:** `ds.R` reads DM back from the XPT file. `haven::read_xpt()` returns blank character values as `""`, not `NA`. The EPOCH rule tests `is.na(RFXSTDTC)`, so `""` fell through to the last branch. SAS treats a blank character value as missing, so the SAS program was not affected.
- **Fix:** Added `read_sdtm()` to `r/sdtm/setup.R`. It converts `""` to `NA` on read. `ae.R` and `ds.R` now use it.
- **Lesson:** When R reads SAS data, set blank strings to `NA` before any missing-value logic.

### Finding 2 - DSSEQ order (Interpretation)

All remaining DS differences, and every SUPPDS and RELREC difference, came from DSSEQ. The values were the same, but records were numbered in a different order. SUPPDS and RELREC point to DS through DSSEQ, so they changed as well.

The spec said: *"Sort by USUBJID, DSSTDTC, DSCAT (PROTOCOL MILESTONE first), DSSCAT."* The two programs read this in two different ways:

| Case | SAS | R |
|---|---|---|
| STUDY TREATMENT and STUDY PARTICIPATION on the same day (217 subjects) | Treatment first (`descending dsscat`) | Participation first (alphabetical DSSCAT, as literally written) |
| 01-705-1382: randomized and discontinued on the same day | Compared the date part only -> RANDOMIZED first | Compared the full DSSTDTC string: `2013-05-13` sorts before `2013-05-13T16:40:09` -> discontinuation first |

- **Root cause:** Sorting by date needs a tie-break rule for same-day records, and the spec did not fully define one. The final DS data has **245 same-day record pairs**, so this affects most subjects.
- **First attempt:** Kept the date sort and added explicit rank variables to the R program. This matched SAS, but it still depended on the date and on how partial dates or datetimes compare.
- **Resolution:** Redesigned MT.DSSEQ so it does not use dates. Each record type gets a fixed position that follows the protocol flow:

  | Order | DSCAT / DSSCAT | Record |
  |---|---|---|
  | 1 | PROTOCOL MILESTONE | INFORMED CONSENT OBTAINED |
  | 2 | PROTOCOL MILESTONE | RANDOMIZED |
  | 3 | DISPOSITION EVENT / STUDY TREATMENT | End of treatment |
  | 4 | DISPOSITION EVENT / STUDY PARTICIPATION | End of study (includes SCREEN FAILURE) |

  Each type occurs at most once per subject, so no tie-break is needed. The DS key variables became `STUDYID, USUBJID, DSSEQ`.
- **Changes:** Spec (Methods MT.DSSEQ, Datasets key variables), `sas/sdtm/ds.sas` (`_ord`), `r/sdtm/ds.R` (`ds_ord`). The SAS program was re-run.
- **Check:** In both outputs, DSSEQ order never runs backwards in date (0 records with an earlier date than the record before).
- **Lesson:** A --SEQ rule that depends on dates needs a complete tie-break. When the record types have a natural order, a fixed rank is simpler and can't be misread.

### Final result

| Domain | Rows | Result |
|---|---|---|
| DM | 306 | Match |
| AE | 1190 | Match |
| DS | 1120 | Match |
| SUPPDS | 3 | Match |
| RELREC | 190 | Match |

---

## 1-5b SDTM: SV, EX, MH, VS, QS, LB

| | |
|---|---|
| Date | 2026-09-30 |
| Production | `sas/sdtm/sv.sas`, `ex.sas`, `mh.sas`, `vs.sas`, `qs.sas`, `lb.sas` |
| Independent | `r/sdtm/sv.R`, `ex.R`, `mh.R`, `vs.R`, `qs.R`, `lb.R` |
| Method | `r/sdtm/compare.R` - {diffdf} by key, report in `output/validation/sdtm-r-vs-sas.txt` |

The R programs follow the spec and the raw data, and were written after the SAS programs had run on the server, so this comparison checks the implementation rather than the spec interpretation. Before comparing with SAS, row counts were checked against the SAS log (all equal), and EX, LB, MH, VS and QS were reconciled against the CDISC Pilot SDTM that the raw data were built from.

### Finding 1 - TELEPHONE CALL flag on early termination visits (Bug in SAS)

- **What:** Found while writing `sv.R`, before any comparison. `sv.sas` set `SVCNTMOD = 'TELEPHONE CALL'` when the folder name ends in `T`. The early termination folder is `ET`, so 143 ET visits would have been flagged as telephone visits.
- **Fix:** Match the telephone folders explicitly (`V8T` to `V11T`) with a regular expression. The same flag also drives the `.5` VISITNUM rule.
- **Lesson:** Test a pattern against every folder name in the data, not only the ones it is meant for.

### Finding 2 - Macro sort error in the SAS flag macro (Bug in SAS, found at run time)

- **What:** The first server run of `vs.sas` stopped with `BY variables not properly sorted on data set WORK._LOBX`, which also left `VSLOBXFL` undefined.
- **Why:** The `%lobxfl` macro merges the last pre-dose record back onto the data by row number, but the lookup was still sorted by test and date.
- **Fix:** Sort the lookup by row number before the merge. `qs.sas` and `lb.sas` use the same macro.

### First comparison

| Domain | Result |
|---|---|
| SV, EX, MH, QS, LB | Match |
| AE | 5 differences in EPOCH |
| VS | 24,624 differences in VSTPTREF |

### Finding 3 - VSTPTREF without a blank (Language)

- **What:** SAS gave `PATIENTSUPINE`, R gave `PATIENT SUPINE`. No other VS variable differed.
- **Why:** `cats()` removes leading and trailing blanks from every argument, so the blank in `'PATIENT '` was lost. R's `paste()` keeps it.
- **Fix:** `catx(' ', 'PATIENT', vspos)` in `vs.sas`.

### Finding 4 - AE compared against an old file (Process)

- **What:** AE EPOCH was FOLLOW-UP in SAS and TREATMENT in R for 5 records of two subjects (705-1031, 705-1303). Both subjects have no last dose date.
- **Why:** The SAS `ae.xpt` in the repository was from the previous day and had not been copied after the last run. Since then the last dose date was taken from the Date of Final Dose page instead of the previous dosing interval, so it is blank for these subjects and the EPOCH rule gives TREATMENT.
- **Fix:** No code change. Copied the new `ae.xpt` and compared again.
- **Lesson:** Check the file dates of the outputs before investigating a difference.

### Reconciliation with the Pilot SDTM

| Domain | Result |
|---|---|
| EX | 591 of 591 records equal in dose, end date and treatment |
| LB | No difference in result, standard result, reference range or flag for 57,744 matched results. The rest differ only in the test code: `BUN` and `HBA1C` were changed to `UREAN` and `HBA1CHGB` (current CT) |
| MH | Same record counts per category (706 historical, 254 primary, 858 pre-existing) |
| VS | Only the planted issues differ: one temperature without a unit (P7) and one swapped systolic/diastolic pair (P8). Units follow CT (`beats/min`, `in`) |
| QS | 592 records not in the Pilot: 562 CIBIC+ records renamed to ADCS-CGIC, 29 ADAS-Cog items left blank by the site (`NOT DONE`), 1 page not done (`QSALL`) |

### Final result

| Domain | Rows | Result |
|---|---|---|
| DM | 306 | Match |
| AE | 1190 | Match |
| DS | 1120 | Match |
| SUPPDS | 3 | Match |
| RELREC | 190 | Match |
| SV | 3559 | Match |
| EX | 591 | Match |
| MH | 1818 | Match |
| SC | 306 | Match (added 2026-10-01) |
| VS | 29648 | Match |
| QS | 13525 | Match |
| LB | 59580 | Match |

---

## 1-8 ADaM: results checked against the CSR

| | |
|---|---|
| Date | 2026-10-01 |
| Production | `sas/adam/*.sas` -> `data/derived/adam/` |
| Method | Record and flag counts checked against an independent Python calculation; key results checked against the CSR tables |

| CSR table | CSR | ADaM |
|---|---|---|
| 14-3.01 ADAS-Cog (11) Week 24 LOCF: n | 79 / 81 / 74 | 79 / 81 / 74 |
| 14-3.01 Baseline mean | 24.1 / 24.4 / 21.3 | 24.1 / 24.4 / 21.3 |
| 14-3.01 Change from baseline mean | 2.5 / 2.0 / 1.5 | 2.5 / 2.0 / 1.5 |
| 14-3.02 CIBIC+ Week 24 mean | 4.3 / 4.2 / 4.3 | 4.3 / 4.2 / 4.3 |
| 14-5.01 Subjects with TEAE [events] | 65 [281] / 77 [412] / 76 [433] | 65 [281] / 77 [411] / 76 [433] |

The one TEAE event less in the low dose group is the duplicate AE row planted in the raw data (P1, 01-701-1115), removed in SDTM.

### Finding 1 - ACTARM for subjects who stopped during titration (Interpretation)

- **What:** Safety population by actual treatment was 86 / 96 / 72. The CSR has 86 / 84 / 84.
- **Why:** The SDTM DM rule set ACTARM = Xanomeline Low Dose for 12 high-dose subjects who never received the 81 mg dose. The high-dose arm starts with 2 weeks of 54 mg (titration, see TA), and these subjects stopped within those 2 weeks. They followed the high-dose arm path, so their actual arm is High Dose.
- **Fix:** ACTARM = ARM for every treated subject (`dm.sas`, `dm.R`, spec `MT.ACTARM`, SDTM Open Issue). DM and all ADaM datasets rerun.
- **Lesson:** Actual arm follows the arm path in the trial design, not the dose received at one point. Checking derived counts against the CSR found an error that SAS vs R double programming could not, because both programs used the same rule.

---

## 1-9 ADaM: SAS vs R cross-language comparison

| | |
|---|---|
| Date | 2026-10-01 |
| Production | `sas/adam/*.sas` -> `data/derived/adam/` |
| Independent | `r/adam/*.R` ({admiral} 1.5.0) -> `data/derived/adam-r/` |
| Method | `r/adam/compare.R` - {diffdf} by key, report in `output/validation/adam-r-vs-sas.txt` |

### First run

| Dataset | Result |
|---|---|
| ADSL | Values match; date variables had format `DATE` in R and `DATE9.` in SAS |
| ADAE, ADMH, ADVS, ADLBC, ADLBH, ADLBHY, ADTTE, ADQSCIBC | Match |
| ADQSADAS | STUDYID blank in SAS for 726 of 980 ACTOT records |

### Finding 1 - STUDYID lost in a one-to-many merge (Bug in SAS)

- **What:** In the SAS ADQSADAS, STUDYID was blank on 726 total-score (ACTOT) records. Only the first ACTOT record of each subject had a value.
- **Why:** The total-score records are built without STUDYID; the item records still had it from QS. Stacked together, the ACTOT rows had a blank STUDYID. `%addadsl` then merged ADSL (which also has STUDYID) one-to-many by USUBJID. In a SAS merge, the ADSL value is read only once per subject; on the next records the blank value from the analysis data overwrites it. R joins by key and takes STUDYID from ADSL on every row, so R was right.
- **Fix:** `adqsadas.sas` drops STUDYID from the item records before the merge, so every record gets it from ADSL.
- **Lesson:** In a one-to-many SAS merge, a variable that exists in both datasets keeps the value of the "many" side after the first record. Drop overlapping variables before merging.

### Finding 2 - ties in the first dermatologic event (Language)

- **What:** No difference in the output, but {admiral} warned that ADAE has several records with the same USUBJID and ASTDT. 90 subjects have more than one dermatologic event on the date of their first one.
- **Why:** `derive_param_tte()` picks one record per subject by date only. With ties, which AESEQ goes into SRCSEQ is not guaranteed. SAS sorts by ASTDT and AESEQ, so it always takes the lowest AESEQ. The R result matched by chance.
- **Fix:** `adtte.R` keeps only the first event per subject (ASTDT, then AESEQ) before `derive_param_tte()`.
- **Lesson:** A match today is not proof; a warning about ties means the result can change. Make every "first record" rule fully ordered.

### Final result

| Dataset | Rows | Result |
|---|---|---|
| ADSL | 306 | Match |
| ADAE | 1190 | Match |
| ADMH | 1818 | Match |
| ADVS | 29634 | Match |
| ADLBC | 32734 | Match |
| ADLBH | 21919 | Match |
| ADLBHY | 5294 | Match |
| ADTTE | 508 | Match |
| ADQSADAS | 9943 | Match (after Finding 1 fix) |
| ADQSCIBC | 726 | Match |

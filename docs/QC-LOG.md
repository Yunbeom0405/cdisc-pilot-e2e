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

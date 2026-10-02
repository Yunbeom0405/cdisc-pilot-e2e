# CDISC Pilot — End-to-End Clinical Programming and Dual-Programming QC

An end-to-end clinical programming pipeline built on the public CDISC SDTM/ADaM Pilot Project study:
simulated raw EDC data, SDTM, ADaM, TLFs and define.xml. Every layer is programmed twice, in **SAS**
(production) and **R** (independent QC), and the two outputs are compared.

## Study

**CDISCPILOT01** (original protocol H2Q-MC-LZZT) — *Safety and Efficacy of the Xanomeline Transdermal
Therapeutic System (TTS) in Patients with Mild to Moderate Alzheimer's Disease*

- Phase 2, randomized, multi-center, double-blind, placebo-controlled, parallel-group
- Placebo / Xanomeline low dose (54 mg) / Xanomeline high dose (81 mg), 1:1:1, 26 weeks
- 254 subjects randomized (ITT = Safety = 254, Efficacy = 234); 306 screened
- Primary endpoints: ADAS-Cog(11) and CIBIC+ at Week 24

## Approach

Target standards: SDTMIG v3.4, ADaM-IG 1.3, Define-XML v2.1. The aCRF follows SDTM-MSG v2.0.

1. **Raw data first.** The Pilot package has no raw layer, so `raw/` (EDC-style CSVs plus central lab
   and IxRS transfers) is generated with Python from the Pilot SDTM, with known data issues planted
   by hand. See [docs/RAW-GEN-NOTES.md](docs/RAW-GEN-NOTES.md).
2. **Spec before code.** SDTM and ADaM mapping specs were written before programming and drive
   define.xml.
3. **Dual programming.** SAS is the production code. R (`{sdtm.oak}`, `{admiral}`) is written
   independently from the spec. Outputs are compared with `{diffdf}`: by key for SDTM/ADaM,
   cell by cell for TLFs.
4. **External check.** Key TLF results are checked against the Pilot CSR, and the final datasets are
   validated with Pinnacle 21 Community.

## Results

| Layer | Scope | SAS vs R | Pinnacle 21 |
|---|---|---|---|
| SDTM | 12 domains, plus TA/TE/TV/TI/TS | Match | 0 errors, 55,033 warnings |
| ADaM | ADSL, ADAE, ADMH, ADVS, ADLBC, ADLBH, ADLBHY, ADQSADAS, ADQSCIBC, ADTTE | Match | 0 errors, 1,536 warnings |
| TLF | Tables 14-1.01, 14-2.01, 14-3.01, 14-5.01, A3 (AEs by max severity), 23 (lab shifts), Figures 14-1 and A8 (eDISH) | Match; key results of the first four equal CSR | — |
| define.xml | SDTM and ADaM, Define-XML 2.1 | — | Validated with the data |

- Every remaining P21 warning has a documented decision: [docs/P21-REVIEW.md](docs/P21-REVIEW.md).
- 16 discrepancies found along the way, each with cause and fix: [docs/QC-LOG.md](docs/QC-LOG.md).
  Four SAS bugs gave no error or warning and were found only by the SAS vs R comparison.
- Comparison reports: [output/validation/](output/validation/). TLF output: [output/tlf/](output/tlf/).
- Planned TLFs not yet built: [docs/TLF-PLAN.md](docs/TLF-PLAN.md).

## Repository structure

```
raw/               simulated EDC / lab / IxRS exports (generated)
specs/             tlf-shells.docx (SDTM and ADaM spec workbooks are kept local)
sas/               production programs: sdtm/, adam/, tlf/, macros/
r/                 independent QC programs: sdtm/, adam/, tlf/
python/            raw data generation, trial design domains, define.xml builder
define/            define.xml for SDTM and ADaM
output/tlf/        TLF output from SAS (RTF/CSV) and R (TXT/CSV/PNG)
output/validation/ SAS vs R comparison reports and Pinnacle 21 reports
docs/              data inventory, raw generation notes, QC log, P21 review, TLF plan
```

## Tools

| | |
|---|---|
| SAS | SDTM, ADaM and TLF production programs |
| R | `{sdtm.oak}`, `{admiral}`, `{diffdf}` for independent QC programs and comparison |
| Python | `faker`, `pandas`, `pyreadstat`, `openpyxl` for raw data, trial design domains and define.xml |
| Pinnacle 21 Community | SDTM/ADaM validation |

## Reproduction

Source and derived data are not redistributed. Get the Pilot package:

```bash
git clone --depth 1 https://github.com/cdisc-org/sdtm-adam-pilot-project.git data/source/cdisc-pilot
```

See [docs/DATA-INVENTORY.md](docs/DATA-INVENTORY.md) for what the package contains.

1. Generate the raw layer:

   ```bash
   python python/generate_raw.py
   ```

2. Trial design domains (TA, TE, TV, TI, TS) are adapted from the PHUSE Test Data Factory
   (SDTMIG 3.2 to 3.4; changes are listed in the script header). Copy `ta/te/tv/ti/ts.xpt` from
   [phuse-org/phuse-scripts](https://github.com/phuse-org/phuse-scripts) `data/sdtm/TDF_SDTM_v1.0/`
   (MIT license) to `data/source/tdf/`, then:

   ```bash
   python python/trial_design.py
   ```

3. Run the SAS programs in order: `sas/sdtm/`, `sas/adam/` (ADSL first), then `sas/tlf/`. In each
   folder run `setup.sas` first; it sets the root path, libraries and shared macros.
4. Run the R programs from the project root in the same order, e.g. `source("r/sdtm/dm.R")`, then
   `r/*/compare.R` in each layer. `adsl.R` comes first in `r/adam/`.
5. define.xml: `python python/make_define.py sdtm` and `python python/make_define.py adam`.
   The spec workbooks (`specs/sdtm-spec.xlsx`, `specs/adam-spec.xlsx`) are not in the repository, so
   define.xml cannot be rebuilt from a clone. The generated files are in `define/`.

---

## Disclaimer

```
Data source: CDISC SDTM/ADaM Pilot Project
(https://github.com/cdisc-org/sdtm-adam-pilot-project)
Study: CDISCPILOT01 (H2Q-MC-LZZT) — legacy data provided by Eli Lilly and Company

This is a learning/portfolio project and is not associated with any actual
regulatory submission. No proprietary or confidential data is included.
All programs in this repository were written from scratch using publicly
available data.
```

# Data Inventory

Source data is **not redistributed** in this repository (`data/source/` is git-ignored).
Data from the CDISC SDTM/ADaM Pilot Project, © CDISC. Used for learning/portfolio purposes only; not related to any regulatory submission.

## How to obtain

```bash
git clone --depth 1 https://github.com/cdisc-org/sdtm-adam-pilot-project.git data/source/cdisc-pilot
```

Retrieved 2026-09-28.

## What is available

Root: `data/source/cdisc-pilot/updated-pilot-submission-package/900172/m5/`

| Layer | Available? | Location | Contents |
|---|---|---|---|
| Raw / CRF data | **No** | `sdtm/blankcrf.pdf` | Annotated CRF (SDTM annotations; named `blankcrf.pdf` per FDA eCTD convention). No raw data — generated with Python (Stage 1). |
| SDTM | Yes | `datasets/cdiscpilot01/tabulations/sdtm/` | AE CM DM DS EX LB MH QS RELREC SC SE SV TA TE TI TS TV VS + SUPPAE SUPPDM SUPPDS SUPPLB |
| ADaM | Yes | `datasets/cdiscpilot01/analysis/adam/datasets/` | ADSL ADAE ADLBC ADLBH ADLBHY ADQSADAS ADQSCIBC ADQSNPIX ADTTE ADVS |
| ADaM programs | Partial | `datasets/cdiscpilot01/analysis/adam/programs/` | `adae.sas`, `at14-5-02.sas` only |
| define.xml | Yes | `sdtm/define.xml`, `adam/datasets/define.xml` | Also `define.pdf`, `define.html`; ADaM `dataguide.pdf` (ADRG) |
| TLF | PDF only | `53-clin-stud-rep/.../cdiscpilot01/cdiscpilot01.pdf` | CSR with embedded tables/figures; no TLF program outputs |
| Lab reference ranges | Yes | `data/source/cdisc-pilot/reference-ranges/` | `lab1_0_1refrangesampledata.xpt` |

Datasets are SAS transport (`.xpt`); a Dataset-JSON (`.json`) copy sits alongside each one.

## Reference answer key (kept outside this repo)

PHUSE TestDataFactory `Updated/` (modern SDTM IG 3.2 / ADaM IG 1.1 rebuild of the same study;
this project itself targets SDTMIG v3.4, so version-driven differences are expected)
is stored separately and is **not opened until the matching stage is finished**. It contains the
SDTM/ADaM specs (`SpecSDTM_define20.xlsx`, `SpecADaM_define20.xlsx`) and Pinnacle 21 reports,
which would otherwise give away the answers.

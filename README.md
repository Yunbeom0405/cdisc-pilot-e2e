# CDISC Pilot — End-to-End Clinical Programming & Dual-Programming QC

> 🚧 Work in progress. Started 2026-09.

<!-- TODO: remove this line when complete. Sections below are filled in at Stage 4. -->

End-to-end reproduction of a clinical trial programming pipeline using the
publicly available CDISC SDTM/ADaM Pilot Project data — from simulated raw
EDC data and mapping specifications through SDTM, ADaM, TLFs, and define.xml,
with dual-programming QC performed in **both SAS and R**.

## Study

**CDISCPILOT01** (original protocol H2Q-MC-LZZT)

> *Safety and Efficacy of the Xanomeline Transdermal Therapeutic System (TTS)
> in Patients with Mild to Moderate Alzheimer's Disease*

- Phase 2, randomized, multi-center, double-blind, placebo-controlled, parallel-group
- Placebo / Xanomeline low dose (54 mg) / Xanomeline high dose (81 mg), 1:1:1, 26 weeks
- 254 subjects randomized (ITT = Safety = 254, Efficacy = 234)
- Primary endpoints: ADAS-Cog(11) at Week 24, CIBIC+ at Week 24

## Approach

<!-- TODO: write after Stage 1 -->
Target standards: **SDTMIG v3.4**, Define-XML v2.1; aCRF follows SDTM-MSG v2.0.

1. **Spec-first** — mapping specifications written before any programming,
   mirroring real-world workflow. Specs feed directly into define.xml generation.
2. **Dual-programming QC** — independent re-implementation and `PROC COMPARE`.
3. **Cross-language validation** — ADaM datasets built in SAS are independently
   reproduced with R `{admiral}` and reconciled.

## Repository structure

<!-- TODO: update to final structure at Stage 4 -->

## Tools

| | |
|---|---|
| SAS | SDTM / ADaM / TLF programming |
| Pinnacle 21 Community | Validation, spec generation, define.xml (v2.1) |
| R + `{sdtm.oak}`, `{admiral}`, `{diffdf}` | Cross-language QC |
| Python (`faker`, `pandas`, `openpyxl`) | Simulated raw EDC data (the Pilot ships SDTM/ADaM only) |

## How to reproduce

Source data is not redistributed in this repository. Download it with:

```bash
git clone --depth 1 https://github.com/cdisc-org/sdtm-adam-pilot-project.git data/source/cdisc-pilot
```

See [docs/DATA-INVENTORY.md](docs/DATA-INVENTORY.md) for what the package contains.

<!-- TODO: add run order -->

---

## Disclaimer

```
Data source: CDISC SDTM/ADaM Pilot Project
  (https://github.com/cdisc-org/sdtm-adam-pilot-project)
Study: CDISCPILOT01 (H2Q-MC-LZZT) — legacy data provided by Eli Lilly and Company

This is a learning/portfolio project and is not associated with any actual
regulatory submission. No proprietary or confidential data is included.
All programs in this repository were written from scratch against publicly
available data.
```

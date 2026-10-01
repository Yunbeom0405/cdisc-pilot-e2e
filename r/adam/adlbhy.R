# Program : adlbhy.R
# Purpose : Create ADaM ADLBHY (modified Hy's law)
# Needs   : ADSL, ADLBC

source("r/adam/setup.R")

adsl <- read_adam("adsl")

# per visit: any ALT/AST and BILI above 1.5 x ULN
visits <- read_adam("adlbc") |>
  filter(PARAMCD %in% c("ALT", "AST", "BILI"), ANL01FL == "Y") |>
  mutate(trans = PARAMCD %in% c("ALT", "AST"), high = R2A1HI > 1.5) |>
  group_by(USUBJID, AVISITN) |>
  summarise(
    AVISIT = max(AVISIT), ADT = max(ADT),
    ABLFL = if_else(any(ABLFL %in% "Y"), "Y", NA_character_),
    ONTRTFL = if_else(any(ONTRTFL %in% "Y"), "Y", NA_character_),
    nt = sum(trans), t = any(trans & high, na.rm = TRUE),
    nb = sum(!trans), b = any(!trans & high, na.rm = TRUE),
    .groups = "drop"
  )

adlbhy <- bind_rows(
  visits |> filter(nt > 0) |> mutate(PARAMCD = "TRANSHY", PARAM = "ALT or AST >1.5 x ULN", AVAL = as.numeric(t)),
  visits |> filter(nb > 0) |> mutate(PARAMCD = "BILIHY", PARAM = "Bilirubin >1.5 x ULN", AVAL = as.numeric(b)),
  visits |> filter(nt > 0, nb > 0) |> mutate(
    PARAMCD = "HYLAW", PARAM = "ALT or AST >1.5 x ULN and Bilirubin >1.5 x ULN", AVAL = as.numeric(t & b)
  )
) |>
  add_adsl(adsl, exprs(
    STUDYID, SITEID, TRTP = TRT01P, TRTPN = TRT01PN, TRTA = TRT01A, TRTAN = TRT01AN, AGE, AGEGR1,
    AGEGR1N, RACE, RACEN, SEX, SAFFL, TRTSDT, TRTEDT
  )) |>
  mutate(AVALC = if_else(AVAL == 1, "Y", "N")) |>
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT)) |>
  derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = AVAL, new_var = BASE) |>
  derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = AVALC, new_var = BASEC)

adlbhy <- finalize(adlbhy, "ADLBHY", keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN"))

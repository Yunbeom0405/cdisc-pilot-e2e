# Program : adtte.R
# Purpose : Create ADaM ADTTE
# Needs   : ADSL, ADAE

source("r/adam/setup.R")

adsl <- read_adam("adsl") |> filter(SAFFL == "Y")

# first treatment-emergent dermatologic event (same-day events: lowest AESEQ)
adae <- read_adam("adae") |>
  filter(TRTEMFL == "Y", !is.na(CQ01NAM)) |>
  filter_extreme(by_vars = exprs(USUBJID), order = exprs(ASTDT, AESEQ), mode = "first")

derm_event <- event_source(
  dataset_name = "adae",
  date = ASTDT,
  set_values_to = exprs(EVNTDESC = "DERMATOLOGIC EVENT", SRCDOM = "ADAE", SRCVAR = "ASTDT", SRCSEQ = AESEQ)
)

end_of_study <- censor_source(
  dataset_name = "adsl",
  date = EOSDT,
  censor = 1,
  set_values_to = exprs(EVNTDESC = "END OF STUDY", SRCDOM = "ADSL", SRCVAR = "EOSDT")
)

trt_stopped <- event_source(
  dataset_name = "adsl",
  filter = EOTSTT == "DISCONTINUED",
  date = TRTEDT,
  set_values_to = exprs(EVNTDESC = "TREATMENT DISCONTINUED", SRCDOM = "ADSL", SRCVAR = "TRTEDT")
)

trt_completed <- censor_source(
  dataset_name = "adsl",
  date = TRTEDT,
  censor = 1,
  set_values_to = exprs(EVNTDESC = "TREATMENT COMPLETED", SRCDOM = "ADSL", SRCVAR = "TRTEDT")
)

sources <- list(adsl = adsl, adae = adae)

adtte <- derive_param_tte(
  dataset_adsl = adsl,
  start_date = TRTSDT,
  event_conditions = list(derm_event),
  censor_conditions = list(end_of_study),
  source_datasets = sources,
  set_values_to = exprs(PARAMCD = "TTDE", PARAM = "Time to First Dermatologic Event (Days)")
) |>
  derive_param_tte(
    dataset_adsl = adsl,
    start_date = TRTSDT,
    event_conditions = list(trt_stopped),
    censor_conditions = list(trt_completed),
    source_datasets = sources,
    set_values_to = exprs(PARAMCD = "TTDISC", PARAM = "Time to Treatment Discontinuation (Days)")
  ) |>
  derive_vars_duration(new_var = AVAL, start_date = STARTDT, end_date = ADT) |>
  add_adsl(adsl, exprs(
    SITEID, TRTA = TRT01A, TRTAN = TRT01AN, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, SAFFL,
    TRTSDT, TRTEDT
  ))

adtte <- finalize(adtte, "ADTTE", keys = c("STUDYID", "USUBJID", "PARAMCD"))

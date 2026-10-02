# Program : t_lb_shift.R
# Purpose : Table 23 Shifts in Laboratory Chemistry Values, Baseline to On-treatment

source("r/tlf/setup.R")

adsl <- read_adam("adsl") |> filter(SAFFL == "Y")
bign <- table(factor(adsl$TRT01A, levels = trt_levels))

lb <- read_adam("adlbc") |>
  filter(ONTRTFL == "Y", SAFFL == "Y", !is.na(BNRIND), !is.na(ANRIND)) |>
  mutate(TRTA = factor(TRTA, levels = trt_levels))

shifts <- tibble(
  seq = 0:6,
  txt = c("N", "Normal to Low", "Normal to High", "Low to Normal", "Low to High", "High to Normal", "High to Low"),
  BNRIND = c("", "NORMAL", "NORMAL", "LOW", "LOW", "HIGH", "HIGH"),
  ANRIND = c("", "LOW", "HIGH", "NORMAL", "HIGH", "NORMAL", "LOW")
)

# subjects with at least one on-treatment value in the shift category; seq 0 = all evaluable
count_n <- function(p, b, a, trt) {
  x <- lb[lb$PARAMCD == p & lb$TRTA == trt & (b == "" | (lb$BNRIND == b & lb$ANRIND == a)), ]
  n_distinct(x$USUBJID)
}

cnt <- lb |>
  distinct(PARAMCD, PARAM) |>
  cross_join(shifts) |>
  rowwise() |>
  mutate(
    n_1 = count_n(PARAMCD, BNRIND, ANRIND, trt_levels[1]),
    n_2 = count_n(PARAMCD, BNRIND, ANRIND, trt_levels[2]),
    n_3 = count_n(PARAMCD, BNRIND, ANRIND, trt_levels[3])
  ) |>
  ungroup()

cell <- function(n, den, seq) if_else(seq == 0, as.character(n), npct(n, den, 1))

df <- cnt |>
  group_by(PARAMCD) |>
  mutate(d_1 = n_1[1], d_2 = n_2[1], d_3 = n_3[1]) |>
  ungroup() |>
  mutate(
    C1 = cell(n_1, d_1, seq),
    C2 = cell(n_2, d_2, seq),
    C3 = cell(n_3, d_3, seq),
    LABEL = txt,
    INDENT = 1L
  ) |>
  bind_rows(
    distinct(cnt, PARAMCD, PARAM) |>
      mutate(seq = -1L, LABEL = PARAM, INDENT = 0L, C1 = "", C2 = "", C3 = "")
  ) |>
  arrange(PARAMCD, seq) |>
  mutate(ROW = row_number()) |>
  select(ROW, LABEL, INDENT, C1:C3)

save_df(df, "t_lb_shift", "Table 23 Shifts in Laboratory Chemistry Values from Baseline to On-treatment",
  paste0(trt_levels, " (N=", bign, ")"),
  c("Population: Safety. N: subjects with a baseline and at least one on-treatment value. Range category (low/normal/high) from the reference range.",
    "Cells: subjects (percent of N) with at least one on-treatment value in the category; a subject can be in more than one shift."))

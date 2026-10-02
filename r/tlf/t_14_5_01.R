# Program : t_14_5_01.R
# Purpose : Table 14-5.01 Incidence of Treatment Emergent Adverse Events by Treatment Group

source("r/tlf/setup.R")

adsl <- read_adam("adsl") |> filter(SAFFL == "Y")
bign <- table(factor(adsl$TRT01A, levels = trt_levels))

te <- read_adam("adae") |>
  filter(TRTEMFL == "Y", SAFFL == "Y") |>
  mutate(TRTA = factor(TRTA, levels = trt_levels))

# subjects and events per row and treatment, zero-filled
tally <- function(df, ...) {
  df |>
    group_by(..., TRTA) |>
    summarise(n = n_distinct(USUBJID), ev = n(), .groups = "drop") |>
    pivot_wider(names_from = TRTA, values_from = c(n, ev), values_fill = 0, names_expand = TRUE)
}

rows <- bind_rows(
  tally(te) |> mutate(lvl = 0),
  tally(te, AEBODSYS) |> mutate(lvl = 1),
  tally(te, AEBODSYS, AEDECOD) |> mutate(lvl = 2)
)
names(rows) <- sub("Xanomeline High Dose", "3", sub("Xanomeline Low Dose", "2", sub("Placebo", "1", names(rows))))

fisher <- function(x1, m1, x2, m2) {
  mapply(\(a, b) fisher.test(matrix(c(a, m1 - a, b, m2 - b), 2))$p.value, x1, x2)
}

cell <- function(n, ev, den) if_else(n == 0, "0", paste0(npct(n, den, 1), " [", ev, "]"))

df <- rows |>
  mutate(
    tot = n_1 + n_2 + n_3,
    any = lvl > 0,
    ptord = if_else(lvl == 2, -tot, 0)
  ) |>
  arrange(any, AEBODSYS, lvl, ptord, AEDECOD) |>
  mutate(
    ROW = row_number(),
    LABEL = coalesce(AEDECOD, AEBODSYS, "ANY BODY SYSTEM"),
    INDENT = as.integer(lvl == 2),
    C1 = cell(n_1, ev_1, bign[1]),
    C2 = cell(n_2, ev_2, bign[2]),
    C3 = cell(n_3, ev_3, bign[3]),
    C4 = pv(fisher(n_1, bign[1], n_2, bign[2])),
    C5 = pv(fisher(n_1, bign[1], n_3, bign[3]))
  ) |>
  select(ROW, LABEL, INDENT, C1:C5)

save_df(df, "t_14_5_01", "Table 14-5.01 Incidence of Treatment Emergent Adverse Events by Treatment Group",
  c(paste0(trt_levels, " (N=", bign, ")"), "p Placebo vs. Low", "p Placebo vs. High"),
  c("Population: Safety. Treatment emergent: events which start on or after the first dose. Coded with MedDRA.",
    "Cells: subjects with at least one event (percent of N) [number of events]. p-values: two-sided Fisher exact test."))

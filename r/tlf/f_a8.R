# Program : f_a8.R
# Purpose : Figure A8 eDISH, peak ALT vs peak bilirubin (x ULN)
#           (+ statistics table f_a8_stats for QC)

source("r/tlf/setup.R")
library(ggplot2)

adsl <- read_adam("adsl") |> filter(SAFFL == "Y")
bign <- table(factor(adsl$TRT01A, levels = trt_levels))

# peak on-treatment value as multiple of the upper limit, per subject
ed <- read_adam("adlbc") |>
  filter(ONTRTFL == "Y", SAFFL == "Y", PARAMCD %in% c("ALT", "BILI"), !is.na(AVAL), !is.na(A1HI)) |>
  mutate(TRTA = factor(TRTA, levels = trt_levels), X = AVAL / A1HI) |>
  group_by(USUBJID, TRTA, PARAMCD) |>
  summarise(X = max(X), .groups = "drop") |>
  pivot_wider(names_from = PARAMCD, values_from = X) |>
  filter(!is.na(ALT), !is.na(BILI))

st <- ed |>
  group_by(TRTA, .drop = FALSE) |>
  summarise(n = n(), a = sum(ALT >= 3), b = sum(BILI >= 2), ab = sum(ALT >= 3 & BILI >= 2))

df <- tibble(
  LABEL = c("N (ALT and bilirubin measured)", "ALT >= 3 x ULN", "Bilirubin >= 2 x ULN",
    "ALT >= 3 x ULN and bilirubin >= 2 x ULN"),
  C1 = c(st$n[1], npct(st$a[1], st$n[1], 1), npct(st$b[1], st$n[1], 1), npct(st$ab[1], st$n[1], 1)),
  C2 = c(st$n[2], npct(st$a[2], st$n[2], 1), npct(st$b[2], st$n[2], 1), npct(st$ab[2], st$n[2], 1)),
  C3 = c(st$n[3], npct(st$a[3], st$n[3], 1), npct(st$b[3], st$n[3], 1), npct(st$ab[3], st$n[3], 1))
) |>
  mutate(ROW = row_number(), INDENT = 0L, across(C1:C3, as.character)) |>
  relocate(ROW)

save_df(df, "f_a8_stats", "Figure A8 Statistics: Peak ALT and Bilirubin",
  paste0(trt_levels, " (N=", bign, ")"),
  c("Population: Safety. Peak on-treatment value as multiple of the upper limit of normal (ULN) at the same record.",
    "Cells: subjects (percent of N with both measurements)."),
  src = "f_a8")

p <- ggplot(ed, aes(ALT, BILI, colour = TRTA)) +
  geom_point(size = 2, alpha = 0.8) +
  geom_vline(xintercept = 3, linetype = "dashed") +
  geom_hline(yintercept = 2, linetype = "dashed") +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "Figure A8 eDISH: Peak ALT vs Peak Total Bilirubin (x ULN) by Treatment Group",
    x = "Peak ALT (x ULN)", y = "Peak total bilirubin (x ULN)", colour = NULL,
    caption = "Population: Safety. One point per subject, peak on-treatment value. Reference lines: ALT 3 x ULN, bilirubin 2 x ULN. Source: r/tlf/f_a8.R"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "f_a8.png"), p, width = 9, height = 6, dpi = 150)

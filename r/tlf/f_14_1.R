# Program : f_14_1.R
# Purpose : Figure 14-1 Kaplan-Meier: Time to First Dermatologic Event
#           (+ statistics table f_14_1_stats for QC)

source("r/tlf/setup.R")
suppressPackageStartupMessages({
  library(survival)
  library(ggplot2)
})

tte <- read_adam("adtte") |>
  filter(PARAMCD == "TTDE", SAFFL == "Y") |>
  mutate(TRTA = factor(TRTA, levels = trt_levels), EVENT = 1 - CNSR)

# log-log confidence intervals, as SAS PROC LIFETEST
fit <- survfit(Surv(AVAL, EVENT) ~ TRTA, data = tte, conf.type = "log-log")

times <- seq(30, 180, by = 30)
est <- summary(fit, times = times, extend = TRUE)
med <- quantile(fit, probs = 0.5)
med_txt <- ifelse(is.na(med$quantile), "NE",
  paste0(f(med$quantile, 1), " (", ifelse(is.na(med$lower), "NE", f(med$lower, 1)), ";",
    ifelse(is.na(med$upper), "NE", f(med$upper, 1)), ")"))

n <- table(tte$TRTA)
events <- tapply(tte$EVENT, tte$TRTA, sum)
km <- matrix(f(est$surv, 3), nrow = length(times))

df <- tibble(
  LABEL = c("N", "Events", "Censored", "Median (95% CI)", paste("Event-free at Day", times)),
  C1 = c(n[1], events[1], n[1] - events[1], med_txt[1], km[, 1]),
  C2 = c(n[2], events[2], n[2] - events[2], med_txt[2], km[, 2]),
  C3 = c(n[3], events[3], n[3] - events[3], med_txt[3], km[, 3])
) |>
  mutate(ROW = row_number(), INDENT = 0L, across(C1:C3, as.character)) |>
  relocate(ROW)

save_df(df, "f_14_1_stats", "Figure 14-1 Statistics: Time to First Dermatologic Event",
  paste0(trt_levels, " (N=", n, ")"),
  c("Population: Safety. Kaplan-Meier estimates, 95% CI with log-log transformation.", "NE: not estimable."),
  src = "f_14_1")

# Kaplan-Meier plot
curve <- tibble(time = fit$time, surv = fit$surv, strata = rep(trt_levels, fit$strata)) |>
  bind_rows(tibble(time = 0, surv = 1, strata = trt_levels)) |>
  arrange(strata, time)

p <- ggplot(curve, aes(time, surv, colour = factor(strata, levels = trt_levels))) +
  geom_step() +
  scale_x_continuous(breaks = seq(0, 210, 30)) +
  labs(
    title = "Figure 14-1 Kaplan-Meier: Time to First Dermatologic Event by Treatment Group",
    x = "Days from first dose", y = "Probability of no dermatologic event", colour = NULL,
    caption = "Population: Safety. Censored at end of study. Source: r/tlf/f_14_1.R"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "f_14_1.png"), p, width = 9, height = 5.5, dpi = 150)

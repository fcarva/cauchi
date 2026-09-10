# Funcoes compartilhadas do relatorio Box-Jenkins.

OUT_FIG <- "output/figures"
OUT_TAB <- "output/tables"
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_TAB, recursive = TRUE, showWarnings = FALSE)

read_series <- function() {
  x <- readr::read_csv("data/processed/serie_diaria.csv", show_col_types = FALSE)
  x$date <- as.Date(x$date)
  x
}

write_table <- function(x, name) {
  readr::write_csv(as.data.frame(x), file.path(OUT_TAB, name))
}

save_gg <- function(plot, name, width = 8, height = 5) {
  ggplot2::ggsave(file.path(OUT_FIG, name), plot, width = width, height = height, dpi = 160)
}

critical_p <- function(stat, critical) {
  critical <- sort(as.numeric(critical), decreasing = TRUE)
  if (!is.finite(stat)) return(NA_real_)
  if (stat <= min(critical)) return(0.01)
  if (stat >= max(critical)) return(0.10)
  approx(x = critical, y = c(0.10, 0.05, 0.01)[seq_along(critical)],
         xout = stat, rule = 2)$y
}

run_unit_root_tests <- function(x, label, max_lag = 12) {
  rows <- list()
  for (type in c("none", "drift", "trend")) {
    fit <- urca::ur.df(x, type = type, lags = max_lag, selectlags = "AIC")
    stat <- as.numeric(fit@teststat[1])
    cv <- as.numeric(fit@cval[1, ])
    rows[[length(rows) + 1]] <- data.frame(
      series = label, test = "ADF", specification = type,
      statistic = stat, critical_10 = cv[1], critical_5 = cv[2], critical_1 = cv[3],
      p_value_approx = critical_p(stat, cv), lags = max_lag,
      lag_selection = "AIC", stringsAsFactors = FALSE
    )
  }
  for (model in c("constant", "trend")) {
    fit <- urca::ur.pp(x, type = "Z-tau", model = model, lags = "short")
    stat <- as.numeric(fit@teststat[1])
    cv <- as.numeric(fit@cval[1, ])
    rows[[length(rows) + 1]] <- data.frame(
      series = label, test = "PP", specification = model,
      statistic = stat, critical_10 = cv[1], critical_5 = cv[2], critical_1 = cv[3],
      p_value_approx = critical_p(stat, cv), lags = NA_integer_,
      lag_selection = "short Bartlett", stringsAsFactors = FALSE
    )
  }
  for (type in c("mu", "tau")) {
    fit <- urca::ur.kpss(x, type = type, lags = "short")
    stat <- as.numeric(fit@teststat)
    cv <- as.numeric(fit@cval[1, ])
    rows[[length(rows) + 1]] <- data.frame(
      series = label, test = "KPSS", specification = type,
      statistic = stat, critical_10 = cv[1], critical_5 = cv[2], critical_1 = cv[3],
      p_value_approx = critical_p(stat, cv), lags = NA_integer_,
      lag_selection = "short Bartlett", stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

fit_candidate <- function(x, order, seasonal = c(0, 0, 0)) {
  forecast::Arima(x, order = order, seasonal = list(order = seasonal, period = 7),
                  method = "ML", include.drift = FALSE)
}

model_row <- function(fit, name) {
  cf <- stats::coef(fit)
  se <- sqrt(diag(fit$var.coef))
  data.frame(
    model = name,
    coefficients = paste(names(cf), round(cf, 6), collapse = "; "),
    standard_errors = paste(names(se), round(se, 6), collapse = "; "),
    t_statistics = paste(names(cf), round(cf / se, 3), collapse = "; "),
    sigma2 = unname(fit$sigma2), loglik = as.numeric(logLik(fit)),
    AIC = AIC(fit), BIC = BIC(fit), nobs = stats::nobs(fit),
    stringsAsFactors = FALSE
  )
}

metric_row <- function(actual, predicted, model, scheme) {
  err <- actual - predicted
  data.frame(
    scheme = scheme, model = model,
    RMSE = sqrt(mean(err^2, na.rm = TRUE)),
    MAE = mean(abs(err), na.rm = TRUE),
    MAPE = mean(abs(err / actual), na.rm = TRUE) * 100,
    stringsAsFactors = FALSE
  )
}

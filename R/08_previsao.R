# 08_previsao.R  --  Questao 7: previsao fora da amostra vs RW e sazonal ingenuo.

source("R/99_helpers.R")
serie <- read_series()
y <- as.numeric(serie$taxa_esperada)
H <- 24L
s <- 7L
T0 <- length(y) - H
fit_full <- readRDS(file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
fit_train <- fit_candidate(y[seq_len(T0)], forecast::arimaorder(fit_full)[1:3])
fc <- forecast::forecast(fit_train, h = H, level = 95)

actual <- y[(T0 + 1):length(y)]
fixed <- as.numeric(fc$mean)
rw_fixed <- rep(y[T0], H)
seasonal_fixed <- y[(T0 - s + 1):T0]
seasonal_fixed <- rep(seasonal_fixed, length.out = H)

one_step <- numeric(H)
for (j in seq_len(H)) {
	t <- T0 + j - 1L
	refit_state <- forecast::Arima(y[seq_len(t)], model = fit_train)
	one_step[j] <- as.numeric(forecast::forecast(refit_state, h = 1)$mean[1])
}
rw_one <- y[T0:(length(y) - 1L)]
seasonal_one <- y[(T0 - s + 1):(length(y) - s)]

metrics <- rbind(
	metric_row(actual, fixed, "ARIMA", "origem_fixa_24_passos"),
	metric_row(actual, rw_fixed, "passeio_aleatorio", "origem_fixa_24_passos"),
	metric_row(actual, seasonal_fixed, "sazonal_ingenuo", "origem_fixa_24_passos"),
	metric_row(actual, one_step, "ARIMA", "origem_movel_1_passo"),
	metric_row(actual, rw_one, "passeio_aleatorio", "origem_movel_1_passo"),
	metric_row(actual, seasonal_one, "sazonal_ingenuo", "origem_movel_1_passo")
)
write_table(metrics, "q7_metricas_previsao.csv")

coverage <- mean(actual >= as.numeric(fc$lower[, 1]) & actual <= as.numeric(fc$upper[, 1]))
write_table(data.frame(horizonte = H, cobertura_intervalo_95 = coverage), "q7_cobertura.csv")

plot_df <- data.frame(
	date = serie$date[(T0 + 1):length(y)], observed = actual,
	forecast = fixed, lower = as.numeric(fc$lower[, 1]), upper = as.numeric(fc$upper[, 1])
)
p <- ggplot2::ggplot(plot_df, ggplot2::aes(date)) +
	ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper), fill = "#9ecae1", alpha = .5) +
	ggplot2::geom_line(ggplot2::aes(y = observed), color = "#16425B") +
	ggplot2::geom_line(ggplot2::aes(y = forecast), color = "#C44536") +
	ggplot2::labs(title = "Previsao fora da amostra", x = NULL, y = "%") + ggplot2::theme_minimal()
save_gg(p, "q7_previsao.png")

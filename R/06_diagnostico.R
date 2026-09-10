# 06_diagnostico.R  --  Questao 5: residuos (Ljung-Box, Jarque-Bera, ARCH-LM).

source("R/99_helpers.R")
serie <- read_series()
fit <- readRDS(file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
res <- as.numeric(stats::residuals(fit))
res <- res[is.finite(res)]

png(file.path(OUT_FIG, "q5_diagnostico_residuos.png"), width = 1400, height = 1000, res = 140)
par(mfrow = c(2, 2))
plot(res, type = "l", main = "Residuos", xlab = "Tempo", ylab = "residuo")
acf(res, lag.max = 42, main = "FAC dos residuos")
hist(res, breaks = "FD", main = "Histograma dos residuos", xlab = "residuo")
qqnorm(res, main = "Q-Q plot"); qqline(res, col = "#C44536")
dev.off()

lb_lag <- 14L
lb <- stats::Box.test(res, lag = lb_lag, type = "Ljung-Box", fitdf = length(stats::coef(fit)))
n <- length(res)
skew <- mean((res - mean(res))^3) / sd(res)^3
kurt <- mean((res - mean(res))^4) / sd(res)^4
jb_stat <- n / 6 * (skew^2 + (kurt - 3)^2 / 4)
jb_p <- stats::pchisq(jb_stat, df = 2, lower.tail = FALSE)

arch_lag <- 7L
sq <- res^2
z <- stats::embed(sq, arch_lag + 1)
arch_fit <- stats::lm(z[, 1] ~ z[, -1])
arch_stat <- nrow(z) * summary(arch_fit)$r.squared
arch_p <- stats::pchisq(arch_stat, df = arch_lag, lower.tail = FALSE)

diagnostico <- data.frame(
	teste = c("Ljung-Box", "Jarque-Bera", "ARCH-LM"),
	estatistica = c(unname(lb$statistic), jb_stat, arch_stat),
	graus_liberdade = c(lb_lag - length(stats::coef(fit)), 2L, arch_lag),
	p_valor = c(lb$p.value, jb_p, arch_p),
	stringsAsFactors = FALSE
)
write_table(diagnostico, "q5_diagnostico.csv")

overfits <- list(
	"ARIMA(4,1,2)" = fit_candidate(serie$taxa_esperada, c(4, 1, 2)),
	"ARIMA(3,1,3)" = fit_candidate(serie$taxa_esperada, c(3, 1, 3))
)
overfit_table <- do.call(rbind, Map(model_row, overfits, names(overfits)))
write_table(overfit_table, "q5_sobreacte.csv")

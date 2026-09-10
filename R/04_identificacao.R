# 04_identificacao.R  --  Questao 3: FAC/FACP -> 3 candidatos.

source("R/99_helpers.R")
serie <- read_series()
dif1 <- diff(serie$taxa_esperada)

png(file.path(OUT_FIG, "q3_fac_ficp.png"), width = 1400, height = 700, res = 140)
par(mfrow = c(1, 2))
acf(dif1, lag.max = 42, main = "FAC da primeira diferenca")
pacf(dif1, lag.max = 42, main = "FACP da primeira diferenca")
dev.off()

candidatos <- data.frame(
	model = c("ARIMA(1,1,0)", "ARIMA(1,1,1)", "ARIMA(3,1,3)"),
	p = c(1L, 1L, 3L), d = 1L, q = c(0L, 1L, 3L),
	justificativa = c(
		"Persistencia no primeiro lag da diferenca.",
		"Especificacao intermediaria para persistencia e choque.",
		"Estrutura estendida para os lags persistentes e a heterocedasticidade residual observados."
	), stringsAsFactors = FALSE
)
write_table(candidatos, "q3_candidatos.csv")

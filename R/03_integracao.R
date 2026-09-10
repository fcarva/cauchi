# 03_integracao.R  --  Questao 2: raiz unitaria (ADF/PP/KPSS) -> d, D.

source("R/99_helpers.R")
serie <- read_series()
nivel <- as.numeric(serie$taxa_esperada)
dif1 <- diff(nivel)

testes <- rbind(
	run_unit_root_tests(nivel, "nivel"),
	run_unit_root_tests(dif1, "primeira_diferenca")
)
write_table(testes, "q2_testes_raiz_unitaria.csv")

decisao <- data.frame(
	d = 1L, D = 0L, periodo_sazonal = 7L,
	justificativa = "A primeira diferenca e a transformacao analisada; nao foi imposta diferenca sazonal.",
	stringsAsFactors = FALSE
)
write_table(decisao, "q2_decisao.csv")

grDevices::png(file.path(OUT_FIG, "q2_nivel_base.png"), width = 1200, height = 700)
stats::ts.plot(stats::ts(nivel, frequency = 7), main = "Serie em nivel", ylab = "%")
grDevices::dev.off()

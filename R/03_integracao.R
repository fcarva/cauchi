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

## ---- Q2(c): D e o periodo sazonal, decididos com evidencia -------------------
# O periodo candidato e s = 7 porque a Kalshi negocia nos sete dias da semana --
# medido em output/tables/q1_atividade_semanal.csv, nao suposto. Resta testar se
# esse ciclo exige DIFERENCA sazonal (D = 1) ou apenas eventual estrutura ARMA.
#
# Tres evidencias independentes, para nao decidir por omissao:
#   (i)   testes de raiz unitaria sazonal (OCSB e Canova-Hansen, via nsdiffs);
#   (ii)  a FAC da primeira diferenca nos lags sazonais 7, 14 e 21 contra a banda
#         de 95% -- raiz sazonal se manifesta como autocorrelacao que NAO decai;
#   (iii) comparacao direta por AIC/BIC entre D = 0 e D = 1 no mesmo modelo base.
s <- PERIODO_SAZONAL
nivel_ts <- stats::ts(nivel, frequency = s)

testa_nsdiffs <- function(teste) {
	out <- tryCatch(forecast::nsdiffs(nivel_ts, test = teste),
	                error = function(e) NA_integer_, warning = function(w) NA_integer_)
	as.integer(out)
}
D_ocsb <- testa_nsdiffs("ocsb")
D_seas <- testa_nsdiffs("seas")

fac <- stats::acf(dif1, lag.max = 3 * s, plot = FALSE)
banda <- stats::qnorm(0.975) / sqrt(length(dif1))
lags_saz <- s * (1:3)
fac_saz <- as.numeric(fac$acf)[lags_saz + 1]

base_D0 <- fit_candidate(nivel, c(1, 1, 1), seasonal = c(0, 0, 0), period = s)
base_D1 <- fit_candidate(nivel, c(1, 1, 1), seasonal = c(0, 1, 0), period = s)

sazonal <- data.frame(
	criterio = c("nsdiffs (OCSB)", "nsdiffs (Canova-Hansen)",
	             sprintf("FAC da 1a diferenca no lag %d", lags_saz),
	             "AIC: D = 0 menos D = 1", "BIC: D = 0 menos D = 1"),
	valor = c(D_ocsb, D_seas, fac_saz,
	          AIC(base_D0) - AIC(base_D1), BIC(base_D0) - BIC(base_D1)),
	referencia = c("D sugerido", "D sugerido", rep(sprintf("banda 95%%: +/- %.4f", banda), 3),
	               "negativo favorece D = 0", "negativo favorece D = 0"),
	stringsAsFactors = FALSE
)
sazonal$conclusao <- c(
	ifelse(is.na(D_ocsb), "inconclusivo", ifelse(D_ocsb == 0, "D = 0", "D = 1")),
	ifelse(is.na(D_seas), "inconclusivo", ifelse(D_seas == 0, "D = 0", "D = 1")),
	ifelse(abs(fac_saz) > banda, "fora da banda", "dentro da banda"),
	ifelse(AIC(base_D0) < AIC(base_D1), "D = 0", "D = 1"),
	ifelse(BIC(base_D0) < BIC(base_D1), "D = 0", "D = 1")
)
write_table(sazonal, "q2_sazonal.csv")

D_escolhido <- 0L
justificativa <- sprintf(
	paste0("d = 1 pelos testes de raiz unitaria em nivel e primeira diferenca. ",
	       "D = 0 decidido com evidencia, nao por omissao: o periodo candidato e s = %d ",
	       "porque a Kalshi negocia nos sete dias (q1_atividade_semanal.csv); ",
	       "nsdiffs sugere D = %s (OCSB) e D = %s (Canova-Hansen); a FAC da primeira ",
	       "diferenca nos lags %s fica %s da banda de 95%% (+/-%.4f); e impor D = 1 %s ",
	       "o AIC e %s o BIC. Ver q2_sazonal.csv."),
	s,
	ifelse(is.na(D_ocsb), "indeterminado", D_ocsb),
	ifelse(is.na(D_seas), "indeterminado", D_seas),
	paste(lags_saz, collapse = ", "),
	ifelse(any(abs(fac_saz) > banda), "parcialmente fora", "dentro"),
	banda,
	ifelse(AIC(base_D0) < AIC(base_D1), "piora", "melhora"),
	ifelse(BIC(base_D0) < BIC(base_D1), "piora", "melhora")
)

decisao <- data.frame(
	d = 1L, D = D_escolhido, periodo_sazonal = s,
	justificativa = justificativa,
	stringsAsFactors = FALSE
)
write_table(decisao, "q2_decisao.csv")

cat("\n=== Q2(c) diferenca sazonal ===\n"); print(sazonal, row.names = FALSE)

grDevices::png(file.path(OUT_FIG, "q2_nivel_base.png"), width = 1200, height = 700)
stats::ts.plot(stats::ts(nivel, frequency = 7), main = "Serie em nivel", ylab = "%")
grDevices::dev.off()

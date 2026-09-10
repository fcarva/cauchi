# 06_diagnostico.R  --  Questao 5: residuos (Ljung-Box, Jarque-Bera, ARCH-LM),
#                       heterocedasticidade no horizonte e log de descartados.

source("R/99_helpers.R")
serie <- read_series()
fit <- readRDS(file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
rotulo <- readr::read_csv(file.path(OUT_TAB, "q4_selecao.csv"),
                          show_col_types = FALSE)$modelo_selecionado[1]
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

## ---- Q5(c): heterocedasticidade LIGADA AO HORIZONTE --------------------------
# O ARCH-LM testa AGRUPAMENTO de volatilidade: variancia alta seguida de variancia
# alta. Nao e o que esta em jogo aqui. A variancia desta serie cai porque o
# horizonte encurta -- perto da reuniao resta menos incerteza a resolver. Isso e
# uma tendencia DETERMINISTICA na variancia, e o ARCH-LM pode nao rejeitar mesmo
# quando ela e enorme, porque a queda e suave em vez de agrupada.
#
# Duas medidas diretas, reportadas ao lado do ARCH-LM:
#   (i)  regressao de log(residuo^2) sobre os dias que faltam para a reuniao;
#   (ii) teste F de igualdade de variancias entre a primeira e a segunda metade.
dif1 <- diff(serie$taxa_esperada)
dias_ate <- as.numeric(serie$expiry - serie$date)[-1]        # alinha com dif1
u2 <- dif1^2

# log(0) e -Inf: os dias sem variacao de preco saem da regressao, e o descarte fica
# registrado na propria tabela em vez de sumir num na.omit silencioso.
#
# O corte e por TOLERANCIA, nao por igualdade exata a zero. A normalizacao das
# probabilidades deixa residuo de ponto flutuante da ordem de 1e-16 pontos
# percentuais, que um parser de CSV pode arredondar para zero e outro nao -- o
# numero de observacoes da regressao chegou a mudar entre readr e read.csv por
# causa disso. Movimento real de preco nesta serie e da ordem de 1e-2; qualquer
# coisa abaixo de 1e-12 e ruido numerico, nao noticia economica.
TOL_ZERO <- 1e-12
usar <- abs(dif1) > TOL_ZERO
reg <- stats::lm(log(u2[usar]) ~ dias_ate[usar])
reg_s <- summary(reg)

metade <- floor(length(dif1) / 2)
f_teste <- stats::var.test(dif1[seq_len(metade)], dif1[(metade + 1):length(dif1)])
var_1 <- stats::var(dif1[seq_len(metade)])
var_2 <- stats::var(dif1[(metade + 1):length(dif1)])

hetero <- data.frame(
	medida = c("Inclinacao de log(dif^2) sobre dias ate a reuniao",
	           "Erro-padrao da inclinacao",
	           "Estatistica t da inclinacao",
	           "p-valor da inclinacao",
	           "Variancia da 1a metade",
	           "Variancia da 2a metade",
	           "Razao de variancias (1a / 2a)",
	           "Estatistica F",
	           "p-valor do teste F",
	           "ARCH-LM (para contraste)",
	           "p-valor do ARCH-LM (para contraste)"),
	valor = c(unname(coef(reg)[2]),
	          reg_s$coefficients[2, 2],
	          reg_s$coefficients[2, 3],
	          reg_s$coefficients[2, 4],
	          var_1, var_2, var_1 / var_2,
	          unname(f_teste$statistic), f_teste$p.value,
	          arch_stat, arch_p),
	stringsAsFactors = FALSE
)
write_table(hetero, "q5_heterocedasticidade.csv")

nota_hetero <- sprintf(
	paste0("Regressao com %d de %d diferencas (%d dias sem variacao de preco, excluidos ",
	       "por log(0)). Inclinacao %+.5f por dia de horizonte (p = %.4g): a dispersao %s ",
	       "conforme a reuniao se aproxima. A variancia cai %.1fx entre a primeira e a ",
	       "segunda metade (F = %.3f, p = %.4g). O ARCH-LM %s (p = %.4f), mas mede outra ",
	       "coisa -- agrupamento de volatilidade, nao tendencia deterministica no horizonte; ",
	       "os dois resultados sao complementares, nao substitutos."),
	sum(usar), length(u2), sum(!usar),
	coef(reg)[2], reg_s$coefficients[2, 4],
	if (coef(reg)[2] > 0) "ENCOLHE" else "CRESCE",
	var_1 / var_2, unname(f_teste$statistic), f_teste$p.value,
	if (arch_p < 0.05) "tambem rejeita a homocedasticidade" else "nao rejeita a homocedasticidade",
	arch_p)

## ---- Q5(e): sobreajuste deliberado -------------------------------------------
# Acrescenta um termo AR e um MA ao modelo selecionado. Se os termos extras forem
# insignificantes e o ajuste nao melhorar, a especificacao esta adequada.
ordem <- forecast::arimaorder(fit)[1:3]
ordem_ar <- ordem + c(1L, 0L, 0L)
ordem_ma <- ordem + c(0L, 0L, 1L)
nome_ar <- sprintf("ARIMA(%d,%d,%d)", ordem_ar[1], ordem_ar[2], ordem_ar[3])
nome_ma <- sprintf("ARIMA(%d,%d,%d)", ordem_ma[1], ordem_ma[2], ordem_ma[3])

overfits <- list(fit_candidate(serie$taxa_esperada, ordem_ar),
                 fit_candidate(serie$taxa_esperada, ordem_ma))
names(overfits) <- c(nome_ar, nome_ma)
overfit_table <- do.call(rbind, Map(model_row, overfits, names(overfits)))
overfit_table$AIC_vs_selecionado <- overfit_table$AIC - AIC(fit)
overfit_table$melhora_AIC <- overfit_table$AIC_vs_selecionado < 0
write_table(overfit_table, "q5_sobreacte.csv")

## ---- Q5(d): log de descartados (continua o aberto no 05) ---------------------
for (i in seq_len(nrow(overfit_table))) {
	m <- overfit_table$model[i]
	rz <- raizes_modelo(overfits[[m]], m)
	inadmissivel <- !all(rz$admissivel)
	registrar_descarte(
		modelo = m,
		etapa = "Q5(e) sobreajuste deliberado",
		motivo = if (inadmissivel) "termo extra torna o polinomio inadmissivel"
		         else if (!overfit_table$melhora_AIC[i]) "termo extra nao melhora o ajuste"
		         else "termo extra melhora o AIC -- REVER a especificacao selecionada",
		evidencia = sprintf("AIC %.4f contra %.4f do %s (diferenca %+.4f); admissivel: %s",
		                    overfit_table$AIC[i], AIC(fit), rotulo,
		                    overfit_table$AIC_vs_selecionado[i], all(rz$admissivel)),
		questao = "Q5(e)"
	)
}
if (lb$p.value < 0.05) {
	registrar_descarte(
		modelo = rotulo, etapa = "Q5(b) autocorrelacao residual",
		motivo = "residuos com autocorrelacao remanescente",
		evidencia = sprintf("Ljung-Box Q = %.4f, %d g.l., p = %.4g",
		                    unname(lb$statistic), lb_lag - length(stats::coef(fit)), lb$p.value),
		questao = "Q5(b)"
	)
}
descartados <- readr::read_csv(file.path(OUT_TAB, "modelos_descartados.csv"),
                               show_col_types = FALSE)

cat("\n=== Q5 diagnostico de", rotulo, "===\n"); print(diagnostico, row.names = FALSE)
cat("\n=== Q5(c) heterocedasticidade no horizonte ===\n"); print(hetero, row.names = FALSE)
cat("\n", nota_hetero, "\n", sep = "")
cat("\n=== Q5(e) sobreajuste ===\n")
print(overfit_table[, c("model", "AIC", "AIC_vs_selecionado", "melhora_AIC")], row.names = FALSE)
cat("\n=== Q5(d) modelos descartados ===\n")
print(as.data.frame(descartados)[, c("modelo", "etapa", "motivo")], row.names = FALSE)

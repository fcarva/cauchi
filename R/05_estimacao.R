# 05_estimacao.R  --  Questao 4: estimacao MV, AIC/BIC, raizes, admissibilidade.

source("R/99_helpers.R")
serie <- read_series()
x <- as.numeric(serie$taxa_esperada)

# Os candidatos vem da Questao 3, nao de uma lista fixa aqui: uma fonte da verdade
# so. Se a FAC/FACP mudar, o 04 muda os candidatos e o 05 acompanha.
candidatos <- readr::read_csv(file.path(OUT_TAB, "q3_candidatos.csv"), show_col_types = FALSE)
specs <- lapply(seq_len(nrow(candidatos)), function(i) {
  list(order    = c(candidatos$p[i], candidatos$d[i], candidatos$q[i]),
       seasonal = c(candidatos$P[i], candidatos$D[i], candidatos$Q[i]),
       period   = candidatos$periodo_sazonal[i])
})
names(specs) <- candidatos$model

fits <- lapply(specs, function(sp)
  fit_candidate(x, sp$order, seasonal = sp$seasonal, period = sp$period))
estimacao <- do.call(rbind, Map(model_row, fits, names(fits)))
write_table(estimacao, "q4_estimacao_modelos.csv")

## ---- Q4(f): raizes e admissibilidade -----------------------------------------
raizes <- do.call(rbind, Map(raizes_modelo, fits, names(fits)))
write_table(raizes, "q4_raizes.csv")

admissivel <- vapply(split(raizes$admissivel, raizes$modelo), all, logical(1))
admissivel <- admissivel[names(fits)]          # preserva a ordem dos candidatos
estimacao$admissivel <- unname(admissivel)
write_table(estimacao, "q4_estimacao_modelos.csv")

## ---- Q4(e) + selecao ---------------------------------------------------------
# ORDEM DAS OPERACOES. Invertibilidade e estacionariedade sao restricoes de
# ADMISSIBILIDADE: um modelo que as viola nao esta em competicao, por melhor que
# seja seu ajuste. Por isso o filtro vem ANTES do criterio de informacao, e nao
# como ressalva depois. A versao anterior aplicava which.min(AIC) direto sobre
# todos os candidatos e elegia um modelo nao-invertivel.
vencedor_aic_irrestrito <- estimacao$model[which.min(estimacao$AIC)]
vencedor_bic_irrestrito <- estimacao$model[which.min(estimacao$BIC)]

elegiveis <- estimacao[estimacao$admissivel, , drop = FALSE]
if (!nrow(elegiveis)) {
  stop("Nenhum candidato satisfaz a restricao de admissibilidade da Q4(f).\n",
       "  Reveja a identificacao na Questao 3 -- nao ha modelo a selecionar.",
       call. = FALSE)
}
vencedor_aic <- elegiveis$model[which.min(elegiveis$AIC)]
vencedor_bic <- elegiveis$model[which.min(elegiveis$BIC)]

selected_name <- vencedor_aic
selected_fit  <- fits[[selected_name]]
saveRDS(selected_fit, file.path(OUT_TAB, "q4_modelo_selecionado.rds"))

divergem <- vencedor_aic != vencedor_bic
selecao <- data.frame(
  modelo_selecionado = selected_name,
  criterio = "AIC entre os modelos admissiveis (Q4f antes de Q4e)",
  vencedor_aic_admissivel = vencedor_aic,
  vencedor_bic_admissivel = vencedor_bic,
  criterios_divergem = divergem,
  vencedor_aic_sem_restricao = vencedor_aic_irrestrito,
  vencedor_bic_sem_restricao = vencedor_bic_irrestrito,
  aic_selecionado = elegiveis$AIC[match(vencedor_aic, elegiveis$model)],
  bic_selecionado = elegiveis$BIC[match(vencedor_aic, elegiveis$model)],
  n_candidatos = nrow(estimacao),
  n_admissiveis = nrow(elegiveis),
  nota = if (divergem) {
    sprintf(paste0("AIC e BIC DIVERGEM entre os admissiveis: AIC escolhe %s, BIC escolhe %s. ",
                   "O BIC penaliza a complexidade mais fortemente (log(n) contra 2 por ",
                   "parametro), e a divergencia e informacao, nao ruido -- reportada aqui ",
                   "em vez de resolvida em silencio."),
            vencedor_aic, vencedor_bic)
  } else {
    sprintf(paste0("AIC e BIC CONCORDAM entre os admissiveis (%s). Sem a restricao de ",
                   "admissibilidade o AIC escolheria %s."),
            vencedor_aic, vencedor_aic_irrestrito)
  },
  stringsAsFactors = FALSE
)
write_table(selecao, "q4_selecao.csv")

## ---- Q5(d): log de modelos descartados (aberto aqui, continuado no 06) --------
inadmissiveis <- estimacao$model[!estimacao$admissivel]
primeiro <- TRUE
for (m in inadmissiveis) {
  r <- raizes[raizes$modelo == m & !raizes$admissivel, ]
  registrar_descarte(
    modelo = m, etapa = "Q4(f) admissibilidade",
    motivo = if (any(r$tipo_raiz == "MA")) "polinomio MA nao-invertivel" else "polinomio AR nao-estacionario",
    evidencia = sprintf("raizes %s com modulo %s (limiar 1 + %s)",
                        paste(unique(r$tipo_raiz), collapse = "/"),
                        paste(sprintf("%.6f", r$modulo), collapse = "; "),
                        format(TOL_RAIZ, scientific = FALSE)),
    questao = "Q4(f)", reiniciar = primeiro
  )
  primeiro <- FALSE
}
if (primeiro) {                                  # nenhum descarte: zera o log
  registrar_descarte(character(0), character(0), character(0), character(0),
                     character(0), reiniciar = TRUE)
}

## ---- Q4(d): convencao de k nos criterios de informacao ------------------------
# A lista pede que se verifique na documentacao se a variancia residual estimada
# entra na contagem de parametros. Em vez de afirmar de memoria, verificamos no
# proprio objeto: logLik() carrega o atributo 'df' que o AIC de fato usa.
k_ref <- selected_fit
k_df <- attr(stats::logLik(k_ref), "df")
k_coef <- length(stats::coef(k_ref))
convencao <- data.frame(
  modelo = selected_name,
  n_coeficientes = k_coef,
  k_usado_pelo_AIC = k_df,
  sigma2_conta_como_parametro = (k_df == k_coef + 1L),
  verificacao = "attr(logLik(fit), 'df') contra length(coef(fit))",
  aic_recalculado = -2 * as.numeric(stats::logLik(k_ref)) + 2 * k_df,
  aic_reportado = AIC(k_ref),
  nota = sprintf(paste0("k = %d para %d coeficientes: a variancia residual estimada %s ",
                        "contabilizada como parametro livre. Toda comparacao AIC/BIC nesta ",
                        "tabela usa a mesma convencao e a mesma amostra efetiva (n = %d), ",
                        "condicao sem a qual os criterios nao sao comparaveis (Q4c)."),
                k_df, k_coef, if (k_df == k_coef + 1L) "E" else "NAO e", stats::nobs(k_ref)),
  stringsAsFactors = FALSE
)
write_table(convencao, "q4_convencao_k.csv")

## ---- Figura das raizes -------------------------------------------------------
# Plotamos as raizes INVERSAS contra o circulo unitario: e a convencao grafica
# usual (forecast::autoplot) e mantem o desenho legivel quando uma raiz e grande.
# Admissivel = ponto DENTRO do circulo. A tabela q4_raizes.csv traz as duas
# escalas, para que o texto possa citar |raiz| > 1 sem ambiguidade.
png(file.path(OUT_FIG, "q4_raizes.png"), width = 1000, height = 800, res = 140)
plot(NA, xlim = c(-1.5, 1.5), ylim = c(-1.5, 1.5), asp = 1,
     xlab = "Parte real", ylab = "Parte imaginaria",
     main = "Raizes inversas dos polinomios")
symbols(0, 0, circles = 1, inches = FALSE, add = TRUE, fg = "grey60")
abline(h = 0, v = 0, col = "grey85", lty = 3)
inv_re <- raizes$parte_real / raizes$modulo^2
inv_im <- -raizes$parte_imaginaria / raizes$modulo^2
cores <- as.integer(factor(raizes$modelo, levels = names(fits)))
points(inv_re, inv_im, pch = ifelse(raizes$admissivel, 19, 4),
       col = cores, cex = 1.2, lwd = 2)
legend("topright", legend = names(fits), col = seq_along(fits), pch = 19, bty = "n", cex = 0.8)
legend("bottomright", legend = c("admissivel", "inadmissivel"), pch = c(19, 4),
       col = "grey30", bty = "n", cex = 0.8)
mtext("Dentro do circulo = raiz de modulo > 1 = admissivel", side = 1, line = 3.6, cex = 0.75)
dev.off()

cat("\n=== Q4 estimacao ===\n")
print(estimacao[, c("model", "sigma2", "AIC", "BIC", "nobs", "admissivel")], row.names = FALSE)
cat("\n=== Q4(f) admissibilidade ===\n")
print(raizes[, c("modelo", "tipo_raiz", "modulo", "admissivel")], row.names = FALSE)
cat(sprintf("\nSelecionado: %s (AIC entre %d admissiveis de %d candidatos)\n",
            selected_name, nrow(elegiveis), nrow(estimacao)))
cat(sprintf("Sem a restricao, o AIC escolheria: %s\n", vencedor_aic_irrestrito))
cat(selecao$nota, "\n")

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
write_table(do.call(rbind, Map(coef_long, fits, names(fits))), "q4_coeficientes.csv")

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
    motivo = if (any(r$tipo_raiz == "MA")) "polinômio MA não-invertível" else "polinômio AR não-estacionário",
    evidencia = sprintf("raízes %s com módulo %s (limiar 1 + %s)",
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
# Pequenos multiplos, um painel por candidato: sobrepor quatro modelos num circulo
# so obrigaria o leitor a casar cores. Forma = tipo de raiz; cor = admissibilidade.
library(ggplot2)
source("R/99_viz.R")
rz <- raizes[!is.na(raizes$modulo), ]
rz$inv_re <- rz$parte_real / rz$modulo^2
rz$inv_im <- -rz$parte_imaginaria / rz$modulo^2
rz$modelo <- factor(rz$modelo, levels = names(fits))
rz$status <- factor(ifelse(rz$admissivel, "Admissível", "Inadmissível"),
                    levels = c("Admissível", "Inadmissível"))
circulo <- data.frame(x = cos(seq(0, 2 * pi, length.out = 361)),
                      y = sin(seq(0, 2 * pi, length.out = 361)))
p_raizes <- ggplot(rz, aes(inv_re, inv_im)) +
  geom_hline(yintercept = 0, colour = COR$grade, linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = COR$grade, linewidth = 0.3) +
  geom_path(data = circulo, aes(x, y), colour = COR$tinta, linewidth = 0.35) +
  geom_point(aes(shape = tipo_raiz, fill = status), size = 2.3, stroke = 0.4,
             colour = "white") +
  scale_shape_manual(values = c(AR = 21, MA = 24), name = NULL) +
  scale_fill_manual(values = c("Admissível" = COR$serie_1, "Inadmissível" = COR$serie_2),
                    name = NULL, drop = FALSE) +
  guides(fill = guide_legend(override.aes = list(shape = 21, size = 2.6)),
         shape = guide_legend(override.aes = list(fill = COR$tinta_fraca, size = 2.6))) +
  scale_x_continuous(limits = c(-1.15, 1.15), breaks = c(-1, 0, 1), labels = escala_br(0)) +
  scale_y_continuous(limits = c(-1.15, 1.15), breaks = c(-1, 0, 1), labels = escala_br(0)) +
  coord_equal() +
  facet_wrap(~modelo, nrow = 1) +
  labs(x = "Parte real", y = "Parte imaginária",
       caption = nota_fonte(paste0(
         "Raízes inversas dos polinômios AR (círculos) e MA (triângulos). É admissível ",
         "a raiz inversa dentro do círculo unitário, com folga de 0,001."))) +
  theme_feds() +
  theme(legend.key.width = unit(0.35, "cm"), legend.spacing.x = unit(0.1, "cm"),
        legend.box.spacing = unit(0.1, "cm"))
salvar_fig(p_raizes, "q4_raizes", altura = 2.6)

cat("\n=== Q4 estimacao ===\n")
print(estimacao[, c("model", "sigma2", "AIC", "BIC", "nobs", "admissivel")], row.names = FALSE)
cat("\n=== Q4(f) admissibilidade ===\n")
print(raizes[, c("modelo", "tipo_raiz", "modulo", "admissivel")], row.names = FALSE)
cat(sprintf("\nSelecionado: %s (AIC entre %d admissiveis de %d candidatos)\n",
            selected_name, nrow(elegiveis), nrow(estimacao)))
cat(sprintf("Sem a restricao, o AIC escolheria: %s\n", vencedor_aic_irrestrito))
cat(selecao$nota, "\n")

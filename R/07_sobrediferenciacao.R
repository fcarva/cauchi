# 07_sobrediferenciacao.R  --  Questao 6: custo de sobrediferenciar (theta -> -1).

source("R/99_helpers.R")
serie <- read_series()
fit <- readRDS(file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
ord <- forecast::arimaorder(fit)
over <- fit_candidate(serie$taxa_esperada, c(ord[1], ord[2] + 1, ord[3]))
write_table(rbind(
	model_row(fit, "selecionado"),
	model_row(over, "sobrediferenciado")
), "q6_comparacao.csv")
write_table(rbind(coef_long(fit, "selecionado"), coef_long(over, "sobrediferenciado")),
            "q6_coeficientes.csv")

co <- stats::coef(over)
ma <- co[grep("^ma", names(co))]
roots <- if (length(ma)) 1 / polyroot(c(1, ma)) else complex()
write_table(data.frame(
	parametro_ma = paste(names(ma), round(ma, 6), collapse = "; "),
	erro_padrao_ma = paste(names(ma), round(sqrt(diag(over$var.coef))[grep("^ma", names(co))], 6), collapse = "; "),
	raiz_modulo = paste(round(Mod(roots), 6), collapse = "; "),
	stringsAsFactors = FALSE
), "q6_ma_raiz.csv")

library(ggplot2)
source("R/99_viz.R")
rot_sel  <- sprintf("A. Selecionado, ARIMA(%d,%d,%d)", ord[1], ord[2], ord[3])
rot_over <- sprintf("B. Sobrediferenciado, ARIMA(%d,%d,%d)", ord[1], ord[2] + 1, ord[3])
f_sel  <- dados_fac(as.numeric(stats::residuals(fit)),  21)
f_over <- dados_fac(as.numeric(stats::residuals(over)), 21)
f_sel  <- f_sel[f_sel$painel == "FAC", ];   f_sel$painel  <- rot_sel
f_over <- f_over[f_over$painel == "FAC", ]; f_over$painel <- rot_over
fac_q6 <- rbind(f_sel, f_over)
fac_q6$painel <- factor(fac_q6$painel, levels = c(rot_sel, rot_over))
attr(fac_q6, "banda") <- max(attr(dados_fac(stats::residuals(fit), 21), "banda"),
                             attr(dados_fac(stats::residuals(over), 21), "banda"))
p_q6 <- grafico_fac(fac_q6) +
  labs(caption = nota_fonte(sprintf(paste0(
    "FAC dos resíduos; faixa sombreada: banda de 95%%; em azul, defasagens fora dela. ",
    "No modelo sobrediferenciado, θ = %s: a raiz MA cai sobre o círculo unitário, ",
    "e a variância residual sobe %s%%."),
    fmt_br(unname(ma[1]), 4),
    fmt_br(100 * (over$sigma2 / fit$sigma2 - 1), 0))))
salvar_fig(p_q6, "q6_fac_residuos", altura = 2.6)

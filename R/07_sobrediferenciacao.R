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

co <- stats::coef(over)
ma <- co[grep("^ma", names(co))]
roots <- if (length(ma)) 1 / polyroot(c(1, ma)) else complex()
write_table(data.frame(
	parametro_ma = paste(names(ma), round(ma, 6), collapse = "; "),
	erro_padrao_ma = paste(names(ma), round(sqrt(diag(over$var.coef))[grep("^ma", names(co))], 6), collapse = "; "),
	raiz_modulo = paste(round(Mod(roots), 6), collapse = "; "),
	stringsAsFactors = FALSE
), "q6_ma_raiz.csv")

png(file.path(OUT_FIG, "q6_fac_residuos.png"), width = 1200, height = 600, res = 140)
par(mfrow = c(1, 2))
acf(stats::residuals(fit), main = "Residuos: modelo selecionado")
acf(stats::residuals(over), main = "Residuos: sobrediferenciado")
dev.off()

# 05_estimacao.R  --  Questao 4: estimacao MV, AIC/BIC, raizes.

source("R/99_helpers.R")
serie <- read_series()
x <- as.numeric(serie$taxa_esperada)
specs <- list(
	"ARIMA(1,1,0)" = c(1, 1, 0),
	"ARIMA(1,1,1)" = c(1, 1, 1),
	"ARIMA(3,1,2)" = c(3, 1, 2)
)
fits <- lapply(specs, function(order) fit_candidate(x, order))
estimacao <- do.call(rbind, Map(model_row, fits, names(fits)))
write_table(estimacao, "q4_estimacao_modelos.csv")

selected_name <- estimacao$model[which.min(estimacao$AIC)]
selected_fit <- fits[[selected_name]]
saveRDS(selected_fit, file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
write_table(data.frame(modelo_selecionado = selected_name, criterio = "AIC"), "q4_selecao.csv")

root_rows <- list()
for (name in names(fits)) {
	fit <- fits[[name]]
	ar <- fit$model$arma
	co <- stats::coef(fit)
	ar_co <- co[grep("^ar", names(co))]
	ma_co <- co[grep("^ma", names(co))]
	roots <- c(if (length(ar_co)) 1 / polyroot(c(1, -ar_co)) else complex(),
						 if (length(ma_co)) 1 / polyroot(c(1, ma_co)) else complex())
	if (!length(roots)) roots <- NA_complex_
	root_rows[[length(root_rows) + 1]] <- data.frame(
		model = name, root_type = c(rep("AR", length(ar_co)), rep("MA", length(ma_co))),
		real = Re(roots), imaginary = Im(roots), modulus = Mod(roots),
		outside_unit_circle = Mod(roots) > 1, stringsAsFactors = FALSE
	)
}
roots <- do.call(rbind, root_rows)
write_table(roots, "q4_raizes.csv")

png(file.path(OUT_FIG, "q4_raizes.png"), width = 1000, height = 800, res = 140)
plot(NA, xlim = c(-2, 2), ylim = c(-2, 2), asp = 1,
		 xlab = "Parte real", ylab = "Parte imaginaria", main = "Raizes dos polinomios")
symbols(0, 0, circles = 1, inches = FALSE, add = TRUE, fg = "grey60")
points(roots$real, roots$imaginary, pch = 19, col = as.factor(roots$model))
legend("topright", legend = unique(roots$model), col = seq_along(unique(roots$model)), pch = 19)
dev.off()

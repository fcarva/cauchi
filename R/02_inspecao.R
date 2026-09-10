# 02_inspecao.R  --  Questao 1: inspecao grafica e transformacao.
# Entrada: data/processed/serie_diaria.csv   Saida: output/figures/q1_*.png

source("R/99_helpers.R")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Pacote ggplot2 ausente")

serie <- read_series()
serie$observacao <- seq_len(nrow(serie))
serie$diferenca <- c(NA_real_, diff(serie$taxa_esperada))

p_level <- ggplot2::ggplot(serie, ggplot2::aes(date, taxa_esperada)) +
	ggplot2::geom_line(color = "#16425B") +
	ggplot2::labs(title = "Ponto medio da faixa-alvo do Fed", x = NULL, y = "%") +
	ggplot2::theme_minimal()
save_gg(p_level, "q1_nivel.png")

p_diff <- ggplot2::ggplot(serie[-1, ], ggplot2::aes(date, diferenca)) +
	ggplot2::geom_hline(yintercept = 0, color = "grey60") +
	ggplot2::geom_line(color = "#C44536") +
	ggplot2::labs(title = "Primeira diferença do ponto medio da faixa-alvo", x = NULL, y = "pontos percentuais") +
	ggplot2::theme_minimal()
save_gg(p_diff, "q1_diferenca.png")

resumo <- data.frame(
	observacoes = nrow(serie), inicio = min(serie$date), fim = max(serie$date),
	media = mean(serie$taxa_esperada), desvio_padrao = sd(serie$taxa_esperada),
	minimo = min(serie$taxa_esperada), maximo = max(serie$taxa_esperada),
	media_abs_diferenca = mean(abs(diff(serie$taxa_esperada))),
	stringsAsFactors = FALSE
)
write_table(resumo, "q1_resumo.csv")

# 02_inspecao.R  --  Questao 1: inspecao grafica e transformacao.
# Entrada: data/processed/serie_diaria.csv   Saida: output/figures/q1_*.png

source("R/99_helpers.R")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Pacote ggplot2 ausente")

serie <- read_series()
serie$observacao <- seq_len(nrow(serie))
serie$diferenca <- c(NA_real_, diff(serie$taxa_esperada))

library(ggplot2)
source("R/99_viz.R")

# Figura da Q1: dois paineis empilhados com o MESMO eixo de datas, como nos FEDS.
# Serie unica por painel -> cor de tinta, sem legenda; o titulo do painel diz o
# que esta plotado. A diferenca e desenhada em hastes a partir do zero, nao em
# linha: e uma sequencia de choques, e a linha sugeriria continuidade entre eles.
eixo_datas <- scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y",
                           expand = expansion(mult = 0.01))
p_level <- ggplot(serie, aes(date, taxa_esperada)) +
	geom_line(colour = COR$tinta, linewidth = 0.5) +
	eixo_datas + scale_y_continuous(labels = escala_br(2)) +
	labs(title = "A. Ponto médio implícito da faixa-alvo", x = NULL, y = "% a.a.") +
	theme_feds() + theme(axis.text.x = element_blank())
p_diff <- ggplot(serie[-1, ], aes(date, diferenca * 100)) +
	geom_hline(yintercept = 0, colour = COR$tinta, linewidth = 0.3) +
	geom_segment(aes(xend = date, yend = 0), colour = COR$serie_1, linewidth = 0.35) +
	eixo_datas + scale_y_continuous(labels = escala_br(0)) +
	labs(title = "B. Primeira diferença", x = NULL, y = "Pontos-base") +
	theme_feds()
p_q1 <- patchwork::wrap_plots(p_level, p_diff, ncol = 1, heights = c(1.15, 1)) +
	patchwork::plot_annotation(
		caption = nota_fonte(sprintf("Contrato %s, %d observações diárias.",
		                             serie$event_ticker[1], nrow(serie))),
		theme = theme_feds())
salvar_fig(p_q1, "q1_serie", altura = 4.4)

resumo <- data.frame(
	observacoes = nrow(serie), inicio = min(serie$date), fim = max(serie$date),
	media = mean(serie$taxa_esperada), desvio_padrao = sd(serie$taxa_esperada),
	minimo = min(serie$taxa_esperada), maximo = max(serie$taxa_esperada),
	media_abs_diferenca = mean(abs(diff(serie$taxa_esperada))),
	stringsAsFactors = FALSE
)
write_table(resumo, "q1_resumo.csv")

## ---- atividade por dia da semana: a base empirica de s = 7 --------------------
# A Kalshi negocia 24/7. Isso NAO e detalhe operacional: define qual periodo
# sazonal faz sentido. Num mercado que fecha aos fins de semana o ciclo natural e
# de 5 dias uteis; num que negocia todos os dias, e de 7. A tabela abaixo mede a
# atividade real do contrato analisado, em vez de supor o calendario.
#
# Corrige uma afirmacao anterior de docs/alinhamento.md, que tratava as variacoes
# de fim de semana como carregamento do ultimo preco ("nao ha pregao"). Ha pregao,
# e ha negocio: o que distingue o fim de semana e a espessura do livro, nao a
# ausencia de negociacao.
snap <- snapshot_dir()
arq_trades <- file.path(snap, "trades.csv")
if (nzchar(snap) && file.exists(arq_trades)) {
	evento <- serie$event_ticker[1]
	trades <- readr::read_csv(arq_trades, show_col_types = FALSE)
	trades$date <- as.Date(substr(trades$created_time, 1, 10))
	trades <- trades[!is.na(trades$date) &
	                 	startsWith(trades$ticker, paste0(evento, "-")) &
	                 	trades$date >= min(serie$date) & trades$date <= max(serie$date), ]
	trades$dia <- dia_da_semana(trades$date)
	dias_serie <- data.frame(date = serie$date, dia = dia_da_semana(serie$date))

	atividade <- data.frame(
		dia_da_semana = DIAS_SEMANA,
		negocios = as.integer(table(trades$dia)[DIAS_SEMANA]),
		contratos = as.numeric(tapply(as.numeric(trades$count_fp), trades$dia,
		                              sum, na.rm = TRUE)[DIAS_SEMANA]),
		dias_no_calendario = as.integer(table(dias_serie$dia)[DIAS_SEMANA]),
		dias_com_negocio = as.integer(table(dia_da_semana(unique(trades$date)))[DIAS_SEMANA]),
		stringsAsFactors = FALSE
	)
	atividade[is.na(atividade)] <- 0
	atividade$negocios_por_dia <- atividade$negocios / atividade$dias_no_calendario
	atividade$fim_de_semana <- atividade$dia_da_semana %in% c("sabado", "domingo")
	write_table(atividade, "q1_atividade_semanal.csv")

	fds <- atividade$fim_de_semana
	message(sprintf(
		"Atividade: %d negocios em %d dias de fim de semana; %d negocios em %d dias uteis.",
		sum(atividade$negocios[fds]),  sum(atividade$dias_com_negocio[fds]),
		sum(atividade$negocios[!fds]), sum(atividade$dias_com_negocio[!fds])))
	message("Mercado ativo nos sete dias -> periodo sazonal candidato s = 7 (Q2c, Q3b, Q7e).")
} else {
	warning("Snapshot indisponivel: q1_atividade_semanal.csv nao foi gerada, e com ela ",
	        "a justificativa empirica de s = 7 (Q2c/Q3b/Q7e).", call. = FALSE)
}

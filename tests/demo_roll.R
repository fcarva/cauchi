# demo_roll.R ----------------------------------------------------------------
# Demonstra, em numeros, por que MODO="contrato_unico" e o default do
# 01_build_series.R: encadear reunioes ("front") injeta saltos de nivel que nao
# sao noticia economica, e sim artefato de construcao -- e que entrariam nos
# testes de raiz unitaria da Questao 2 como falsa quebra estrutural.
#
# RODA SOBRE DADOS SINTETICOS (tests/fixtures/). Serve para validar o pipeline,
# nao para inferencia economica.
# -----------------------------------------------------------------------------
cu    <- read.csv(Sys.getenv("SERIE_CU"),    stringsAsFactors = FALSE)
front <- read.csv(Sys.getenv("SERIE_FRONT"), stringsAsFactors = FALSE)
cu$date <- as.Date(cu$date); front$date <- as.Date(front$date)

# Dias em que o alvo troca de reuniao = roll
troca <- which(c(FALSE, front$event_ticker[-1] != front$event_ticker[-nrow(front)]))
d_front <- diff(front$taxa_esperada)
d_cu    <- diff(cu$taxa_esperada)

salto_roll <- abs(d_front[troca - 1])
dp_normal  <- sd(d_front[-(troca - 1)])

cat("=== Variacao diaria da serie encadeada ('front') ===\n")
cat(sprintf("desvio-padrao em dias normais:        %.2f bps\n", dp_normal * 100))
cat(sprintf("salto medio nos %d dias de roll:       %.2f bps\n",
            length(troca), mean(salto_roll) * 100))
cat(sprintf("razao (salto de roll / dp normal):    %.1fx\n", mean(salto_roll) / dp_normal))
cat("\n=== Serie de contrato unico (default) ===\n")
cat(sprintf("desvio-padrao da variacao diaria:     %.2f bps\n", sd(d_cu) * 100))
cat(sprintf("maior variacao diaria em modulo:      %.2f bps\n", max(abs(d_cu)) * 100))
cat(sprintf("nenhum roll: %d obs de uma unica reuniao (%s)\n",
            nrow(cu), cu$event_ticker[1]))

cat("\n=== Autocorrelacao (previa das Questoes 1-2) ===\n")
a_niv <- acf(cu$taxa_esperada, lag.max = 5, plot = FALSE)$acf[2:6]
a_dif <- acf(d_cu,             lag.max = 5, plot = FALSE)$acf[2:6]
cat("FAC do nivel  (lags 1-5): ", paste(sprintf("%+.3f", a_niv), collapse = "  "), "\n")
cat("FAC da 1a dif (lags 1-5): ", paste(sprintf("%+.3f", a_dif), collapse = "  "), "\n")
cat("Nivel com FAC decaindo devagar e diferenca sem estrutura e a assinatura\n")
cat("de I(1) -- exatamente o que a eficiencia fraca preve. (Aqui e tautologico:\n")
cat("o dado sintetico FOI gerado como passeio aleatorio. Serve so para mostrar\n")
cat("que o pipeline preserva a estrutura, nao como evidencia economica.)\n")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
png("output/figures/comparacao_roll.png", width = 1600, height = 1000, res = 170)
par(mfrow = c(2, 1), mar = c(4, 4.4, 3, 1.2), tck = -0.02)

plot(front$date, front$taxa_esperada, type = "l", col = "firebrick", lwd = 1.5,
     xlab = "", ylab = "taxa esperada (%)",
     main = "Encadeada ('front'): os saltos sao artefato do roll, nao noticia")
abline(v = front$date[troca], lty = 2, col = "grey55")
legend("topleft", c("serie encadeada", "troca de reuniao (roll)"),
       col = c("firebrick", "grey55"), lwd = c(1.5, 1), lty = c(1, 2), bty = "n", cex = 0.8)

plot(cu$date, cu$taxa_esperada, type = "l", col = "steelblue", lwd = 1.6,
     xlab = "", ylab = "taxa esperada (%)",
     main = sprintf("Contrato unico (default): %d obs, um alvo so, sem roll", nrow(cu)))
mtext("DADOS SINTETICOS -- validacao do pipeline, nao inferencia economica",
      side = 1, line = 2.6, cex = 0.72, col = "grey40")
invisible(dev.off())
cat("\ngravado: output/figures/comparacao_roll.png\n")

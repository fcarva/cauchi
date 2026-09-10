# gera_painel_sintetico.R ----------------------------------------------------
# Gera um painel SINTETICO no schema exato que R/00_pull_kalshi.R produz, para
# exercitar o 01 de ponta a ponta sem depender da API da Kalshi.
#
# ISTO NAO E DADO REAL. Vive em tests/fixtures/ de proposito, nunca em
# data/raw/ -- o snapshot entregue ao professor tem de ser dado de verdade.
# -----------------------------------------------------------------------------
set.seed(20260909)

STRIKE_INT <- 0.25
AJUSTE     <- STRIKE_INT / 2
baldes     <- seq(3.25, 5.25, by = STRIKE_INT)   # 9 baldes
strikes    <- baldes[-1]                          # 8 strikes listados
reunioes   <- c("FED-26MAR", "FED-26JUN", "FED-26SEP")
vencimento <- as.Date(c("2026-03-18", "2026-06-17", "2026-09-16"))
n_dias     <- 180

linhas <- list()
for (i in seq_along(reunioes)) {
  # taxa latente evolui como passeio aleatorio (o que a eficiencia fraca preve)
  nivel <- 4.35 + cumsum(rnorm(n_dias, 0, 0.012))
  datas <- vencimento[i] - rev(seq_len(n_dias)) + 1
  for (t in seq_len(n_dias)) {
    # incerteza cai conforme a reuniao se aproxima
    sd_t <- 0.42 * (1 - 0.6 * t / n_dias)
    q  <- dnorm(baldes + AJUSTE, mean = nivel[t], sd = sd_t); q <- q / sum(q)
    sv <- sapply(strikes, function(s) sum(q[baldes >= s]))
    # preco de mercado = sobrevivencia + ruido de microestrutura, em cents
    mid <- pmin(pmax(sv * 100 + rnorm(length(sv), 0, 1.1), 1), 99)
    spread <- runif(length(sv), 1, 3)
    linhas[[length(linhas) + 1L]] <- data.frame(
      event_ticker = reunioes[i],
      outcome      = sprintf("%.2f or above", strikes),
      ticker       = sprintf("%s-T%s", reunioes[i], format(strikes, trim = TRUE)),
      date         = datas[t],
      yes_close    = round(pmin(pmax(mid + rnorm(length(sv), 0, 0.6), 1), 99)) / 100,
      yes_mean     = round(mid) / 100,
      mid          = round(mid) / 100,
      bid          = round(pmax(mid - spread / 2, 1)) / 100,
      ask          = round(pmin(mid + spread / 2, 99)) / 100,
      volume       = rpois(length(sv), 260),
      stringsAsFactors = FALSE
    )
  }
}
painel <- do.call(rbind, linhas)
dir.create("tests/fixtures", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(painel, "tests/fixtures/painel_sintetico.csv", row.names = FALSE)
cat(sprintf("painel sintetico: %d linhas | %d reunioes | %d dias | %d strikes\n",
            nrow(painel), length(reunioes), length(unique(painel$date)), length(strikes)))

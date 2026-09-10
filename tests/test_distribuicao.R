# test_distribuicao.R --------------------------------------------------------
# Valida o nucleo de R/fun_distribuicao.R contra uma distribuicao de resposta
# CONHECIDA. Base R puro: roda com `Rscript tests/test_distribuicao.R` em
# qualquer maquina, sem instalar pacote nenhum.
#
# A ideia: em vez de esperar os dados da Kalshi para so entao descobrir se o
# pipeline esta certo, eu construo uma distribuicao de probabilidade cuja media
# eu conheco, gero dela os precos que a Kalshi publicaria (a funcao de
# sobrevivencia, em cents), e verifico se o pipeline recupera a media original.
# -----------------------------------------------------------------------------

source("R/fun_distribuicao.R")

STRIKE_INT <- 0.25
AJUSTE     <- STRIKE_INT / 2
ok <- TRUE
falhou <- function(msg) { cat("  FALHOU:", msg, "\n"); ok <<- FALSE }
passou <- function(msg) cat("  ok:", msg, "\n")

# ---------------------------------------------------------------------------
# Verdade conhecida: distribuicao sobre baldes de 25 bps da FFR.
# Balde indexado pelo limite INFERIOR s cobre (s, s+0.25]; seu ponto medio
# (o valor esperado da taxa dentro do balde) e s + 0.125.
# ---------------------------------------------------------------------------
baldes <- c(3.50, 3.75, 4.00, 4.25, 4.50)
q      <- c(0.05, 0.15, 0.45, 0.25, 0.10)   # soma 1
stopifnot(abs(sum(q) - 1) < 1e-12)

media_verdadeira <- sum(q * (baldes + AJUSTE))

# Precos que a Kalshi publicaria: strikes listados sao os baldes exceto o mais
# baixo (esse e o "balde extra" que o algoritmo reconstroi da cauda).
strikes_listados <- baldes[-1]
# P(taxa > s_i) = massa dos baldes com limite inferior >= s_i
sobrevivencia <- sapply(strikes_listados, function(s) sum(q[baldes >= s]))
# Kalshi precifica em cents inteiros, limitada a [1, 99]
precos <- pmin(pmax(round(sobrevivencia * 100), 1), 99)

cat("\n=== Montagem ===\n")
cat("distribuicao verdadeira (balde -> prob):\n")
print(setNames(q, sprintf("%.2f", baldes)))
cat(sprintf("media verdadeira da taxa: %.6f%%\n", media_verdadeira))
cat("precos que a Kalshi publicaria (cents, P(taxa > strike)):\n")
print(setNames(precos, sprintf("T%.2f", strikes_listados)))

# ---------------------------------------------------------------------------
cat("\n=== Teste 1: o pipeline recupera a distribuicao e a media ===\n")
aj  <- middle_out(precos)
d   <- massa_de_sobrevivencia(strikes_listados, aj, STRIKE_INT)
mu  <- taxa_esperada(d$strike, d$prob, AJUSTE)

cat("distribuicao recuperada (balde -> prob):\n")
print(setNames(round(d$prob, 4), sprintf("%.2f", d$strike)))
cat(sprintf("media recuperada:  %.6f%%\n", mu))
cat(sprintf("media verdadeira:  %.6f%%\n", media_verdadeira))
erro_bps <- (mu - media_verdadeira) * 100
cat(sprintf("erro: %+.2f pontos-base\n", erro_bps))

if (!identical(d$strike, baldes)) falhou("os baldes recuperados nao batem com os verdadeiros")
if (abs(sum(d$prob) - 1) > 1e-12) falhou("as probabilidades nao somam 1")
if (any(d$prob < 0))              falhou("probabilidade negativa")
if (abs(erro_bps) > 3)            falhou(sprintf("erro de %.2f bps acima do tolerado", erro_bps))
if (ok) passou(sprintf("media recuperada dentro de %.2f bps", abs(erro_bps)))

cat("\n  Nota: o erro residual NAO e bug. A Kalshi precifica em [1,99], nunca\n")
cat("  0 ou 100, entao as duas caudas perdem 1 cent cada e a massa e\n")
cat("  renormalizada por 98. O vies e para o centro da distribuicao e some\n")
cat("  quando as caudas tem massa relevante.\n")

# ---------------------------------------------------------------------------
cat("\n=== Teste 2: o ajuste de meio-balde vale exatamente 12,5 bps ===\n")
mu_sem <- taxa_esperada(d$strike, d$prob, 0)
dif_bps <- (mu - mu_sem) * 100
cat(sprintf("com ajuste:  %.6f%%\nsem ajuste:  %.6f%%\ndiferenca:   %+.2f bps\n",
            mu, mu_sem, dif_bps))
if (abs(dif_bps - 12.5) > 1e-9) falhou("o ajuste nao vale 12,5 bps") else
  passou("omitir o ajuste desloca a serie inteira em -12,5 bps, uniformemente")

# ---------------------------------------------------------------------------
cat("\n=== Teste 3: o erro que a estrutura dos dados convida ===\n")
cat("Tratar cada 'outcome' como balde disjunto e fazer sum(p_i * strike_i)\n")
cat("direto sobre os precos, sem diferenciar a sobrevivencia.\n")
cat("O ponto: o erro nao e um vies constante que se pudesse corrigir depois.\n")
cat("Ele depende do formato da distribuicao e do tamanho da escada de strikes.\n\n")

erro_ingenuo <- function(baldes_, q_) {
  st_list <- baldes_[-1]
  surv    <- sapply(st_list, function(s) sum(q_[baldes_ >= s]))
  prec    <- pmin(pmax(round(surv * 100), 1), 99)
  verdade <- sum(q_ * (baldes_ + AJUSTE))
  # correto
  dd  <- massa_de_sobrevivencia(st_list, middle_out(prec), STRIKE_INT)
  bom <- taxa_esperada(dd$strike, dd$prob, AJUSTE)
  # ingenuo
  ing <- sum((prec / sum(prec)) * st_list) + AJUSTE
  c(correto = (bom - verdade) * 100, ingenuo = (ing - verdade) * 100)
}

# escada curta (5 baldes) e escada larga (12 baldes, mais perto do real da Kalshi)
cenarios <- list(
  "concentrada, escada curta" = list(b = seq(3.50, 4.50, by = 0.25),
                                     q = c(0.05, 0.15, 0.45, 0.25, 0.10)),
  "quase certa, escada curta" = list(b = seq(3.50, 4.50, by = 0.25),
                                     q = c(0.01, 0.03, 0.90, 0.05, 0.01)),
  "difusa, escada larga"      = list(b = seq(2.75, 5.50, by = 0.25),
                                     q = local({ x <- dnorm(seq(2.75, 5.50, by = 0.25), 4.1, 0.55); x / sum(x) })),
  "assimetrica, escada larga" = list(b = seq(2.75, 5.50, by = 0.25),
                                     q = local({ x <- dexp(seq(0, 2.75, by = 0.25), rate = 1.1); x / sum(x) }))
)

res <- t(sapply(cenarios, function(cn) erro_ingenuo(cn$b, cn$q)))
cat("erro em pontos-base, contra a media verdadeira:\n\n")
tab <- data.frame(cenario = rownames(res),
                  pipeline = sprintf("%+.2f", res[, "correto"]),
                  ingenuo  = sprintf("%+.1f", res[, "ingenuo"]))
print(tab, row.names = FALSE)

max_pipe <- max(abs(res[, "correto"]))
max_ing  <- max(abs(res[, "ingenuo"]))
cat(sprintf("\npior caso -- pipeline: %.2f bps | ingenuo: %.1f bps (%.0fx maior)\n",
            max_pipe, max_ing, max_ing / max(max_pipe, 1e-9)))
if (max_pipe > 5)         falhou(sprintf("pipeline errou %.2f bps em algum cenario", max_pipe))
if (max_ing < 3 * max_pipe) falhou("o metodo ingenuo nao se mostrou pior") else
  passou("o erro ingenuo e grande e varia com o formato da distribuicao -- nao da para corrigir a posteriori")

# ---------------------------------------------------------------------------
cat("\n=== Teste 4: middle-out conserta violacao de nao-arbitragem ===\n")
# Preco de um strike ALTO acima de um strike baixo viola P(>s) decrescente.
precos_ruins <- precos
precos_ruins[3] <- precos_ruins[2] + 7      # inversao artificial
cat("precos com violacao: ", paste(precos_ruins, collapse = ", "), "\n")
aj2 <- middle_out(precos_ruins)
cat("depois do middle-out: ", paste(aj2, collapse = ", "), "\n")
if (any(diff(aj2) > 0)) falhou("ainda ha precos crescentes em strike") else
  passou("sobrevivencia volta a ser nao-crescente")
d2 <- massa_de_sobrevivencia(strikes_listados, aj2, STRIKE_INT)
if (any(d2$prob < 0)) falhou("massa negativa apos o conserto") else
  passou("nenhuma massa negativa")

# ---------------------------------------------------------------------------
cat("\n=== Teste 5: caso degenerado (mercado com certeza quase total) ===\n")
precos_cert <- c(99, 99, 99, 2)
aj3 <- middle_out(precos_cert)
d3  <- massa_de_sobrevivencia(strikes_listados, aj3, STRIKE_INT)
mu3 <- taxa_esperada(d3$strike, d3$prob, AJUSTE)
cat(sprintf("precos %s -> media %.4f%% (esperado: perto de %.3f)\n",
            paste(precos_cert, collapse = ","), mu3, 4.25 + AJUSTE))
if (!is.finite(mu3))                       falhou("media nao-finita")
if (mu3 < min(baldes) || mu3 > max(baldes) + STRIKE_INT)
  falhou("media fora da faixa dos strikes") else
  passou("media dentro da faixa plausivel")

# ---------------------------------------------------------------------------
cat("\n=== Teste 6: caminho diario completo, com ruido de negociacao ===\n")
set.seed(42)
n_dias <- 180
# taxa esperada "verdadeira" evoluindo como um passeio aleatorio (o que a
# hipotese de eficiencia fraca preve para a expectativa de mercado)
caminho_verdadeiro <- 4.10 + cumsum(rnorm(n_dias, 0, 0.010))
recuperado <- numeric(n_dias)
for (t in seq_len(n_dias)) {
  # distribuicao normal discretizada em torno da taxa verdadeira do dia
  centros <- baldes + AJUSTE
  qt <- dnorm(centros, mean = caminho_verdadeiro[t], sd = 0.18); qt <- qt / sum(qt)
  st <- sapply(strikes_listados, function(s) sum(qt[baldes >= s]))
  pt <- pmin(pmax(round(st * 100 + rnorm(length(st), 0, 1.2)), 1), 99)  # ruido
  dt <- massa_de_sobrevivencia(strikes_listados, middle_out(pt), STRIKE_INT)
  recuperado[t] <- taxa_esperada(dt$strike, dt$prob, AJUSTE)
}
# a media verdadeira implicita pela distribuicao discretizada (nao o caminho
# latente): e isso que o pipeline pode, no maximo, recuperar
alvo <- sapply(caminho_verdadeiro, function(m) {
  qt <- dnorm(baldes + AJUSTE, mean = m, sd = 0.18); qt <- qt / sum(qt)
  sum(qt * (baldes + AJUSTE))
})
eqm <- sqrt(mean((recuperado - alvo)^2)) * 100
cor_ <- cor(recuperado, alvo)
cat(sprintf("%d dias | REQM = %.2f bps | correlacao = %.4f\n", n_dias, eqm, cor_))
if (eqm > 10)   falhou(sprintf("REQM de %.2f bps alto demais", eqm))
if (cor_ < 0.95) falhou(sprintf("correlacao de %.4f baixa demais", cor_)) else
  passou("o caminho diario e recuperado sob ruido de negociacao")
if (length(recuperado) < 120) falhou("menos de 120 obs") else
  passou(sprintf("%d observacoes -- acima do minimo de 120 da lista", length(recuperado)))

# ---------------------------------------------------------------------------
cat("\n=== Grafico de validacao ===\n")
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
png("output/figures/validacao_pipeline.png", width = 1600, height = 1150, res = 170)
par(mfrow = c(2, 1), mar = c(4, 4.2, 3, 1.2), tck = -0.02)

barplot(rbind(q, d$prob), beside = TRUE, names.arg = sprintf("%.2f", baldes),
        col = c("grey30", "steelblue"), border = NA, ylim = c(0, max(q) * 1.25),
        xlab = "balde de taxa (limite inferior, %)", ylab = "probabilidade",
        main = "Distribuicao verdadeira vs. recuperada da sobrevivencia")
legend("topright", c("verdadeira", "recuperada"), fill = c("grey30", "steelblue"),
       border = NA, bty = "n", cex = 0.85)

plot(alvo, type = "l", lwd = 2.5, col = "grey30", ylab = "taxa esperada (%)",
     xlab = "dia (0 = 180 dias antes da reuniao)",
     main = sprintf("Caminho diario sob ruido de negociacao (REQM = %.2f bps)", eqm))
lines(recuperado, col = "steelblue", lwd = 1.4)
legend("topleft", c("verdadeira", "recuperada pelo pipeline"),
       col = c("grey30", "steelblue"), lwd = c(2.5, 1.4), bty = "n", cex = 0.85)
invisible(dev.off())
cat("gravado: output/figures/validacao_pipeline.png\n")

cat("\n============================================\n")
cat(if (ok) "TODOS OS TESTES PASSARAM\n" else "HOUVE FALHAS -- ver acima\n")
cat("============================================\n")
quit(save = "no", status = if (ok) 0 else 1)

# audita_contratos.R ---------------------------------------------------------
# Qual contrato KXFED deve ser a serie do trabalho?
#
# Rode com:  Rscript tests/audita_contratos.R
#
# Base R puro -- roda sem nenhum pacote instalado. Isso importa: o pipeline de
# producao depende de dplyr/tidyr/readr/stringr, e esta auditoria precisa rodar
# mesmo onde eles nao estejam disponiveis.
#
# Auditoria comparativa de contratos, em base R puro, usando R/fun_distribuicao.R.
# Usa o painel de candlesticks (nao o pipeline de trades), entao os NIVEIS podem
# diferir ligeiramente da producao; a COMPARACAO entre contratos e valida porque
# todos passam exatamente pelo mesmo tratamento.
source("R/fun_distribuicao.R")
SI <- 0.25; AJ <- SI/2; DB <- 180

p <- read.csv("data/raw/kalshi_fed_panel.csv", stringsAsFactors = FALSE)
p$date <- as.Date(p$date)
m <- regexpr("(?<=-T)[0-9]+\\.?[0-9]*", p$ticker, perl = TRUE)
p$strike <- NA_real_; hit <- m != -1L
p$strike[hit] <- as.numeric(regmatches(p$ticker, m))
pr <- p$mid; pr[is.na(pr)] <- p$yes_close[is.na(pr)]
p$preco <- pr * 100
p <- p[!is.na(p$strike) & !is.na(p$preco), ]
SNAP <- max(p$date)

serie_de <- function(ev) {
  g <- p[p$event_ticker == ev, ]
  exp_ <- max(g$date)
  g <- g[g$date >= exp_ - DB, ]
  ch <- split(g, g$date)
  out <- do.call(rbind, lapply(ch, function(k) {
    k <- k[order(k$strike), ]
    if (nrow(k) < 2L) return(NULL)
    d <- massa_de_sobrevivencia(k$strike, middle_out(k$preco), SI)
    if (is.null(d)) return(NULL)
    data.frame(date = k$date[1], taxa = taxa_esperada(d$strike, d$prob, AJ),
               vol = sum(k$volume, na.rm = TRUE))
  }))
  out[order(out$date), ]
}

jb <- function(x) { n<-length(x); s<-mean((x-mean(x))^3)/sd(x)^3; k<-mean((x-mean(x))^4)/sd(x)^4
                    n/6*(s^2 + (k-3)^2/4) }

evs <- sort(unique(p$event_ticker))
res <- do.call(rbind, lapply(evs, function(ev) {
  s <- serie_de(ev); if (is.null(s) || nrow(s) < 30) return(NULL)
  d <- diff(s$taxa)
  data.frame(
    contrato   = ev,
    resolvido  = max(s$date) < SNAP,
    obs        = nrow(s),
    volume     = round(sum(p$volume[p$event_ticker == ev], na.rm = TRUE)),
    dp_dif_bps = round(sd(d) * 100, 1),
    salto_max  = round(max(abs(d)) * 100, 0),
    curtose    = round(mean((d-mean(d))^4)/sd(d)^4, 1),
    JB         = round(jb(d), 0),
    ac1        = round(acf(d, lag.max = 1, plot = FALSE)$acf[2], 3),
    stringsAsFactors = FALSE)
}))
res <- res[order(-res$volume), ]
cat("\n=== Contratos KXFED: qual serve para Box-Jenkins? ===\n")
cat("(salto_max e curtose em cima das diferencas diarias; salto em pontos-base)\n\n")
print(res, row.names = FALSE)

cat("\n=== Perfil de variancia: primeiro vs ultimo terco da amostra ===\n")
cat("Sob a hipotese do artigo, a variancia deve CAIR conforme a reuniao se aproxima.\n\n")
vp <- do.call(rbind, lapply(res$contrato, function(ev) {
  s <- serie_de(ev); d <- diff(s$taxa); n <- length(d); t3 <- floor(n/3)
  data.frame(contrato = ev, resolvido = max(s$date) < SNAP,
             dp_inicio = round(sd(d[1:t3])*100, 1),
             dp_fim    = round(sd(d[(n-t3+1):n])*100, 1),
             razao     = round(sd(d[1:t3])/sd(d[(n-t3+1):n]), 2),
             stringsAsFactors = FALSE)
}))
print(vp, row.names = FALSE)

cat("\n\n=== KXFED-26JUL: a variancia cai com a aproximacao da reuniao? ===\n")
s <- serie_de("KXFED-26JUL"); d <- diff(s$taxa); dts <- s$date[-1]
dias_ate <- as.numeric(max(s$date) - dts)          # dias ate a reuniao
fit <- lm(log(d^2 + 1e-12) ~ dias_ate)
co <- summary(fit)$coefficients
cat(sprintf("regressao log(dif^2) ~ dias_ate_reuniao:\n  inclinacao = %+.5f (ep %.5f, t = %.2f, p = %.4f)\n",
            co[2,1], co[2,2], co[2,3], co[2,4]))
cat(if (co[2,4] < 0.05 && co[2,1] > 0)
      "  -> inclinacao POSITIVA e significante: variancia MAIOR longe da reuniao,\n     isto e, ela ENCOLHE conforme a resolucao se aproxima. Figura 8 do artigo.\n"
    else "  -> nao significante nesta especificacao.\n")
n <- length(d); h <- floor(n/2)
ft <- var.test(d[1:h], d[(n-h+1):n])
cat(sprintf("\nteste F de igualdade de variancias (1a vs 2a metade):\n  F = %.3f, p = %.5f\n",
            ft$statistic, ft$p.value))
# ARCH-LM manual (regressao dos quadrados nos proprios lags)
archlm <- function(x, q = 7) {
  e2 <- (x - mean(x))^2; n <- length(e2)
  X <- embed(e2, q + 1); y <- X[,1]; Z <- X[,-1, drop = FALSE]
  r2 <- summary(lm(y ~ Z))$r.squared; LM <- (n - q) * r2
  c(LM = LM, p = 1 - pchisq(LM, q))
}
a <- archlm(d)
cat(sprintf("\nARCH-LM (7 lags) na mesma serie: LM = %.3f, p = %.4f\n", a["LM"], a["p"]))
cat("Nota: ARCH-LM procura AGRUPAMENTO de volatilidade (dependencia condicional).\n")
cat("Uma queda SUAVE e deterministica da variancia ao longo do horizonte pode passar\n")
cat("despercebida por ele. Por isso a regressao acima e o teste F sao os instrumentos\n")
cat("adequados para a afirmacao do artigo -- e devem acompanhar o ARCH-LM na Q5(c).\n")

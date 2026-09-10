# replica_apendice_a.R -------------------------------------------------------
# Replica o Apendice A de Diercks, Katz & Wright (2026, FEDS 2026-010):
# "Midpoint of Bid-Ask Spreads". Eles comparam o erro absoluto medio da taxa
# esperada construida a partir do ULTIMO NEGOCIO contra a construida a partir do
# PONTO MEDIO bid/ask, medido contra o desfecho REALIZADO, por horizonte.
# Conclusao deles: "the forecast errors spike quite a bit more [com o mid],
# indicating some reliability issues, most likely due to issues surrounding the
# tails of the distribution. Because of these issues, we maintain focus on the
# last trade for our main results."
#
# Rode com:  Rscript tests/replica_apendice_a.R
# Base R puro -- roda sem nenhum pacote instalado.
#
# O criterio deles (erro contra o desfecho realizado) e melhor que o criterio de
# suavidade que eu havia usado antes: uma serie mais suave pode ser mais viesada.
# Isto so e possivel num contrato JA RESOLVIDO -- por isso o KXFED-26JUL.
source("R/fun_distribuicao.R")
SI <- 0.25; AJ <- SI/2
EVENTO <- Sys.getenv("KALSHI_EVENTO", "KXFED-26JUL")

p <- read.csv("data/raw/kalshi_fed_panel.csv", stringsAsFactors = FALSE)
p$date <- as.Date(p$date)
m <- regexpr("(?<=-T)[0-9]+\\.?[0-9]*", p$ticker, perl = TRUE)
p$strike <- NA_real_; hit <- m != -1L
p$strike[hit] <- as.numeric(regmatches(p$ticker, m))
g <- p[p$event_ticker == EVENTO & !is.na(p$strike), ]
if (!nrow(g)) stop("Evento nao encontrado: ", EVENTO)

# Livro vazio (bid = 0 e ask = 1) torna o mid degenerado em 0,5. Descartar.
g$livro_vazio <- (g$bid == 0 & g$ask == 1)
g <- g[order(g$ticker, g$date), ]

# "carry over the last-traded strike from a previous day" (paper, secao 3)
ffill <- function(x) { for (i in seq_along(x)) if (is.na(x[i]) && i > 1) x[i] <- x[i-1]; x }
g$close_ff <- ave(g$yes_close, g$ticker, FUN = ffill)
g$mid_ff   <- ave(ifelse(g$livro_vazio, NA, g$mid), g$ticker, FUN = ffill)

serie <- function(col) {
  gg <- g[!is.na(g[[col]]), ]; gg$preco <- gg[[col]] * 100
  o <- do.call(rbind, lapply(split(gg, gg$date), function(k) {
    k <- k[order(k$strike), ]; if (nrow(k) < 3L) return(NULL)
    d <- massa_de_sobrevivencia(k$strike, middle_out(k$preco), SI)
    if (is.null(d)) return(NULL)
    data.frame(date = k$date[1], taxa = taxa_esperada(d$strike, d$prob, AJ))
  }))
  o[order(o$date), ]
}

a <- serie("close_ff"); b <- serie("mid_ff"); fim <- max(a$date)
kf <- g[g$date == fim & !is.na(g$close_ff), ]; kf <- kf[order(kf$strike), ]
df <- massa_de_sobrevivencia(kf$strike, middle_out(kf$close_ff * 100), SI)
realizado <- df$strike[which.max(df$prob)] + AJ

cat(sprintf("Contrato %s | encerrado em %s | desfecho realizado: %.3f%% ",
            EVENTO, format(fim), realizado))
cat(sprintf("(massa %.3f no balde vencedor)\n", max(df$prob)))

cm <- merge(a, b, by = "date"); names(cm) <- c("date", "ultimo", "mid")
cm$dias <- as.numeric(fim - cm$date)
cm$e_u <- abs(cm$ultimo - realizado); cm$e_m <- abs(cm$mid - realizado)
cat(sprintf("Amostra balanceada: %d datas comuns\n\n", nrow(cm)))

cat("=== EAM contra o desfecho realizado, por horizonte (pontos percentuais) ===\n")
fx <- list(">160d"=c(161,1e6), "120-160d"=c(120,161), "90-120d"=c(90,120),
           "60-90d"=c(60,90), "30-60d"=c(30,60), "7-30d"=c(7,30), "0-7d"=c(0,7))
tb <- do.call(rbind, lapply(names(fx), function(nm) {
  r <- fx[[nm]]; s <- cm[cm$dias >= r[1] & cm$dias < r[2], ]
  if (!nrow(s)) return(NULL)
  data.frame(janela = nm, n = nrow(s),
             EAM_ultimo = round(mean(s$e_u), 4), EAM_mid = round(mean(s$e_m), 4),
             melhor = ifelse(mean(s$e_u) < mean(s$e_m), "ultimo", "mid"))
}))
print(tb, row.names = FALSE)

tt <- t.test(cm$e_u, cm$e_m, paired = TRUE)
cat(sprintf("\nGLOBAL: ultimo negocio = %.4f pp | mid = %.4f pp -> %s\n",
            mean(cm$e_u), mean(cm$e_m),
            ifelse(mean(cm$e_u) < mean(cm$e_m), "ULTIMO NEGOCIO", "MID")))
cat(sprintf("teste t pareado: t = %.3f, p = %.5f\n", tt$statistic, tt$p.value))
cat("\nLeitura: a vantagem do ultimo negocio se concentra nos horizontes LONGOS,\n")
cat("onde o livro e raso e o spread largo puxa o mid para o centro da escada de\n")
cat("strikes -- exatamente o mecanismo que o paper aponta. Dentro da janela de\n")
cat("180 dias que a analise usa, as duas ficam proximas.\n")

# 08_previsao.R  --  QUESTAO 7: avaliacao preditiva contra benchmarks.
#
# Q7(a) H = 24 ultimas observacoes como validacao. T0 = T - H.
# Q7(b) ESQUEMA 1 (origem fixa, multiplos passos) com IC de 95% e grafico.
# Q7(c) ESQUEMA 2 (origem movel, um passo) MANTENDO FIXOS os coeficientes.
# Q7(d) RMSE, MAE e MAPE nos dois esquemas.
# Q7(e) Benchmarks sob os MESMOS esquemas: passeio aleatorio e sazonal ingenuo.
# Q7(f) Superou? -> DIEBOLD-MARIANO. Sem ele, "nao superou" e observacao; com
#       ele, e inferencia. Diebold & Mariano (1995), JBES 13, 253-263, que esta
#       na propria bibliografia do FEDS 2026-010. Com a correcao de amostra
#       pequena de Harvey, Leybourne & Newbold (1997) -- indispensavel com H=24.
# Q7(g) Cobertura empirica do IC + TRANSFORMADA INTEGRAL DE PROBABILIDADE (PIT),
#       Diebold, Gunther & Tay (1998), IER 39, 863-883, aplicada pelos proprios
#       autores do FEDS na secao 6.1. A cobertura e uma versao fraca do PIT.

source("R/99_helpers.R")
library(ggplot2)
source("R/99_viz.R")

serie <- read_series()
y  <- as.numeric(serie$taxa_esperada)
H  <- 24L
s  <- 7L
T0 <- length(y) - H

fit_full  <- readRDS(file.path(OUT_TAB, "q4_modelo_selecionado.rds"))
ordem     <- forecast::arimaorder(fit_full)[1:3]
fit_train <- fit_candidate(y[seq_len(T0)], ordem)
fc        <- forecast::forecast(fit_train, h = H, level = 95)
rotulo    <- sprintf("ARIMA(%d,%d,%d)", ordem[1], ordem[2], ordem[3])
message("Modelo da Q4 em uso: ", rotulo, " | T = ", length(y), " | T0 = ", T0)

actual         <- y[(T0 + 1):length(y)]
fixed          <- as.numeric(fc$mean)
rw_fixed       <- rep(y[T0], H)
seasonal_fixed <- rep(y[(T0 - s + 1):T0], length.out = H)

## ---- Esquema 2: origem movel, coeficientes FIXOS -----------------------------
one_step <- numeric(H)
for (j in seq_len(H)) {
  t <- T0 + j - 1L
  estado <- forecast::Arima(y[seq_len(t)], model = fit_train)   # nao reestima
  one_step[j] <- as.numeric(forecast::forecast(estado, h = 1)$mean[1])
}
rw_one       <- y[T0:(length(y) - 1L)]
seasonal_one <- y[(T0 - s + 1):(length(y) - s)]

metrics <- rbind(
  metric_row(actual, fixed,          "ARIMA",             "origem_fixa_24_passos"),
  metric_row(actual, rw_fixed,       "passeio_aleatorio", "origem_fixa_24_passos"),
  metric_row(actual, seasonal_fixed, "sazonal_ingenuo",   "origem_fixa_24_passos"),
  metric_row(actual, one_step,       "ARIMA",             "origem_movel_1_passo"),
  metric_row(actual, rw_one,         "passeio_aleatorio", "origem_movel_1_passo"),
  metric_row(actual, seasonal_one,   "sazonal_ingenuo",   "origem_movel_1_passo")
)
write_table(metrics, "q7_metricas_previsao.csv")

## ---- Q7(f): DIEBOLD-MARIANO --------------------------------------------------
# d_t = L(e_1t) - L(e_2t). H0: E[d_t] = 0 (acuracia preditiva igual).
# Variancia de longo prazo por Newey-West com h-1 defasagens (autocorrelacao
# inerente a previsoes de h passos). Correcao HLN para amostra pequena e
# referencia t com n-1 g.l. em vez de normal.
dm_test <- function(e1, e2, h = 1L, potencia = 2) {
  d <- abs(e1)^potencia - abs(e2)^potencia
  n <- length(d); dbar <- mean(d)
  gama <- function(k) sum((d[(k + 1):n] - dbar) * (d[1:(n - k)] - dbar)) / n
  lrv <- gama(0)
  if (h > 1L) for (k in 1:(h - 1L)) lrv <- lrv + 2 * gama(k)
  if (lrv <= 0) return(c(DM = NA, p = NA, dbar = dbar))
  dm <- dbar / sqrt(lrv / n)
  # Harvey, Leybourne & Newbold (1997)
  correcao <- sqrt((n + 1 - 2 * h + h * (h - 1) / n) / n)
  dm_hln <- dm * correcao
  c(DM = dm_hln, p = 2 * stats::pt(-abs(dm_hln), df = n - 1L), dbar = dbar)
}

erros <- list(
  fixa_arima = actual - fixed,       fixa_rw   = actual - rw_fixed,
  fixa_saz   = actual - seasonal_fixed,
  movel_arima = actual - one_step,   movel_rw  = actual - rw_one,
  movel_saz   = actual - seasonal_one
)
# APLICABILIDADE. O DM compara sequencias de erros de previsao geradas por
# ORIGENS REPETIDAS. O Esquema 1 tem uma UNICA origem: seus 24 erros sao um so
# caminho, nao 24 previsoes independentes. Alem disso, com h = n a correcao de
# Harvey-Leybourne-Newbold, sqrt((n + 1 - 2h + h(h-1)/n)/n), zera exatamente
# (n = h = 24 => (25 - 48 + 23)/24 = 0), e a variancia de longo prazo de
# Newey-West com 23 defasagens sobre 24 observacoes deixa de ser positiva.
# Portanto o teste so e reportado para o ESQUEMA 2 (um passo, origem movel).
comparacoes <- list(
  list(esq = "origem_movel_1_passo", vs = "passeio_aleatorio", a = "movel_arima", b = "movel_rw",  h = 1L),
  list(esq = "origem_movel_1_passo", vs = "sazonal_ingenuo",   a = "movel_arima", b = "movel_saz", h = 1L)
)
veredito <- function(dm, p) {
  if (is.na(p) || p >= 0.05) "nao rejeita acuracia igual"
  else if (dm < 0) "ARIMA superior" else "benchmark superior"
}
dm_tab <- do.call(rbind, lapply(comparacoes, function(cc) {
  q <- dm_test(erros[[cc$a]], erros[[cc$b]], h = cc$h, potencia = 2)
  a <- dm_test(erros[[cc$a]], erros[[cc$b]], h = cc$h, potencia = 1)
  data.frame(
    esquema = cc$esq, comparacao = paste0(rotulo, " vs ", cc$vs), h = cc$h,
    DM_quadratico = unname(q["DM"]), p_quadratico = unname(q["p"]),
    veredito_quadratico = veredito(unname(q["DM"]), unname(q["p"])),
    DM_absoluto = unname(a["DM"]), p_absoluto = unname(a["p"]),
    veredito_absoluto = veredito(unname(a["DM"]), unname(a["p"])),
    stringsAsFactors = FALSE)
}))
dm_tab <- rbind(dm_tab, data.frame(
  esquema = "origem_fixa_24_passos", comparacao = "nao aplicavel", h = H,
  DM_quadratico = NA_real_, p_quadratico = NA_real_,
  veredito_quadratico = "origem unica: DM nao se aplica (correcao HLN zera com h = n)",
  DM_absoluto = NA_real_, p_absoluto = NA_real_,
  veredito_absoluto = "idem", stringsAsFactors = FALSE))
write_table(dm_tab, "q7_diebold_mariano.csv")

## ---- Q7(g): cobertura + PIT --------------------------------------------------
lo <- as.numeric(fc$lower[, 1]); hi <- as.numeric(fc$upper[, 1])
cobertura <- mean(actual >= lo & actual <= hi)

# Esquema 1: desvio-padrao preditivo cresce com o horizonte; extrai do IC.
sd_fixa <- (hi - fixed) / stats::qnorm(0.975)
pit_fixa <- stats::pnorm((actual - fixed) / sd_fixa)
# Esquema 2: um passo, variancia = sigma^2_a do modelo. E o caso para o qual o
# arcabouco de Diebold, Gunther & Tay foi desenhado (PITs i.i.d. sob H0).
sd_movel <- sqrt(fit_train$sigma2)
pit_movel <- stats::pnorm((actual - one_step) / sd_movel)

ks_f <- suppressWarnings(stats::ks.test(pit_fixa,  "punif"))
ks_m <- suppressWarnings(stats::ks.test(pit_movel, "punif"))
write_table(data.frame(
  horizonte = H, cobertura_intervalo_95 = cobertura, cobertura_nominal = 0.95,
  ks_esquema1 = unname(ks_f$statistic), p_ks_esquema1 = ks_f$p.value,
  ks_esquema2 = unname(ks_m$statistic), p_ks_esquema2 = ks_m$p.value
), "q7_cobertura.csv")
write_table(data.frame(h = seq_len(H), pit_esquema1 = pit_fixa, pit_esquema2 = pit_movel),
            "q7_pit.csv")

## ---- Figuras -----------------------------------------------------------------
datas <- serie$date[(T0 + 1):length(y)]
ctx   <- 40L
hist_df <- data.frame(date = serie$date[(T0 - ctx + 1):T0], y = y[(T0 - ctx + 1):T0])
prev_df <- data.frame(date = datas, obs = actual, arima = fixed, rw = rw_fixed,
                      saz = seasonal_fixed, lo = lo, hi = hi)

# Quebra a nota de fonte para nao ser cortada na margem.
quebrar <- function(txt, largura = 105) paste(strwrap(txt, width = largura), collapse = "\n")

# Formato longo: a cor entra por aes, de modo que a LEGENDA existe de fato.
# Identidade nao fica so na cor -- cada serie tem tambem seu tipo de linha.
longo <- rbind(
  data.frame(date = datas, valor = fixed,          serie = "ARIMA"),
  data.frame(date = datas, valor = rw_fixed,       serie = "Passeio aleatorio"),
  data.frame(date = datas, valor = seasonal_fixed, serie = "Sazonal ingenuo"))
longo$serie <- factor(longo$serie, levels = c("ARIMA", "Passeio aleatorio", "Sazonal ingenuo"))
obs_df <- rbind(hist_df, data.frame(date = datas, y = actual))

p1 <- ggplot() +
  geom_ribbon(data = prev_df, aes(date, ymin = lo, ymax = hi),
              fill = COR$banda, alpha = 0.13) +
  geom_line(data = obs_df, aes(date, y), colour = COR$tinta, linewidth = 0.75) +
  geom_line(data = longo, aes(date, valor, colour = serie, linetype = serie), linewidth = 0.7) +
  geom_vline(xintercept = as.numeric(serie$date[T0]), colour = COR$tinta_fraca,
             linewidth = 0.3, linetype = "13") +
  annotate("text", x = serie$date[T0], y = max(hi, na.rm = TRUE),
           label = "  inicio da validacao", hjust = 0, vjust = 1.4,
           size = 2.9, colour = COR$tinta_fraca) +
  annotate("text", x = min(hist_df$date), y = max(hi, na.rm = TRUE),
           label = "Observado", hjust = 0, vjust = 1.4, size = 3,
           colour = COR$tinta, fontface = "bold") +
  scale_colour_manual(values = c("ARIMA" = COR$serie_1,
                                 "Passeio aleatorio" = COR$serie_2,
                                 "Sazonal ingenuo" = COR$serie_3)) +
  scale_linetype_manual(values = c("ARIMA" = "solid",
                                   "Passeio aleatorio" = "42",
                                   "Sazonal ingenuo" = "22")) +
  scale_y_continuous(labels = escala_br(2)) +
  labs(title = sprintf("Figura 1 -- Previsao fora da amostra: %s contra benchmarks ingenuos", rotulo),
       subtitle = sprintf("Esquema 1 (origem fixa, %d passos). Faixa azul: intervalo de previsao de 95%%.", H),
       x = NULL, y = "Taxa esperada implicita (% a.a.)",
       caption = quebrar(nota_fonte(sprintf(
         "Cobertura empirica do intervalo: %s%% contra 95%% nominais -- as densidades preditivas sao largas demais.",
         fmt_br(100 * cobertura, 1))))) +
  theme_feds() +
  theme(legend.key.width = unit(1.4, "cm"))
salvar_fig(p1, "q7_previsao.png", 7.8, 4.6)

pit_df <- data.frame(pit = pit_movel)
nbin <- 6L; esperado <- H / nbin
band <- stats::qbinom(c(0.025, 0.975), H, 1 / nbin)
p2 <- ggplot(pit_df, aes(pit)) +
  annotate("rect", xmin = 0, xmax = 1, ymin = band[1], ymax = band[2],
           fill = COR$grade, alpha = 0.9) +
  geom_hline(yintercept = esperado, colour = COR$tinta_fraca, linetype = "42", linewidth = 0.35) +
  geom_histogram(breaks = seq(0, 1, length.out = nbin + 1), fill = COR$serie_1,
                 colour = "white", linewidth = 0.6) +
  scale_x_continuous(labels = escala_br(1), breaks = seq(0, 1, 0.25)) +
  labs(title = "Figura 2 -- Transformada integral de probabilidade (PIT)",
       subtitle = paste0("Esquema 2 (um passo a frente). Sob densidades preditivas corretas, ",
                         "as PIT sao U(0,1).\nFaixa cinza: banda de 95% para a contagem por bin; ",
                         "tracejado: contagem esperada."),
       x = "PIT", y = "Frequencia",
       caption = quebrar(nota_fonte(sprintf(
         "Kolmogorov-Smirnov contra a uniforme: D = %s, p = %s. Arcabouco de Diebold, Gunther e Tay (1998).",
         fmt_br(ks_m$statistic, 3), fmt_br(ks_m$p.value, 4))))) +
  theme_feds()
salvar_fig(p2, "q7_pit.png", 6.4, 4.2)

# Perda acumulada: mostra ONDE a vantagem aparece, nao so o resultado agregado
dif_df <- data.frame(
  h = rep(seq_len(H), 2),
  cum = c(cumsum(erros$movel_arima^2 - erros$movel_rw^2),
          cumsum(erros$fixa_arima^2  - erros$fixa_rw^2)),
  esquema = rep(c("Origem movel, 1 passo", "Origem fixa, 24 passos"), each = H))
p3 <- ggplot(dif_df, aes(h, cum, colour = esquema)) +
  geom_hline(yintercept = 0, colour = COR$tinta_fraca, linewidth = 0.35) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c("Origem movel, 1 passo" = COR$serie_1,
                                 "Origem fixa, 24 passos" = COR$serie_2)) +
  scale_y_continuous(labels = escala_br(4)) +
  labs(title = "Figura 3 -- Diferencial de perda acumulado contra o passeio aleatorio",
       subtitle = paste0("Erro quadratico do ", rotulo, " menos o do passeio aleatorio. ",
                         "Abaixo de zero: o modelo acumula\nvantagem; acima: o benchmark vence."),
       x = "Passo do horizonte de validacao", y = "Diferencial acumulado",
       caption = quebrar(nota_fonte("Estatistica de Diebold-Mariano em output/tables/q7_diebold_mariano.csv."))) +
  theme_feds()
salvar_fig(p3, "q7_perda_acumulada.png", 7.0, 4.0)

cat("\n=== Q7(f) Diebold-Mariano ===\n"); print(dm_tab, row.names = FALSE)
cat(sprintf("\n=== Q7(g) cobertura = %s%% (nominal 95%%) ===\n", fmt_br(100 * cobertura, 1)))
cat(sprintf("KS PIT esquema 1: D = %s, p = %s\n", fmt_br(ks_f$statistic, 3), fmt_br(ks_f$p.value, 4)))
cat(sprintf("KS PIT esquema 2: D = %s, p = %s\n", fmt_br(ks_m$statistic, 3), fmt_br(ks_m$p.value, 4)))

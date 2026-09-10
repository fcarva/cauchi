# 04_identificacao.R  --  Questao 3: FAC/FACP -> candidatos justificados.

source("R/99_helpers.R")
serie <- read_series()
dif1 <- diff(serie$taxa_esperada)
n <- length(dif1)
s <- PERIODO_SAZONAL
banda <- stats::qnorm(0.975) / sqrt(n)

# Q3(a): pelo menos dois ciclos sazonais. Com s = 7, 42 defasagens cobrem seis.
LAG_MAX <- 42L
fac  <- stats::acf(dif1,  lag.max = LAG_MAX, plot = FALSE)
facp <- stats::pacf(dif1, lag.max = LAG_MAX, plot = FALSE)
fac_v  <- as.numeric(fac$acf)[-1]      # descarta o lag 0
facp_v <- as.numeric(facp$acf)

png(file.path(OUT_FIG, "q3_fac_ficp.png"), width = 1400, height = 700, res = 140)
par(mfrow = c(1, 2))
acf(dif1, lag.max = LAG_MAX, main = "FAC da primeira diferenca")
abline(v = s * (1:6), col = "#c0392b", lty = 3)
pacf(dif1, lag.max = LAG_MAX, main = "FACP da primeira diferenca")
abline(v = s * (1:6), col = "#c0392b", lty = 3)
dev.off()

## ---- Q3(b): inspecao explicita dos lags sazonais -----------------------------
# A lista exige que a sazonalidade seja examinada, nao dispensada. Com s = 7
# (mercado ativo nos sete dias -- q1_atividade_semanal.csv), os lags de interesse
# sao 7, 14 e 21 e suas vizinhancas imediatas, que sinalizariam um periodo
# proximo mas mal especificado.
lags_foco <- sort(unique(c(s * (1:3), s * (1:3) - 1L, s * (1:3) + 1L)))
lags_saz <- data.frame(
  lag = lags_foco,
  sazonal = lags_foco %% s == 0,
  FAC  = fac_v[lags_foco],
  FACP = facp_v[lags_foco],
  banda_95 = banda,
  FAC_significativa  = abs(fac_v[lags_foco])  > banda,
  FACP_significativa = abs(facp_v[lags_foco]) > banda,
  stringsAsFactors = FALSE
)
write_table(lags_saz, "q3_lags_sazonais.csv")

sem_sazonalidade <- !any(lags_saz$FAC_significativa[lags_saz$sazonal] |
                         lags_saz$FACP_significativa[lags_saz$sazonal])

## ---- Q3(c): candidatos derivados da leitura acima ----------------------------
# Regra de leitura de Box-Jenkins aplicada ao que os graficos mostram:
#   - FAC: corte abrupto no lag 1 (negativo e forte); alem dele so residuos
#     marginais. Corte na FAC com decaimento na FACP identifica MA(q).
#   - FACP: decaimento gradual, com varios lags iniciais significativos. Decaimento
#     na FACP com corte na FAC confirma a leitura MA; o lag 1 isolado sustenta
#     tambem uma leitura AR(1) concorrente.
#   - Lags sazonais: nada. Por isso nenhum candidato leva componente sazonal --
#     e isso e RESULTADO documentado (q3_lags_sazonais.csv), nao omissao.
#
# O sinal dominante e o lag 1 negativo. Ele e o que a literatura de microestrutura
# atribui a oscilacao entre compra e venda (bid-ask bounce), nao a previsibilidade
# economica -- ver docs/literatura.md. Os tres primeiros candidatos sao as tres
# leituras parcimoniosas concorrentes desse mesmo sinal.
fac_sig  <- which(abs(fac_v[1:10])  > banda)
facp_sig <- which(abs(facp_v[1:10]) > banda)

candidatos <- data.frame(
  model = c("ARIMA(0,1,1)", "ARIMA(1,1,0)", "ARIMA(1,1,1)", "ARIMA(3,1,3)"),
  p = c(0L, 1L, 1L, 3L), d = 1L, q = c(1L, 0L, 1L, 3L),
  P = 0L, D = 0L, Q = 0L, periodo_sazonal = s,
  justificativa = c(
    "Leitura canonica: a FAC corta apos o lag 1 e a FACP decai. E a especificacao que o par de graficos indica primeiro.",
    "Leitura AR concorrente: o lag 1 da FACP e o maior em modulo; testa se a persistencia se explica por um unico termo autorregressivo.",
    "Mistura parcimoniosa: acomoda simultaneamente persistencia e choque quando FAC e FACP nao separam com nitidez.",
    "Especificacao estendida, incluida para SER TESTADA contra a restricao de admissibilidade da Q4(f): os lags 2, 3, 5, 6 e 8 da FACP sugerem estrutura mais rica, e o AIC tende a premia-la."
  ),
  evidencia = c(
    sprintf("FAC significativa nos lags %s; FACP decai ao longo de %s.",
            paste(fac_sig, collapse = ", "), paste(facp_sig, collapse = ", ")),
    sprintf("FACP no lag 1 = %.4f, fora da banda de 95%% (+/-%.4f).", facp_v[1], banda),
    sprintf("FAC no lag 1 = %.4f e FACP no lag 1 = %.4f, ambas fora da banda.",
            fac_v[1], facp_v[1]),
    sprintf("FACP fora da banda tambem nos lags %s.",
            paste(setdiff(facp_sig, 1L), collapse = ", "))
  ),
  stringsAsFactors = FALSE
)
write_table(candidatos, "q3_candidatos.csv")

cat("\n=== Q3(b) lags sazonais (s = ", s, ") ===\n", sep = "")
print(lags_saz, row.names = FALSE)
cat(sprintf("\nSazonalidade em s = %d: %s\n", s,
            if (sem_sazonalidade)
              "nenhum lag sazonal fora da banda -- nenhum candidato sazonal (P = D = Q = 0)."
            else
              "ha lag sazonal fora da banda -- reveja a necessidade de componente sazonal."))
cat("\n=== Q3(c) candidatos ===\n")
print(candidatos[, c("model", "justificativa")], row.names = FALSE)

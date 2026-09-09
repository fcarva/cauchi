# 01_build_series.R  ---------------------------------------------------------
# Painel bruto (data/raw/kalshi_fed_panel.csv) -> serie diaria unica p/ ARIMA.
#
# Entrada: data/raw/kalshi_fed_panel.csv    (snapshot CONGELADO, gerado pelo 00)
# Saida:   data/processed/serie_diaria.csv
#
# BASE R PURO -- nenhum pacote. Toda a matematica vive em R/fun_distribuicao.R,
# que e testado isoladamente por tests/test_distribuicao.R contra uma
# distribuicao de resposta conhecida. Este arquivo so faz a manipulacao de
# dados em volta daquelas funcoes.
#
# METODOLOGIA: Diercks, Katz & Wright (2026), replication package
# jdkatz21/Prediction_Markets_Public,
#   code/convert_trades_to_pdfs/convert_trade_level_data_cdfs.R
# parametros do bloco "FFR levels" de data_convert_runner.R:
#   strike_int = 0.25, days_before_horizon = 180, moment_adjustment = .125
#
# O PONTO NAO-OBVIO: o yes_price de 'FED-22DEC-T4.25' e P(taxa ACIMA de 4.25),
# nao a probabilidade do balde (4.25, 4.50]. Os strikes de um contrato formam
# uma funcao de SOBREVIVENCIA. Ver o cabecalho de R/fun_distribuicao.R.
# -----------------------------------------------------------------------------

source("R/fun_distribuicao.R")

## ---- parametros ----
ARQ_IN            <- Sys.getenv("KALSHI_PANEL", "data/raw/kalshi_fed_panel.csv")
ARQ_OUT           <- Sys.getenv("KALSHI_SERIE", "data/processed/serie_diaria.csv")
STRIKE_INT        <- 0.25              # espacamento dos strikes da FFR
MOMENT_ADJUSTMENT <- STRIKE_INT / 2    # 0.125 -- ponto medio do balde
DAYS_BEFORE       <- 180               # janela por reuniao
COL_PRECO         <- "mid"             # "mid" (mitiga bid-ask bounce) ou "yes_close"
MIN_OBS           <- 120               # exigencia da lista

# Como colapsar o painel (uma reuniao por vez) em UMA serie:
#   "contrato_unico" - caminho completo de UMA reuniao. Sem roll, sem quebra
#                      artificial de nivel. Com DAYS_BEFORE=180 ja passa das
#                      120 obs. Default, e a opcao mais limpa para Box-Jenkins.
#   "front"          - a cada dia, a reuniao vigente mais proxima. Realista, mas
#                      o ROLL troca o alvo e cria salto de nivel artificial, que
#                      entra nos testes de raiz unitaria da Questao 2 como falsa
#                      quebra estrutural.
#   "horizonte_fixo" - a cada dia, a reuniao ~HORIZONTE_DIAS a frente.
MODO           <- Sys.getenv("KALSHI_MODO", "contrato_unico")
HORIZONTE_DIAS <- 60

## ---- leitura ----
if (!file.exists(ARQ_IN))
  stop("Snapshot nao encontrado em '", ARQ_IN, "'. Rode R/00_pull_kalshi.R uma vez.",
       call. = FALSE)

painel <- utils::read.csv(ARQ_IN, stringsAsFactors = FALSE)
painel$date <- as.Date(painel$date)

## ---- strike vem do TICKER, nao do rotulo de texto ----
# Rotulo e texto de marketing e muda; ticker e chave.
painel$strike <- NA_real_
m   <- regexpr("(?<=-T)[0-9]+\\.?[0-9]*", painel$ticker, perl = TRUE)
hit <- m != -1L
painel$strike[hit] <- as.numeric(regmatches(painel$ticker, m))

if (!any(hit)) {
  stop("Nenhum strike '-T<numero>' encontrado nos tickers.\n",
       "  O snapshot veio da familia de DECISAO (desfechos categoricos, ex.\n",
       "  KXFEDDECISION-28JAN-H26), nao da familia de NIVEL. Este pipeline\n",
       "  exige strikes numericos: use a familia de nivel (KXFED / FED,\n",
       "  tickers '...-T4.25') no 00, ou construa um mapa categoria->bps.",
       call. = FALSE)
}

## ---- preco em CENTS (1-99), como no paper ----
preco <- painel[[COL_PRECO]]
preco[is.na(preco)] <- painel$yes_close[is.na(preco)]
painel$preco <- preco * 100

painel <- painel[!is.na(painel$strike) & !is.na(painel$preco), ]
if (!nrow(painel)) stop("Painel vazio apos limpeza.", call. = FALSE)

## ---- expiry por reuniao + janela de DAYS_BEFORE ----
expiry <- tapply(painel$date, painel$event_ticker, max)
painel$expiry <- as.Date(expiry[painel$event_ticker], origin = "1970-01-01")
painel <- painel[painel$date >= painel$expiry - DAYS_BEFORE, ]

## ---- por (reuniao, dia): sobrevivencia -> distribuicao -> momento ----
chave  <- paste(painel$event_ticker, painel$date, sep = "|")
grupos <- split(painel, chave)

linhas <- lapply(grupos, function(g) {
  g <- g[order(g$strike), ]
  # um strike so nao define uma distribuicao
  if (nrow(g) < 2L) return(NULL)
  d <- massa_de_sobrevivencia(g$strike, middle_out(g$preco), STRIKE_INT)
  if (is.null(d)) return(NULL)
  data.frame(
    event_ticker  = g$event_ticker[1],
    date          = g$date[1],
    expiry        = g$expiry[1],
    taxa_esperada = taxa_esperada(d$strike, d$prob, MOMENT_ADJUSTMENT),
    variancia     = variancia_implicita(d$strike, d$prob),
    n_strikes     = nrow(g),
    volume        = sum(g$volume, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
})

momentos <- do.call(rbind, linhas)
if (is.null(momentos) || !nrow(momentos))
  stop("Nenhum dia com strikes suficientes para formar uma distribuicao.", call. = FALSE)
momentos <- momentos[order(momentos$event_ticker, momentos$date), ]
rownames(momentos) <- NULL

## ---- painel -> serie unica ----
serie <- switch(MODO,
  "contrato_unico" = {
    n_por_reuniao <- table(momentos$event_ticker)
    escolhida <- names(n_por_reuniao)[which.max(n_por_reuniao)]
    message("Reuniao escolhida (mais dias de historico): ", escolhida,
            " (", max(n_por_reuniao), " dias)")
    momentos[momentos$event_ticker == escolhida, ]
  },
  "front" = {
    viv <- momentos[momentos$expiry >= momentos$date, ]
    viv <- viv[order(viv$date, viv$expiry), ]
    viv[!duplicated(viv$date), ]
  },
  "horizonte_fixo" = {
    d <- momentos
    d$gap <- abs(as.numeric(d$expiry - d$date) - HORIZONTE_DIAS)
    d <- d[order(d$date, d$gap), ]
    d[!duplicated(d$date), setdiff(names(d), "gap")]
  },
  stop("MODO invalido: ", MODO, call. = FALSE)
)

serie <- serie[order(serie$date), ]
serie <- serie[!duplicated(serie$date), ]
rownames(serie) <- NULL

## ---- checagens que falham alto ----
if (any(!is.finite(serie$taxa_esperada)))
  stop("taxa_esperada nao-finita: distribuicao degenerada em algum dia.", call. = FALSE)

faixa <- range(painel$strike, na.rm = TRUE)
if (min(serie$taxa_esperada) < faixa[1] - 1 || max(serie$taxa_esperada) > faixa[2] + 1)
  stop("taxa_esperada fora da faixa dos strikes [", faixa[1], ", ", faixa[2],
       "] -- sinal de que a diferenciacao da sobrevivencia saiu errada.", call. = FALSE)

if (nrow(serie) < MIN_OBS)
  warning("Serie com ", nrow(serie), " obs -- abaixo das ", MIN_OBS,
          " exigidas. Aumente DAYS_BACK/N_EVENTS_MAX no 00, ou use MODO='front'.")

# Dias sem pregao: o ARIMA precisa de espacamento regular. Aqui so REPORTO;
# a decisao (preencher vs. dias uteis) e da Questao 1 e vai documentada.
faltando <- as.integer(diff(range(serie$date))) + 1L - nrow(serie)
if (faltando > 0)
  message("Atencao: ", faltando, " dias de calendario sem observacao no intervalo. ",
          "Decida na Questao 1 como tratar (preencher vs. dias uteis).")

dir.create(dirname(ARQ_OUT), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(serie, ARQ_OUT, row.names = FALSE)

cat(sprintf("Serie: %d obs | %s a %s | taxa esperada de %.3f%% a %.3f%%\n",
            nrow(serie), as.character(min(serie$date)), as.character(max(serie$date)),
            min(serie$taxa_esperada), max(serie$taxa_esperada)))

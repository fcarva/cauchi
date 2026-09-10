# 01_build_series.R  ---------------------------------------------------------
# Painel bruto (data/raw/kalshi_fed_panel.csv) -> serie diaria unica p/ ARIMA.
#
# Entrada: data/raw/kalshi_fed_panel.csv    (snapshot CONGELADO, gerado pelo 00)
# Saida:   data/processed/serie_diaria.csv
#
# METODOLOGIA: transcrita de Diercks, Katz & Wright (2026), replication package
# jdkatz21/Prediction_Markets_Public, arquivo
#   code/convert_trades_to_pdfs/convert_trade_level_data_cdfs.R
# com os parametros que eles usam para o FFR em
#   code/convert_trades_to_pdfs/data_convert_runner.R  (bloco "FFR levels"):
#   strike_int = 0.25, moment_adjustment = .125; a janela foi ampliada para
#   aproveitar todo o historico disponivel no snapshot.
#
# O PONTO NAO-OBVIO -----------------------------------------------------------
# Os contratos de nivel da FFR na Kalshi sao 'FED-22DEC-T4.25' e o yes_price
# NAO e a probabilidade do balde [4.25, 4.50). E a probabilidade da CAUDA:
#     yes_price(T4.25) = P(taxa acima de 4.25)
# Ou seja, a familia de strikes de um mesmo contrato e uma FUNCAO DE
# SOBREVIVENCIA (1 - CDF), decrescente em strike -- nao um conjunto de baldes
# disjuntos. Tratar cada 'outcome' como um balde independente e somar p*taxa da
# uma serie ERRADA, e errada de um jeito silencioso (nao gera erro, gera numero).
# Por isso o pipeline abaixo:
#   1. le o strike do TICKER (nao do rotulo de texto);
#   2. impoe monotonicidade em strike (nao-arbitragem) -- 'middle-out' do paper;
#   3. DIFERENCIA strikes adjacentes para obter a massa de cada balde;
#   4. normaliza para somar 1;
#   5. taxa esperada = sum(p_i * strike_i) + strike_int/2.
# O termo strike_int/2 (= 0.125) nao e detalhe: o contrato em s_i denota o
# limite superior da faixa-alvo [s_i, s_i+0.25]. O balde fica indexado por s_i,
# entao o ajuste usa o ponto medio da faixa; sem ele a serie vem 12,5 bps baixa.
#
# AVISO: escrito a partir da metodologia publicada, mas NAO executado contra o
# snapshot (esta sessao nao tem R nem acesso a rede). As checagens abaixo falham
# alto de proposito -- rode e me traga o erro se algo nao bater.
# -----------------------------------------------------------------------------

pkgs <- c("dplyr", "tidyr", "readr", "stringr")
inst <- pkgs[!(pkgs %in% rownames(installed.packages()))]
if (length(inst)) install.packages(inst, repos = "https://cloud.r-project.org")
invisible(lapply(pkgs, library, character.only = TRUE))

## ---- parametros (paper, bloco "FFR levels") ----
ARQ_IN            <- "data/raw/kalshi_fed_panel.csv"
ARQ_TRADES        <- "data/raw/kalshi_fed_trades.csv"
ARQ_OUT           <- "data/processed/serie_diaria.csv"
SNAPSHOT_DIR      <- Sys.getenv("KALSHI_SNAPSHOT", "")
STRIKE_INT        <- 0.25              # espacamento dos strikes da FFR
MOMENT_ADJUSTMENT <- STRIKE_INT / 2    # 0.125 -- ponto medio do balde
DAYS_BEFORE       <- 180               # horizonte original do paper
COL_PRECO         <- "mid"             # somente no fallback de candles
MIN_OBS           <- 120               # exigencia da lista

# Como colapsar o painel (uma reuniao por vez) em UMA serie:
#   "contrato_unico" - caminho completo de UMA reuniao. Sem roll, sem quebra
#                      artificial de nivel. Com DAYS_BEFORE=180 ja passa das 120
#                      obs. E a opcao mais limpa para Box-Jenkins e a default.
#   "front"          - a cada dia, a reuniao vigente mais proxima. Realista, mas
#                      o ROLL cria saltos de nivel quando o alvo troca; isso
#                      contamina os testes de raiz unitaria da Questao 2.
#   "horizonte_fixo" - a cada dia, a reuniao ~HORIZONTE_DIAS a frente.
MODO           <- "contrato_unico"
HORIZONTE_DIAS <- 60

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

## ---- leitura do snapshot completo, quando disponivel ----------------------
if (!nzchar(SNAPSHOT_DIR)) {
  snapshots <- list.dirs("data/raw", full.names = TRUE, recursive = FALSE)
  snapshots <- snapshots[grepl("snapshot_[0-9]{4}-[0-9]{2}-[0-9]{2}$", snapshots)]
  if (length(snapshots)) SNAPSHOT_DIR <- sort(snapshots, decreasing = TRUE)[1]
}

parse_api_time <- function(x) {
  x <- as.character(x)
  out <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  miss <- is.na(out)
  if (any(miss)) out[miss] <- as.POSIXct(x[miss], tz = "UTC")
  as.Date(out)
}

price_cents <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), NA_real_, ifelse(abs(x) <= 1, x * 100, x))
}

# Metadado por evento (data de liquidacao). So existe quando ha markets.csv da
# API; nos fallbacks fica NULL e a coluna sai NA na serie final.
evento_meta <- NULL

if (nzchar(SNAPSHOT_DIR) && file.exists(file.path(SNAPSHOT_DIR, "markets.csv"))) {
  message("Usando snapshot completo: ", SNAPSHOT_DIR)
  markets <- readr::read_csv(file.path(SNAPSHOT_DIR, "markets.csv"), show_col_types = FALSE)
  # REUNIAO vs LIQUIDACAO -- a API distingue duas datas e elas NAO sao a mesma coisa:
  #   close_time      = o mercado para de negociar; e a data da reuniao do FOMC.
  #   expiration_time = a Kalshi liquida e paga, ~uma semana depois.
  # Ex. KXFED-26JUL: reuniao 2026-07-29, liquidacao 2026-08-05.
  # A janela DAYS_BEFORE = 180 do paper conta dias ATE A REUNIAO -- o evento
  # economico que o mercado precifica. Por isso 'expiry' ancora em close_time e
  # 'liquidacao' fica guardada a parte, como metadado.
  market_map <- markets |>
    dplyr::transmute(
      ticker,
      event_ticker = .data[["_event_ticker"]],
      expiry = dplyr::coalesce(
        parse_api_time(close_time),
        parse_api_time(expected_expiration_time),
        parse_api_time(expiration_time)
      ),
      liquidacao = dplyr::coalesce(
        parse_api_time(expiration_time),
        parse_api_time(expected_expiration_time)
      )
    ) |>
    dplyr::filter(!is.na(ticker))

  evento_meta <- market_map |>
    dplyr::filter(!is.na(event_ticker)) |>
    dplyr::group_by(event_ticker) |>
    dplyr::summarise(liquidacao = max(liquidacao, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(liquidacao = dplyr::if_else(is.finite(liquidacao), liquidacao, as.Date(NA)))

  market_map <- dplyr::select(market_map, ticker, event_ticker, expiry)

  if (file.exists(file.path(SNAPSHOT_DIR, "trades.csv"))) {
    trades <- readr::read_csv(file.path(SNAPSHOT_DIR, "trades.csv"), show_col_types = FALSE)
    painel <- trades |>
      dplyr::left_join(market_map, by = "ticker") |>
      dplyr::mutate(
        created_time = as.POSIXct(created_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
        date = as.Date(created_time),
        preco = dplyr::coalesce(price_cents(yes_price_dollars), price_cents(yes_price)),
        volume = dplyr::coalesce(suppressWarnings(as.numeric(count_fp)),
                                 suppressWarnings(as.numeric(count)), 0)
      ) |>
      dplyr::filter(is.finite(preco), !is.na(date)) |>
      dplyr::arrange(created_time) |>
      dplyr::group_by(event_ticker, ticker, expiry, date) |>
      dplyr::summarise(preco = dplyr::last(preco), volume = sum(volume, na.rm = TRUE),
                       .groups = "drop")
  } else {
    candles <- readr::read_csv(file.path(SNAPSHOT_DIR, "candlesticks.csv"), show_col_types = FALSE)
    # A API ja devolveu candles com os sub-objetos price/yes_bid/yes_ask vazios --
    # 32.120 linhas so com ticker e timestamp no snapshot de 2026-09-10. Sem esta
    # checagem o painel sai VAZIO e o erro so aparece muito depois, num range() de
    # vetor de comprimento zero. Falha aqui, onde a causa e legivel.
    cols_preco <- c("yes_bid_close", "yes_ask_close", "price_close", "price_mean")
    cols_preco <- intersect(cols_preco, names(candles))
    preenchidas <- vapply(cols_preco, function(cc) sum(!is.na(candles[[cc]])), integer(1))
    if (!length(cols_preco) || all(preenchidas == 0L)) {
      stop("candlesticks.csv nao tem NENHUMA coluna de preco preenchida (",
           nrow(candles), " linhas lidas).\n",
           "  A API devolveu candles sem os sub-objetos price/yes_bid/yes_ask.\n",
           "  Use trades.csv (caminho principal) ou recolete o snapshot; conferir a\n",
           "  cobertura por coluna registrada em manifest.json.", call. = FALSE)
    }
    painel <- candles |>
      dplyr::left_join(market_map, by = "ticker") |>
      dplyr::mutate(
        date = as.Date(as.POSIXct(as.numeric(end_period_ts) - 1,
                                  origin = "1970-01-01", tz = "America/New_York")),
        preco = dplyr::coalesce((price_cents(yes_bid_close) + price_cents(yes_ask_close)) / 2,
                                price_cents(price_close)),
        volume = suppressWarnings(as.numeric(volume))
      ) |>
      dplyr::filter(is.finite(preco), !is.na(date))
  }
} else if (file.exists(ARQ_TRADES)) {
  message("Usando trades autenticados: ", ARQ_TRADES)
  trades <- readr::read_csv(ARQ_TRADES, show_col_types = FALSE) |>
    dplyr::mutate(
      created_time = as.POSIXct(created_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
      date = as.Date(created_time),
      event_ticker = stringr::str_remove(ticker, "-T\\d+\\.?\\d*$"),
      preco = suppressWarnings(as.numeric(yes_price_dollars)) * 100,
      volume = suppressWarnings(as.numeric(count_fp))
    ) |>
    dplyr::filter(is.finite(preco), !is.na(date))

  painel <- trades |>
    dplyr::arrange(created_time) |>
    dplyr::group_by(event_ticker, ticker, date) |>
    dplyr::summarise(preco = dplyr::last(preco), volume = sum(volume, na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::group_by(event_ticker, ticker) |>
    tidyr::complete(date = seq(min(date), max(date), by = "day")) |>
    tidyr::fill(preco, .direction = "down") |>
    dplyr::mutate(volume = dplyr::coalesce(volume, 0)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(preco))
} else {
  message("Trades nao encontrados; usando candles: ", ARQ_IN)
  candles <- readr::read_csv(ARQ_IN, show_col_types = FALSE)
  fallback_preco <- if (COL_PRECO == "mid") {
    dplyr::coalesce(candles$mid, candles$yes_close)
  } else {
    dplyr::coalesce(candles$yes_close, candles$mid)
  }
  painel <- candles |>
    dplyr::mutate(preco = fallback_preco * 100)
}

if (nzchar(SNAPSHOT_DIR) && nrow(painel) && "expiry" %in% names(painel)) {
  painel <- painel |>
    dplyr::group_by(event_ticker, ticker, expiry) |>
    tidyr::complete(date = seq(min(date), max(date), by = "day")) |>
    tidyr::fill(preco, .direction = "down") |>
    dplyr::mutate(volume = dplyr::coalesce(volume, 0)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(preco))
}

painel <- painel |>
  dplyr::mutate(
    strike = suppressWarnings(as.numeric(
      stringr::str_extract(ticker, "(?<=-T)\\d+\\.?\\d*")))
  )

if (all(is.na(painel$strike))) {
  stop("Nenhum strike '-T<numero>' encontrado nos tickers.\n",
       "  Isso quer dizer que o snapshot veio da familia de DECISAO (desfechos\n",
       "  categoricos, ex. KXFEDDECISION-28JAN-H26), nao da familia de NIVEL.\n",
       "  A metodologia deste script exige strikes numericos: use SERIES_TICKER\n",
       "  da familia de nivel (KXFED / FED, tickers '...-T4.25') no 00, ou\n",
       "  construa um mapa categoria->bps antes de chamar este script.",
       call. = FALSE)
}

# preco em CENTS (1-99), como no paper -- as constantes 99 e 49 abaixo dependem disso
painel <- painel |>
  dplyr::filter(!is.na(strike)) |>
  dplyr::filter(!is.na(preco)) |>
  dplyr::arrange(event_ticker, strike, date)

## ---- janela de DAYS_BEFORE antes da reuniao (paper: fill_dataless_days) ----
# O 'expiry' vem do close_time da API e NAO e recalculado aqui. A versao antiga
# fazia 'expiry = max(date)', o que para contratos ainda ativos devolvia a data
# do snapshot em vez da data da reuniao -- um artefato de coleta disfarcado de
# metadado. Ver docs/metodologia.md.
if (!"expiry" %in% names(painel) || all(is.na(painel$expiry))) {
  warning("Sem metadado de reuniao no painel: o horizonte sera INFERIDO de max(date) ",
          "por evento. Isso e um fallback -- para contratos ainda ativos o 'expiry' ",
          "resultante e a data do snapshot, nao a data da reuniao.", call. = FALSE)
  painel <- painel |>
    dplyr::group_by(event_ticker) |>
    dplyr::mutate(expiry = max(date, na.rm = TRUE)) |>
    dplyr::ungroup()
}
painel <- painel |>
  dplyr::filter(!is.na(expiry), date >= expiry - DAYS_BEFORE)

## ---- monotonicidade / nao-arbitragem: 'middle-out' do paper ----
# Preco decresce em strike (e sobrevivencia). Ancora no strike de preco mais
# proximo de 49 (mediana em cents na Kalshi, que precifica 1-99) e forca:
# a esquerda precos nao-decrescentes ao se afastar; a direita nao-crescentes.
middle_out <- function(precos, alvo = 49) {
  n <- length(precos)
  if (n < 2) return(precos)
  k   <- which.min(abs(precos - alvo))
  adj <- precos
  if (k > 1) {                       # strikes menores: preco tem de ser MAIOR
    esq <- 1:(k - 1)
    adj[esq] <- rev(cummax(c(precos[k], rev(precos[esq])))[-1])
  }
  if (k < n) {                       # strikes maiores: preco tem de ser MENOR
    dir <- (k + 1):n
    adj[dir] <- cummin(c(precos[k], precos[dir]))[-1]
  }
  adj
}

redistribute_empty_bins <- function(prob, precos) {
  if (length(prob) < 3) return(prob)
  protegido <- which(!is.na(precos) & precos > 49)
  protegido <- if (length(protegido)) max(protegido) else which.max(ifelse(is.na(precos), -Inf, precos))
  repeat {
    mudou <- FALSE
    for (i in seq_len(length(prob) - 1L)) {
      if (i != protegido && !is.na(precos[i]) && precos[i] > 49 &&
          prob[i] > 0 && prob[i + 1] == 0) {
        prob[i + 1] <- prob[i]
        prob[i] <- 0
        mudou <- TRUE
      }
        if (i != protegido && (i + 1L) != protegido && !is.na(precos[i]) &&
          precos[i] < 49 &&
          prob[i] == 0 && prob[i + 1] > 0) {
        prob[i] <- prob[i + 1]
        prob[i + 1] <- 0
        mudou <- TRUE
      }
    }
    if (!mudou) break
  }
  prob
}

painel <- painel |>
  dplyr::group_by(event_ticker, date) |>
  dplyr::arrange(strike, .by_group = TRUE) |>
  dplyr::mutate(preco_aj = middle_out(preco)) |>
  dplyr::ungroup()

## ---- sobrevivencia -> massa de probabilidade (paper: convert_to_probabilities) ----
# Balde extra abaixo do menor strike, para nao empurrar a media para 0.
baldes_baixos <- painel |>
  dplyr::group_by(event_ticker, date, expiry) |>
  dplyr::summarise(strike = min(strike) - STRIKE_INT, volume = 0, .groups = "drop") |>
  dplyr::mutate(preco_aj = NA_real_)

probs <- dplyr::bind_rows(
  dplyr::select(painel, event_ticker, date, expiry, strike, preco_aj, volume),
    baldes_baixos
  ) |>
  dplyr::group_by(event_ticker, date) |>
  dplyr::arrange(strike, .by_group = TRUE) |>
  dplyr::mutate(
    prob = dplyr::case_when(
      # balde extra (primeira linha): massa na cauda de baixo = 99 - P(acima do menor strike)
      is.na(dplyr::lag(strike))  ~ 99 - dplyr::lead(preco_aj),
      # baldes internos: P(acima de s_i) - P(acima de s_i+1)
      !is.na(dplyr::lead(strike)) ~ preco_aj - dplyr::lead(preco_aj),
      # cauda de cima: piso de 1 cent da Kalshi
      TRUE                        ~ preco_aj - 1
    )
  ) |>
  # massa negativa e residuo de ruido/arredondamento; zera antes de normalizar
  dplyr::mutate(prob = pmax(prob, 0)) |>
  dplyr::group_by(event_ticker, date) |>
  dplyr::mutate(prob = redistribute_empty_bins(prob, preco_aj)) |>
  dplyr::filter(!is.na(prob)) |>
  dplyr::mutate(soma = sum(prob, na.rm = TRUE)) |>
  dplyr::filter(soma > 0) |>
  dplyr::mutate(prob = prob / soma) |>
  dplyr::select(-soma) |>
  dplyr::ungroup()

## ---- momento: taxa esperada implicita (paper: get_moments) ----
momentos <- probs |>
  dplyr::group_by(event_ticker, date, expiry) |>
  dplyr::summarise(
    taxa_esperada = sum(prob * strike, na.rm = TRUE) + MOMENT_ADJUSTMENT,
    variancia     = sum(prob * (strike - sum(prob * strike))^2, na.rm = TRUE),
    volume        = sum(volume, na.rm = TRUE),
    n_strikes     = dplyr::n(),
    .groups       = "drop"
  ) |>
  dplyr::arrange(event_ticker, date)

## ---- painel -> serie unica ----
serie <- switch(MODO,
  "contrato_unico" = {
    liquidez <- momentos |>
      dplyr::group_by(event_ticker) |>
      dplyr::summarise(volume_total = sum(volume, na.rm = TRUE),
                       n_dias = dplyr::n(), .groups = "drop") |>
      dplyr::arrange(dplyr::desc(volume_total), dplyr::desc(n_dias))
    escolhida <- liquidez$event_ticker[1]
    message("Reuniao escolhida (maior volume total): ", escolhida,
            " (volume ", signif(liquidez$volume_total[1], 6), ")")
    momentos |> dplyr::filter(event_ticker == escolhida)
  },
  "front" = {
    momentos |>
      dplyr::filter(expiry >= date) |>
      dplyr::group_by(date) |>
      dplyr::slice_min(expiry, n = 1, with_ties = FALSE) |>
      dplyr::ungroup()
  },
  "horizonte_fixo" = {
    momentos |>
      dplyr::group_by(date) |>
      dplyr::slice_min(abs(as.numeric(expiry - date) - HORIZONTE_DIAS),
                       n = 1, with_ties = FALSE) |>
      dplyr::ungroup()
  },
  stop("MODO invalido: ", MODO)
)

serie <- serie |> dplyr::arrange(date) |> dplyr::distinct(date, .keep_all = TRUE)

# 'liquidacao' e metadado, nao entra em nenhum calculo -- fica na serie para que o
# relatorio possa citar a data de pagamento sem reabrir o snapshot.
serie <- if (!is.null(evento_meta)) {
  serie |>
    dplyr::left_join(evento_meta, by = "event_ticker") |>
    dplyr::relocate(liquidacao, .after = expiry)
} else {
  serie |> dplyr::mutate(liquidacao = as.Date(NA)) |>
    dplyr::relocate(liquidacao, .after = expiry)
}

## ---- checagens que falham alto ----
if (nrow(serie) < MIN_OBS) {
  warning("Serie com ", nrow(serie), " obs -- abaixo das ", MIN_OBS,
          " exigidas. Aumente DAYS_BACK/N_EVENTS_MAX no 00, ou use MODO='front'.")
}
if (any(!is.finite(serie$taxa_esperada))) {
  stop("taxa_esperada nao-finita: distribuicao degenerada em algum dia.", call. = FALSE)
}
# A serie tem de ficar dentro do range plausivel dos strikes observados.
faixa <- range(painel$strike, na.rm = TRUE)
if (min(serie$taxa_esperada) < faixa[1] - 1 || max(serie$taxa_esperada) > faixa[2] + 1) {
  stop("taxa_esperada fora da faixa dos strikes [", faixa[1], ", ", faixa[2],
       "] -- sinal de que a diferenciacao da sobrevivencia saiu errada.", call. = FALSE)
}

# Dias sem pregao: o ARIMA precisa de espacamento regular. Aqui so REPORTO;
# a decisao (preencher com ultimo valor vs. trabalhar em dias uteis) e da
# Questao 1 e fica documentada no relatorio.
faltando <- as.integer(diff(range(serie$date))) + 1L - nrow(serie)
if (faltando > 0) {
  message("Atencao: ", faltando, " dias de calendario sem observacao no intervalo. ",
          "Decida na Questao 1 como tratar (preencher vs. dias uteis).")
}

readr::write_csv(serie, ARQ_OUT)

cat(sprintf("Serie: %d obs | %s a %s | ponto medio da faixa de %.3f a %.3f\n",
            nrow(serie), as.character(min(serie$date)), as.character(max(serie$date)),
            min(serie$taxa_esperada), max(serie$taxa_esperada)))
cat(sprintf("Reuniao (close_time): %s | liquidacao (expiration_time): %s\n",
            as.character(serie$expiry[1]), as.character(serie$liquidacao[1])))

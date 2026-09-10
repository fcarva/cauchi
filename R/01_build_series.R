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
# O termo strike_int/2 (= 0.125) nao e detalhe: como o balde (s_i, s_i+0.25]
# fica indexado por s_i, sem o ajuste a serie inteira vem 12,5 bps baixa.
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
STRIKE_INT        <- 0.25              # espacamento dos strikes da FFR
MOMENT_ADJUSTMENT <- STRIKE_INT / 2    # 0.125 -- ponto medio do balde
DAYS_BEFORE       <- 180               # horizonte original do paper
# FONTE DE PRECO -- decisao medida, nao herdada.
#
# Diercks, Katz & Wright (2026, FEDS 2026-010) usam o ULTIMO PRECO NEGOCIADO e
# advertem contra o ponto medio bid/ask (nota de rodape 4): "midpoints of
# bid-ask spreads seem to introduce additional issues due to occasionally large
# spreads on tail outcomes".
#
# Esse conselho vale para o pipeline DELES, que e trade-level: la "ultimo
# negocio" e uma transacao de verdade. No nosso caminho de CANDLESTICKS o
# yes_close de um dia sem negocios e preco velho, e a medicao mostra que a
# advertencia se inverte (KXFED-26JUL, tests/audita_contratos.R):
#
#              obs   dp da dif   maior salto   curtose    AC(1)
#   yes_close  153    20,5 bps     127,8 bps      21,4   -0,379
#   mid        179     5,4 bps      31,2 bps      12,9   -0,115
#
# O AC(1) e a evidencia direta: -0,379 no ultimo negocio contra -0,115 no mid e
# a assinatura do bid-ask bounce, que o ponto medio remove. E o yes_close perde
# 26 observacoes por precos ausentes.
#
# Portanto: quando ha trades (ARQ_TRADES), o pipeline usa o ultimo negocio e
# segue o paper. Este parametro governa so o fallback por candlesticks, onde
# `mid` e mensuravelmente melhor.
COL_PRECO         <- "mid"             # fallback por candlesticks: ver acima
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

## ---- leitura + agregacao diaria ----
if (file.exists(ARQ_TRADES)) {
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
    dplyr::summarise(
      preco = dplyr::last(preco),
      volume = sum(volume, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::group_by(event_ticker, ticker) |>
    tidyr::complete(date = seq(min(date), max(date), by = "day")) |>
    tidyr::fill(preco, .direction = "down") |>
    dplyr::mutate(volume = dplyr::coalesce(volume, 0)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(preco))
} else {
  message("Trades nao encontrados; usando candles: ", ARQ_IN)
  painel <- readr::read_csv(ARQ_IN, show_col_types = FALSE) |>
    dplyr::mutate(preco = dplyr::coalesce(.data[[COL_PRECO]], yes_close) * 100)
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

## ---- expiry por reuniao + janela de DAYS_BEFORE (paper: fill_dataless_days) ----
painel <- painel |>
  dplyr::group_by(event_ticker) |>
  dplyr::mutate(expiry = max(date, na.rm = TRUE)) |>
  dplyr::ungroup() |>
  dplyr::filter(date >= expiry - DAYS_BEFORE)

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
  dplyr::summarise(strike = min(strike) - STRIKE_INT, .groups = "drop") |>
  dplyr::mutate(preco_aj = NA_real_)

probs <- dplyr::bind_rows(
    dplyr::select(painel, event_ticker, date, expiry, strike, preco_aj),
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
    n_strikes     = dplyr::n(),
    .groups       = "drop"
  ) |>
  dplyr::arrange(event_ticker, date)

## ---- painel -> serie unica ----
serie <- switch(MODO,
  "contrato_unico" = {
    # SELECAO POR LIQUIDEZ, nao por numero de dias.
    # Kagan & Baiocchi (2026) mostram que a calibracao melhora quase
    # monotonicamente com o volume negociado e com o numero de traders unicos.
    # Escolher o contrato com mais DIAS seleciona tipicamente a reuniao mais
    # distante -- que e a mais rala -- e maximiza exatamente o ruido de
    # microestrutura que o artigo documenta. Entre os contratos que cumprem o
    # minimo de observacoes, pega-se o de MAIOR volume.
    forcado <- Sys.getenv("KALSHI_EVENTO", "")
    liq <- painel |>
      dplyr::group_by(event_ticker) |>
      dplyr::summarise(volume = sum(volume, na.rm = TRUE),
                       dias   = dplyr::n_distinct(date),
                       ate    = max(date), .groups = "drop")
    eleg <- liq |> dplyr::filter(dias >= MIN_OBS)
    if (!nrow(eleg)) eleg <- liq
    escolhida <- if (nzchar(forcado)) forcado else
      eleg |> dplyr::arrange(dplyr::desc(volume)) |> dplyr::slice(1) |>
        dplyr::pull(event_ticker)

    info <- liq[liq$event_ticker == escolhida, ]
    message("Reuniao escolhida (maior volume): ", escolhida,
            " | volume ", format(round(info$volume), big.mark = "."),
            " | ", info$dias, " dias")
    # Um contrato ainda VIVO nao tem expiry verdadeiro: expiry = max(date) e
    # apenas a data do snapshot. A serie entao nao termina na resolucao, e a
    # queda de variancia com a aproximacao da reuniao -- o fenomeno central do
    # artigo -- fica fora da amostra.
    if (info$ate >= max(painel$date))
      warning("Contrato '", escolhida, "' ainda nao resolveu: a serie termina na ",
              "data do snapshot, nao na reuniao. A janela de validacao da Q7 NAO ",
              "sera o periodo de resolucao da incerteza.", call. = FALSE)
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

cat(sprintf("Serie: %d obs | %s a %s | taxa esperada de %.3f a %.3f\n",
            nrow(serie), as.character(min(serie$date)), as.character(max(serie$date)),
            min(serie$taxa_esperada), max(serie$taxa_esperada)))

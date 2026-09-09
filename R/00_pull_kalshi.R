###############################################################################
# 00_pull_kalshi.R
# -----------------------------------------------------------------------------
# Constroi a BASE DE DADOS (painel diario) dos mercados de decisao do Fed na
# Kalshi, para a analise Box-Jenkins da Lista 01 (Econometria II, PPGEco/UFES).
# Alinhado a Diercks, Katz & Wright (2026), "Kalshi and the Rise of Macro Markets".
#
# ESTE SCRIPT NAO FAZ PARTE DE run_all.R -- DE PROPOSITO.
# Ele fala com a API (dado VIVO). Rode UMA vez, commite o CSV gerado, e a partir
# dai a analise inteira le o snapshot CONGELADO. Se re-puxar depois, os numeros
# do relatorio mudam e a reprodutibilidade exigida pelo professor quebra.
#
# COMO USAR
#   1. Descoberta (confirma o series_ticker do Fed, nao grava nada):
#          Rscript R/00_pull_kalshi.R --discover
#      Olhe a tabela impressa e ajuste SERIES_TICKER abaixo.
#   2. Coleta (grava o snapshot):
#          Rscript R/00_pull_kalshi.R
#      Gera:
#        data/raw/kalshi_fed_panel.csv    <- o "banco" (entrega da reprodutibilidade)
#        data/raw/sessionInfo_pull.txt    <- versoes de R e pacotes NA COLETA
#   3. Commite os dois arquivos. Nunca mais rode este script para esta entrega.
#
# CAVEATS (importantes)
#   - Cutoff historico: candlesticks de mercados liquidados antes do cutoff so
#     existem em /historical/... O script tenta o endpoint "live" e cai no
#     "historical" automaticamente por mercado.
#   - Verifique os tickers: a Kalshi renomeou familias com prefixo KX. Nao confie
#     em nomes fixos; a descoberta (--discover) imprime os tickers REAIS.
#   - Preco = probabilidade implicita (risco-neutro), em 0-1. Guardo o close e o
#     ponto medio bid/ask (mid); o mid mitiga o "bid-ask bounce" (microestrutura).
#   - Esta e a BASE bruta (painel por desfecho/reuniao/dia). A serie unica de 120+
#     obs pro ARIMA (ex.: taxa esperada implicita, encadeando reunioes) e o proximo
#     passo (01_build_series.R), feito EM CIMA deste painel.
###############################################################################

## ---- pacotes ----
pkgs <- c("httr", "jsonlite", "dplyr", "tidyr", "lubridate", "purrr", "readr", "tibble")
inst <- pkgs[!(pkgs %in% rownames(installed.packages()))]
if (length(inst)) install.packages(inst, repos = "https://cloud.r-project.org")
invisible(lapply(pkgs, library, character.only = TRUE))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

## ---- config ----
BASE          <- "https://api.elections.kalshi.com/trade-api/v2"
CATEGORY      <- "Economics"        # categoria usada na descoberta
SERIES_TICKER <- "KXFEDDECISION"    # <-- CONFIRME/AJUSTE apos rodar --discover
N_EVENTS_MAX  <- 12                 # nao mais que N reunioes (eventos) recentes
DAYS_BACK     <- 200                # janela por mercado, em dias
OUTDIR        <- "data/raw"         # DEVE bater com o que 01_build_series.R le
OUTFILE       <- file.path(OUTDIR, "kalshi_fed_panel.csv")
FORCE_REPULL  <- FALSE              # TRUE apenas para descongelar de proposito

dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

## ---- helper: GET com retry + parse ----
kget <- function(path, query = list()) {
  url <- paste0(BASE, path)
  for (att in 1:4) {
    r <- tryCatch(httr::GET(url, query = query, httr::timeout(30)),
                  error = function(e) NULL)
    if (!is.null(r) && httr::status_code(r) == 200) {
      return(jsonlite::fromJSON(
        httr::content(r, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE))
    }
    Sys.sleep(1.5 * att)   # backoff simples
  }
  warning("Falhou GET: ", url)
  NULL
}

## =============================================================================
## BLOCO 1 - DESCOBERTA   (Rscript R/00_pull_kalshi.R --discover)
## =============================================================================
list_series <- function(category) {
  out <- kget("/series", list(category = category))
  ss  <- out$series %||% list()
  tibble::tibble(
    ticker = purrr::map_chr(ss, ~ .x$ticker %||% NA_character_),
    title  = purrr::map_chr(ss, ~ .x$title  %||% NA_character_)
  )
}

if (any(commandArgs(trailingOnly = TRUE) %in% c("--discover", "--discovery"))) {
  cat("Series da categoria '", CATEGORY, "' na Kalshi:\n\n", sep = "")
  s <- list_series(CATEGORY)
  print(s, n = 200)
  cat("\nProcure a familia do Fed. Duas costumam aparecer, e a escolha importa:\n",
      "  KXFED          - 'Fed funds rate after <mes> meeting?' -> desfechos sao\n",
      "                   FAIXAS DE TAXA (buckets). Permite E[taxa] = sum(p_i * taxa_i).\n",
      "  KXFEDDECISION  - 'Fed decision in <mes>?'               -> desfechos sao\n",
      "                   CATEGORIAS de decisao (corte/manutencao/alta).\n",
      "Ajuste SERIES_TICKER no topo deste arquivo e rode sem --discover.\n", sep = "")
  quit(save = "no", status = 0)
}

## =============================================================================
## BLOCO 2 - PUXA OS DADOS E MONTA O PAINEL
## =============================================================================

# Guarda de congelamento: o snapshot entregue nao pode ser sobrescrito por acidente.
if (file.exists(OUTFILE) && !FORCE_REPULL) {
  stop("Snapshot ja existe em '", OUTFILE, "'.\n",
       "  Os dados da Kalshi sao VIVOS: re-puxar muda os numeros do relatorio e\n",
       "  quebra a reprodutibilidade. Se voce REALMENTE quer descongelar, ponha\n",
       "  FORCE_REPULL <- TRUE no topo e commite o novo CSV como um novo snapshot.",
       call. = FALSE)
}

list_events <- function(series_ticker) {
  ev <- list(); cursor <- NULL
  repeat {
    out <- kget("/events", list(series_ticker      = series_ticker,
                                with_nested_markets = "true",
                                limit               = 200,
                                cursor              = cursor))
    if (is.null(out)) break
    ev     <- c(ev, out$events %||% list())
    cursor <- out$cursor %||% ""
    if (cursor == "" || length(ev) >= 500) break
  }
  ev
}

# extrai probabilidade (0-1) de um no de preco (price / yes_bid / yes_ask),
# tolerando as duas convencoes da API (cents inteiros vs string em dolares).
prob_of <- function(node, field = "close") {
  if (is.null(node)) return(NA_real_)
  d <- node[[paste0(field, "_dollars")]]
  if (!is.null(d)) return(suppressWarnings(as.numeric(d)))
  v <- node[[field]]
  if (!is.null(v)) return(v / 100)
  NA_real_
}

candles_market <- function(series_ticker, ticker, days_back = DAYS_BACK) {
  end_ts   <- as.integer(as.numeric(Sys.time()))
  start_ts <- end_ts - days_back * 24L * 3600L
  q <- list(start_ts = start_ts, end_ts = end_ts, period_interval = 1440)

  out <- kget(sprintf("/series/%s/markets/%s/candlesticks", series_ticker, ticker), q)
  cs  <- out$candlesticks %||% list()
  if (!length(cs)) {                                   # fallback: historico
    out <- kget(sprintf("/historical/markets/%s/candlesticks", ticker), q)
    cs  <- out$candlesticks %||% list()
  }
  if (!length(cs)) return(NULL)

  tibble::tibble(
    ticker    = ticker,
    # end_period_ts marca o FIM do candle. Num candle diario que fecha a meia-noite,
    # converter direto jogaria a obs para o dia seguinte; -1s ancora no dia coberto.
    date      = as.Date(as.POSIXct(purrr::map_dbl(cs, ~ .x$end_period_ts) - 1,
                                   origin = "1970-01-01", tz = "America/New_York")),
    yes_close = purrr::map_dbl(cs, ~ prob_of(.x$price, "close")),
    yes_mean  = purrr::map_dbl(cs, ~ prob_of(.x$price, "mean")),
    bid       = purrr::map_dbl(cs, ~ prob_of(.x$yes_bid, "close")),
    ask       = purrr::map_dbl(cs, ~ prob_of(.x$yes_ask, "close")),
    volume    = purrr::map_dbl(cs, ~ as.numeric(.x$volume %||% .x$volume_fp %||% NA))
  ) |>
    dplyr::mutate(
      mid = rowMeans(cbind(bid, ask), na.rm = TRUE),
      mid = ifelse(is.nan(mid), NA_real_, mid)   # bid e ask ambos NA -> NA, nao NaN
    )
}

message("Buscando eventos de ", SERIES_TICKER, " ...")
events <- list_events(SERIES_TICKER)
if (!length(events))
  stop("Nenhum evento encontrado. Confira SERIES_TICKER com 'Rscript R/00_pull_kalshi.R --discover'.")

# fica so com as N reunioes mais recentes (assumindo ordem decrescente da API).
# CONFIRA no resumo impresso no fim se as reunioes vieram as que voce esperava.
events <- utils::head(events, N_EVENTS_MAX)

panel <- purrr::map_dfr(events, function(ev) {
  et  <- ev$event_ticker %||% NA_character_
  mks <- ev$markets %||% list()
  if (!length(mks)) return(NULL)
  purrr::map_dfr(mks, function(mk) {
    tk <- mk$ticker %||% NA_character_
    cc <- candles_market(SERIES_TICKER, tk)
    if (is.null(cc)) return(NULL)
    cc$event_ticker <- et
    cc$outcome      <- mk$yes_sub_title %||% mk$subtitle %||% mk$title %||% tk
    Sys.sleep(0.2)   # gentileza com o rate limit
    cc
  })
})

if (is.null(panel) || !nrow(panel))
  stop("Painel vazio: verifique tickers/janela de datas.")

panel <- panel |>
  dplyr::arrange(event_ticker, outcome, date) |>
  dplyr::select(event_ticker, outcome, ticker, date,
                yes_close, yes_mean, mid, bid, ask, volume)

readr::write_csv(panel, OUTFILE)
writeLines(capture.output(sessionInfo()), file.path(OUTDIR, "sessionInfo_pull.txt"))

cat(sprintf("OK: %d linhas | %d reunioes | %d dias | %s a %s\n",
            nrow(panel),
            dplyr::n_distinct(panel$event_ticker),
            dplyr::n_distinct(panel$date),
            as.character(min(panel$date, na.rm = TRUE)),
            as.character(max(panel$date, na.rm = TRUE))))

# Resumo por reuniao: confira se as reunioes/desfechos sao os esperados ANTES de
# commitar o snapshot. Estes numeros sao os que eu preciso pra escrever o 01.
cat("\nPor reuniao (event_ticker | desfechos | dias | primeiro dia | ultimo dia):\n")
print(as.data.frame(
  panel |>
    dplyr::group_by(event_ticker) |>
    dplyr::summarise(desfechos = dplyr::n_distinct(outcome),
                     dias      = dplyr::n_distinct(date),
                     de        = min(date, na.rm = TRUE),
                     ate       = max(date, na.rm = TRUE),
                     .groups   = "drop")
))

cat("\nDesfechos distintos observados (rotulos exatos, usados pelo 01):\n")
print(sort(unique(panel$outcome)))

cat("\nAgora commite '", OUTFILE, "' e '", file.path(OUTDIR, "sessionInfo_pull.txt"),
    "'.\nNAO rode este script de novo para esta entrega.\n", sep = "")

## =============================================================================
## BLOCO 3 - EXEMPLO (so pra sentir a base; a serie final vem no 01)
## Probabilidade implicita diaria de "manutencao" na reuniao mais recente.
## =============================================================================
# ult <- panel |> dplyr::filter(event_ticker == dplyr::last(sort(unique(event_ticker))))
# hold <- ult |>
#   dplyr::filter(grepl("hold|maint|manter|unchanged", outcome, ignore.case = TRUE)) |>
#   dplyr::group_by(date) |>
#   dplyr::summarise(p_hold = mean(mid, na.rm = TRUE), .groups = "drop") |>
#   dplyr::arrange(date)
# plot(hold$date, hold$p_hold, type = "l",
#      xlab = "data", ylab = "P(manutencao)", main = "Kalshi - reuniao mais recente")

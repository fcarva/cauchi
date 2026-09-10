# fun_distribuicao.R  --------------------------------------------------------
# Nucleo da construcao da distribuicao implicita. BASE R PURO, de proposito:
# roda sem nenhum pacote instalado, e por isso pode ser testado isoladamente
# (ver tests/test_distribuicao.R). O 01_build_series.R so faz a manipulacao de
# dados em volta; toda a matematica esta aqui.
#
# Metodologia: Diercks, Katz & Wright (2026), replication package
# jdkatz21/Prediction_Markets_Public,
# code/convert_trades_to_pdfs/convert_trade_level_data_cdfs.R
#
# CONVENCAO: precos em CENTS (1-99), como na Kalshi. As constantes 99 (teto) e
# 49 (mediana; a Kalshi precifica 1-99, entao a mediana e 49 e nao 50) dependem
# disso. Strikes em pontos percentuais de taxa (ex.: 4.25).
# -----------------------------------------------------------------------------

#' Impoe monotonicidade (nao-arbitragem) nos precos de uma familia de strikes.
#'
#' O preco de 'FED-...-T<s>' e P(taxa acima de s), logo tem de ser DECRESCENTE
#' em s. Ruido e baixa liquidez violam isso. O algoritmo 'middle-out' do paper
#' ancora no strike cujo preco esta mais proximo de 49 cents -- o bin central,
#' que o paper argumenta ser o mais liquido e portanto o mais confiavel -- e
#' propaga a restricao para fora, em vez de propagar a partir de uma cauda
#' (onde um unico preco ruim contaminaria toda a distribuicao).
#'
#' @param precos Vetor de precos em cents, JA ordenado por strike crescente.
#' @param alvo   Preco-ancora (49 = mediana na escala 1-99 da Kalshi).
#'
#' DIVERGENCIA DOCUMENTADA: o texto do paper (FEDS 2026-010, secao 3) diz
#' "constructing the distribution outward from the MODE toward the tails". Ja o
#' codigo do replication package deles ancora em `target = 49`, que e o
#' cruzamento da MEDIANA na escala 1-99 da Kalshi, nao a moda. Este codigo segue
#' o CODIGO deles, nao a prosa. Vale registrar a divergencia no relatorio.
#' @return Vetor de precos ajustados, nao-crescente.
#' Os tres metodos de monotonicidade do replication package.
#'
#' `robustness_data_runner.R` varia `clean_data_method` entre "middle-out",
#' "left-to-right" e "right-to-left" -- e a checagem de robustez DELES. Os tres
#' ficam disponiveis aqui para que o relatorio possa reproduzir a mesma checagem.
#'
#' @param metodo "middle-out" (padrao), "left-to-right" ou "right-to-left".
impoe_monotonicidade <- function(precos, metodo = "middle-out", alvo = 49) {
  switch(metodo,
    "middle-out"    = middle_out(precos, alvo),
    # da cauda direita para a esquerda: preco nao pode subir com o strike
    "right-to-left" = rev(cummax(rev(precos))),
    # da cauda esquerda para a direita
    "left-to-right" = -cummax(-precos),
    stop("metodo invalido: ", metodo))
}

middle_out <- function(precos, alvo = 49) {
  n <- length(precos)
  if (n < 2L) return(precos)
  k   <- which.min(abs(precos - alvo))
  adj <- precos
  if (k > 1L) {                        # strikes menores: preco tem de ser MAIOR
    esq <- 1:(k - 1L)
    adj[esq] <- rev(cummax(c(precos[k], rev(precos[esq])))[-1L])
  }
  if (k < n) {                         # strikes maiores: preco tem de ser MENOR
    dir <- (k + 1L):n
    adj[dir] <- cummin(c(precos[k], precos[dir]))[-1L]
  }
  adj
}

#' Converte uma funcao de sobrevivencia em massa de probabilidade por balde.
#'
#' ESTE E O PASSO QUE A ESTRUTURA DOS DADOS CONVIDA A ERRAR. O yes_price de
#' 'T4.25' e P(taxa > 4.25) -- a cauda -- e nao a probabilidade do balde
#' (4.25, 4.50]. A massa de cada balde sai da DIFERENCA entre strikes
#' adjacentes:
#'    cauda de baixo (balde extra em s_1 - strike_int): 99 - p_1
#'    balde interno i, indexado por s_i:                p_i - p_{i+1}
#'    cauda de cima, indexada por s_n:                  p_n - 1
#' O balde extra abaixo do menor strike existe para nao empurrar a media para 0
#' quando nem o menor strike listado foi superado.
#'
#' @param strikes    Strikes crescentes.
#' @param precos_aj  Precos ajustados (saida de middle_out), em cents.
#' @param strike_int Espacamento entre strikes (0.25 para a FFR).
#' @return data.frame(strike, prob) com prob somando 1.
massa_de_sobrevivencia <- function(strikes, precos_aj, strike_int) {
  stopifnot(length(strikes) == length(precos_aj), length(strikes) >= 1L)
  o <- order(strikes)
  s <- strikes[o]; p <- precos_aj[o]
  n <- length(s)

  s_out <- c(s[1L] - strike_int, s)              # balde extra na cauda de baixo
  m     <- numeric(n + 1L)
  m[1L] <- 99 - p[1L]                            # P(taxa <= menor strike)
  if (n >= 2L) m[2:n] <- p[1:(n - 1L)] - p[2:n]  # baldes internos
  m[n + 1L] <- p[n] - 1                          # cauda de cima (piso de 1 cent)

  m <- pmax(m, 0)                                # massa negativa = ruido residual
  tot <- sum(m)
  if (!is.finite(tot) || tot <= 0) return(NULL)
  data.frame(strike = s_out, prob = m / tot)
}

#' Taxa esperada implicita a partir da distribuicao.
#'
#' O ajuste de meio-balde NAO e arredondamento: o balde (s, s + strike_int]
#' fica indexado pelo seu limite INFERIOR s. Sem somar strike_int/2 a serie
#' inteira fica strike_int/2 baixa -- para a FFR, 12,5 pontos-base de vies
#' uniforme, que nao aparece no formato da serie, so no nivel.
#'
#' @param strikes            Strikes (indices dos baldes).
#' @param probs              Massa de cada balde (soma 1).
#' @param moment_adjustment  strike_int/2.
taxa_esperada <- function(strikes, probs, moment_adjustment) {
  sum(probs * strikes) / sum(probs) + moment_adjustment
}

#' Le o strike do ticker, tolerando strike NEGATIVO e sinal Unicode.
#'
#' AUDITORIA DA FONTE. O replication package usa TRES regexes diferentes:
#'   convert_trade_level_data_cdfs.R:81   "(?<=-T)\\d+\\.?\\d*"   -> REJEITA negativo
#'   convert_bid_ask_data_cdfs.R:28       "(?<=-T)[^\\-]+$" + troca de "U+2212" por "-"
#'   convert_trade_level_data_pdfs.R:83   "[^-]+$"
#' So o do bid-ask aceita strike negativo. E `data_convert_runner.R` roteia o
#' arquivo de CPI mensal (MoM), que pode ser negativo, pelo caminho que REJEITA.
#' Nessa rota, um strike negativo vira NA e a cauda esquerda da distribuicao
#' desaparece em silencio, viesando a media para cima.
#'
#' Para a FFR o ponto e inocuo -- taxas nao sao negativas -- mas o parser aqui
#' aceita o caso mesmo assim, para nao herdar a fragilidade.
le_strike <- function(ticker) {
  # useBytes: o sinal de menos Unicode (U+2212) chega como bytes e2 88 92; sem
  # isso a substituicao quebra em locale nao-UTF-8, que e o caso de muitas
  # instalacoes de R no Windows.
  tk <- gsub("\xe2\x88\x92", "-", ticker, useBytes = TRUE)
  out <- rep(NA_real_, length(tk))
  m <- regexpr("(?<=-T)-?[0-9]+\\.?[0-9]*", tk, perl = TRUE)
  hit <- m != -1L
  out[hit] <- as.numeric(regmatches(tk, m))
  out
}

#' Filtra spreads largos, como `read_bid_ask(filter_large_spreads = TRUE)` deles.
#'
#' AUDITORIA DA FONTE. O Apendice A do paper conclui que o ponto medio bid/ask e
#' pouco confiavel "due to occasionally large spreads on tail outcomes" -- mas o
#' proprio `convert_bid_ask_data_cdfs.R` deles carrega um filtro que trata
#' exatamente isso: marca `abs(bid - ask) > 10` cents e arrasta o ultimo par
#' bid/ask bom. Nao da para saber, pelo material publico, se a Figura A.1 foi
#' produzida com ou sem esse filtro. Se foi sem, a comparacao do apendice nao e
#' contra o melhor pipeline de bid/ask deles.
#'
#' @param bid,ask em cents (1-99). @param limite spread maximo tolerado, em cents.
#' @return indice logico das observacoes a DESCARTAR.
spread_largo <- function(bid, ask, limite = 10) {
  is.na(bid) | is.na(ask) | (bid == 0 & ask == 99) | abs(ask - bid) > limite
}

#' Variancia da distribuicao implicita (usada como diagnostico de incerteza).
variancia_implicita <- function(strikes, probs) {
  mu <- sum(probs * strikes) / sum(probs)
  sum(probs * (strikes - mu)^2) / sum(probs)
}

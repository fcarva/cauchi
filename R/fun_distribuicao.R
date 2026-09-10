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
#' @return Vetor de precos ajustados, nao-crescente.
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

#' Variancia da distribuicao implicita (usada como diagnostico de incerteza).
variancia_implicita <- function(strikes, probs) {
  mu <- sum(probs * strikes) / sum(probs)
  sum(probs * (strikes - mu)^2) / sum(probs)
}

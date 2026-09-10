# 99_viz.R -------------------------------------------------------------------
# Casa de estilo para figuras e tabelas: rigor do Federal Reserve Board na
# apresentacao, convencao brasileira na notacao.
#
# FIGURAS. O padrao visual segue o proprio codigo do Fed Board: em
# `code/utilities.R` do replication package de Diercks, Katz & Wright (FEDS
# 2026-010), as figuras usam moldura fechada e marcas de escala VOLTADAS PARA
# DENTRO (`par(tck = -0.02)`). `theme_feds()` reproduz isso em ggplot2.
#
# NOTACAO. Separador decimal VIRGULA e milhar PONTO, rotulos em portugues,
# legendas no formato "Figura N -- titulo" com bloco "Fonte:".
#
# PALETA. Validada com o six-checks (surface #fcfcfb, modo claro, pares "all"):
#   [PASS] faixa de luminosidade  [PASS] piso de croma
#   [PASS] separacao CVD: pior par #1baf7a<->#c0392b  dE 12,8 (deuteranopia)
#   [PASS] piso de visao normal:  pior par #1baf7a<->#2a78d6  dE 24,0
#   [WARN] contraste de #1baf7a contra o fundo = 2,74 (< 3:1)
# O WARN obriga RELEVO: a serie aqua so aparece com rotulo direto visivel e
# sempre acompanhada da tabela de metricas. Nao usar aqua sem rotulo.
#
# MODO UNICO. O destino e um PDF impresso, entao a paleta e calibrada so para
# fundo claro. E escolha, nao omissao.
# -----------------------------------------------------------------------------

## ---- paleta -----------------------------------------------------------------
COR <- list(
  tinta       = "#101418",  # observado / texto primario
  tinta_fraca = "#5a6470",  # texto secundario, notas
  grade       = "#e3e6ea",  # grade recessiva
  serie_1     = "#2a78d6",  # azul   -- modelo ARIMA
  serie_2     = "#c0392b",  # tijolo -- passeio aleatorio
  serie_3     = "#1baf7a",  # aqua   -- sazonal ingenuo (SEMPRE com rotulo)
  banda       = "#2a78d6"   # intervalo de previsao (mesma familia do serie_1)
)

## ---- notacao brasileira ------------------------------------------------------
#' Formata numero no padrao brasileiro: virgula decimal, ponto de milhar.
fmt_br <- function(x, dig = 2) {
  ifelse(is.na(x), "--",
         formatC(x, format = "f", digits = dig, big.mark = ".", decimal.mark = ","))
}

#' Escala de eixo com virgula decimal, para ggplot.
escala_br <- function(dig = 2) function(x) fmt_br(x, dig)

#' Estrelas de significancia na convencao da lista (* 10%, ** 5%, *** 1%).
estrelas <- function(p) {
  ifelse(is.na(p), "", ifelse(p < 0.01, "***", ifelse(p < 0.05, "**",
         ifelse(p < 0.10, "*", ""))))
}

## ---- tema das figuras --------------------------------------------------------
#' Tema no padrao do Federal Reserve Board: moldura fechada, marcas para dentro,
#' grade recessiva, tipografia sem serifa, sem enfeite.
theme_feds <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.border      = ggplot2::element_rect(colour = COR$tinta, fill = NA, linewidth = 0.4),
      panel.grid.minor  = ggplot2::element_blank(),
      panel.grid.major  = ggplot2::element_line(colour = COR$grade, linewidth = 0.3),
      axis.ticks        = ggplot2::element_line(colour = COR$tinta, linewidth = 0.3),
      axis.ticks.length = ggplot2::unit(-0.10, "cm"),   # PARA DENTRO, como o FRB
      axis.text         = ggplot2::element_text(colour = COR$tinta_fraca, size = base_size - 2,
                                                margin = ggplot2::margin(t = 5, r = 5)),
      axis.title        = ggplot2::element_text(colour = COR$tinta_fraca, size = base_size - 2),
      plot.title        = ggplot2::element_text(colour = COR$tinta, size = base_size,
                                                face = "bold", hjust = 0),
      plot.subtitle     = ggplot2::element_text(colour = COR$tinta_fraca, size = base_size - 1,
                                                hjust = 0, margin = ggplot2::margin(b = 8)),
      plot.caption      = ggplot2::element_text(colour = COR$tinta_fraca, size = base_size - 3,
                                                hjust = 0, margin = ggplot2::margin(t = 10)),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      legend.position   = "top",
      legend.justification = "left",
      legend.title      = ggplot2::element_blank(),
      legend.key.width  = ggplot2::unit(1.1, "cm"),
      legend.text       = ggplot2::element_text(colour = COR$tinta, size = base_size - 2),
      plot.margin       = ggplot2::margin(10, 14, 8, 10)
    )
}

#' Legenda no padrao "Figura N -- titulo" com bloco "Fonte:".
#' A nota de fonte e obrigatoria: identifica o snapshot congelado.
nota_fonte <- function(extra = NULL) {
  base <- paste0("Fonte: elaboracao propria a partir de dados da Kalshi ",
                 "(snapshot congelado em data/raw/). Metodo de construcao da ",
                 "distribuicao implicita conforme Diercks, Katz e Wright (2026).")
  if (is.null(extra)) base else paste0(base, " ", extra)
}

#' Grava a figura no padrao do relatorio.
salvar_fig <- function(p, arquivo, largura = 7.2, altura = 4.2) {
  ggplot2::ggsave(file.path("output/figures", arquivo), p,
                  width = largura, height = altura, dpi = 200, bg = "white")
  invisible(file.path("output/figures", arquivo))
}

## ---- tabelas estatisticas ----------------------------------------------------
#' Tabela de estimacao no padrao academico: coeficiente com estrelas, erro-padrao
#' entre parenteses na linha de baixo, notacao brasileira.
#'
#' @param coefs vetor nomeado de coeficientes
#' @param ses   vetor nomeado de erros-padrao
#' @param dig   casas decimais
#' @return data.frame com uma linha por parametro, pronta para kable/LaTeX
tabela_coef <- function(coefs, ses, dig = 4) {
  t_stat <- coefs / ses
  p_val  <- 2 * stats::pnorm(-abs(t_stat))
  data.frame(
    parametro   = names(coefs),
    estimativa  = paste0(fmt_br(coefs, dig), estrelas(p_val)),
    erro_padrao = paste0("(", fmt_br(ses, dig), ")"),
    estatistica_t = fmt_br(t_stat, 3),
    p_valor     = fmt_br(p_val, 4),
    stringsAsFactors = FALSE
  )
}

#' Nota de rodape padrao de tabela de estimacao.
nota_tabela <- function(extra = NULL) {
  base <- paste0("Erros-padrao entre parenteses. ",
                 "Significancia: * 10%, ** 5%, *** 1%. ",
                 "Separador decimal: virgula.")
  if (is.null(extra)) base else paste0(base, " ", extra)
}

#' Grava a tabela em CSV (para o relatorio) preservando os numeros crus.
salvar_tab <- function(x, arquivo) {
  utils::write.csv(as.data.frame(x), file.path("output/tables", arquivo), row.names = FALSE)
  invisible(file.path("output/tables", arquivo))
}

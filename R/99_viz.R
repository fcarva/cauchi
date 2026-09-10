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
  s <- formatC(x, format = "f", digits = dig, big.mark = ".", decimal.mark = ",")
  s <- sub("^-", "−", s)            # sinal de menos tipografico, nao hifen
  ifelse(is.na(x), "--", s)
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
theme_feds <- function(base_size = 9) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      # Titulos de painel como nos FEDS: negrito, alinhados a esquerda, sem caixa.
      strip.text        = ggplot2::element_text(colour = COR$tinta, face = "bold",
                                                size = base_size, hjust = 0,
                                                margin = ggplot2::margin(b = 4)),
      strip.background  = ggplot2::element_blank(),
      panel.spacing     = ggplot2::unit(0.9, "lines"),
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
#' Formato dos FEDS: primeiro "Nota:" (o que ler na figura), depois "Fonte:".
nota_fonte <- function(extra = NULL, largura = 120) {
  snap <- if (exists("snapshot_dir")) basename(snapshot_dir()) else ""
  snap <- if (nzchar(snap)) sub("snapshot_", "snapshot de ", snap) else "snapshot congelado"
  fonte <- paste0("Fonte: Kalshi (", snap, "); cálculos do autor com o método de ",
                  "Diercks, Katz e Wright (2026).")
  linhas <- c(if (!is.null(extra)) paste0("Nota: ", extra), fonte)
  paste(vapply(linhas, function(l) paste(strwrap(l, width = largura), collapse = "\n"),
               character(1)), collapse = "\n")
}

#' Grava a figura no padrao do relatorio: PDF vetorial para o relatorio e PNG
#' para leitura no GitHub. O PDF sai pelo Cairo, que embute a fonte e acentua
#' corretamente; o dispositivo pdf() padrao do Windows troca acentos por '?'.
#'
#' LARGURA. 6,3 polegadas e a mancha de texto do relatorio (A4, margens padrao do
#' Quarto). A figura entra em escala 1:1, entao o corpo 9 do tema chega ao papel
#' em corpo 9 -- o mesmo tamanho das notas de rodape, como nos FEDS e IFDP.
#' Figuras gravadas maiores e reduzidas pelo LaTeX encolhem a tipografia junto.
LARGURA_TEXTO <- 6.3
salvar_fig <- function(p, arquivo, largura = LARGURA_TEXTO, altura = 3.3) {
  base <- file.path("output/figures", sub("\\.(png|pdf)$", "", arquivo))
  ggplot2::ggsave(paste0(base, ".pdf"), p, width = largura, height = altura,
                  device = grDevices::cairo_pdf, bg = "white")
  ggplot2::ggsave(paste0(base, ".png"), p, width = largura, height = altura,
                  dpi = 300, bg = "white")
  invisible(paste0(base, ".pdf"))
}

## ---- correlogramas -------------------------------------------------------------
#' FAC e FACP em formato longo, com a banda de 95% e a marca de significancia.
dados_fac <- function(x, lag_max, rotulo = "") {
  x <- x[is.finite(x)]
  banda <- stats::qnorm(0.975) / sqrt(length(x))
  a <- stats::acf(x,  lag.max = lag_max, plot = FALSE)
  p <- stats::pacf(x, lag.max = lag_max, plot = FALSE)
  df <- rbind(
    data.frame(painel = paste0("FAC", rotulo),  lag = as.numeric(a$lag)[-1],
               valor = as.numeric(a$acf)[-1]),
    data.frame(painel = paste0("FACP", rotulo), lag = as.numeric(p$lag),
               valor = as.numeric(p$acf))
  )
  df$painel <- factor(df$painel, levels = unique(df$painel))
  df$fora <- abs(df$valor) > banda
  attr(df, "banda") <- banda
  df
}

#' Correlograma no padrao do relatorio. Hastes finas; a banda de 95% e uma faixa
#' sombreada, nao duas linhas tracejadas (tracejado le como limiar ou projecao).
#' ENFASE: so as defasagens fora da banda levam cor -- o olho vai direto ao que
#' importa, e o resto recua para o cinza. Linhas verticais finas marcam os
#' multiplos do periodo sazonal, quando informado.
grafico_fac <- function(df, sazonal = NULL, ncol = 2) {
  banda <- attr(df, "banda")
  lag_max <- max(df$lag)
  g <- ggplot2::ggplot(df, ggplot2::aes(lag, valor))
  if (!is.null(sazonal)) {
    g <- g + ggplot2::geom_vline(xintercept = seq(sazonal, lag_max, by = sazonal),
                                 colour = COR$serie_2, linewidth = 0.25, alpha = 0.25)
  }
  g +
    ggplot2::annotate("rect", xmin = -Inf, xmax = Inf, ymin = -banda, ymax = banda,
                      fill = COR$banda, alpha = 0.10) +
    ggplot2::geom_hline(yintercept = 0, colour = COR$tinta, linewidth = 0.3) +
    ggplot2::geom_segment(ggplot2::aes(xend = lag, yend = 0, colour = fora),
                          linewidth = 0.55, lineend = "butt") +
    ggplot2::geom_point(ggplot2::aes(colour = fora), size = 0.9) +
    ggplot2::scale_colour_manual(values = c(`FALSE` = COR$tinta_fraca, `TRUE` = COR$serie_1),
                                 guide = "none") +
    ggplot2::scale_x_continuous(breaks = seq(0, lag_max, by = 7), expand = ggplot2::expansion(add = 0.8)) +
    ggplot2::scale_y_continuous(labels = escala_br(1)) +
    ggplot2::facet_wrap(~painel, ncol = ncol) +
    ggplot2::labs(x = "Defasagem (dias)", y = NULL) +
    theme_feds()
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

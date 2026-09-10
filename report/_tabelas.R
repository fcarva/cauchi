# report/_tabelas.R -----------------------------------------------------------
# Camada de APRESENTACAO das tabelas do relatorio.
#
# Os CSVs em output/tables/ guardam os numeros crus -- sao o que o pipeline
# reproduz e o que o professor confere. Aqui eles ganham a forma de tabela de
# periodico, no padrao dos FEDS e IFDP do Federal Reserve Board:
#   - tres filetes (topo, sob o cabecalho, base), nenhuma linha vertical;
#   - cabecalhos em portugues, agrupados quando compartilham unidade;
#   - virgula decimal, ponto de milhar e sinal de menos tipografico (U+2212);
#   - mesmo numero de casas por coluna, para os decimais se alinharem;
#   - erros-padrao entre parenteses sob o coeficiente, estrelas de significancia;
#   - paineis por grupo de linhas e notas abaixo da tabela.
# Nada e reestimado. A unica conta feita aqui sao as estatisticas descritivas da
# Tabela 1, tiradas diretamente da serie processada.
# -----------------------------------------------------------------------------
suppressPackageStartupMessages(library(tinytable))

DIR_TAB <- file.path("..", "output", "tables")
ler <- function(nome) {
  as.data.frame(readr::read_csv(file.path(DIR_TAB, nome), show_col_types = FALSE))
}

## ---- numeros -------------------------------------------------------------------
MENOS <- "\u2212"
TRACO <- "\u2014"

br <- function(x, d = 3) {
  s <- formatC(abs(x), format = "f", digits = d, big.mark = ".", decimal.mark = ",")
  zero <- formatC(0, format = "f", digits = d, decimal.mark = ",")
  s <- ifelse(!is.na(x) & x < 0 & s != zero, paste0(MENOS, s), s)
  ifelse(is.na(x), TRACO, s)
}
br_int <- function(x) ifelse(is.na(x), TRACO, formatC(round(x), format = "d", big.mark = ".", decimal.mark = ","))
br_p <- function(p, d = 3) {
  ifelse(is.na(p), TRACO, ifelse(p < 10^-d, paste0("< ", br(10^-d, d)), br(p, d)))
}
estrelas <- function(p) {
  ifelse(is.na(p), "", ifelse(p < 0.01, "***", ifelse(p < 0.05, "**",
         ifelse(p < 0.10, "*", ""))))
}
sim_nao <- function(x) ifelse(x, "Sim", "Não")
data_br <- function(d) format(as.Date(d), "%d/%m/%Y")

NOTA_EP <- paste0("Erros-padrão entre parênteses. *, ** e *** indicam significância ",
                  "a 10\\%, 5\\% e 1\\%, respectivamente.")

## ---- tabela de estimacao no formato dos periodicos --------------------------------
rotulo_param <- function(p) {
  tipo <- sub("[0-9]+$", "", p)
  k <- sub("^[a-z]+", "", p)
  simb <- c(ar = "\\phi", ma = "\\theta", sar = "\\Phi", sma = "\\Theta")[tipo]
  ifelse(is.na(simb), p, sprintf("$%s_{%s}$", simb, k))
}
ordenar_param <- function(p) {
  tipo <- sub("[0-9]+$", "", p)
  k <- suppressWarnings(as.integer(sub("^[a-z]+", "", p)))
  p[order(match(tipo, c("ar", "ma", "sar", "sma")), k)]
}

#' Um modelo por coluna. Bloco superior: coeficiente com estrelas e, na linha de
#' baixo, o erro-padrao entre parenteses. Bloco inferior, separado por filete:
#' estatisticas de ajuste. E o layout de AER, JPE e dos FEDS.
tabela_regressao <- function(coefs, ajuste, modelos = unique(coefs$modelo),
                             d = 3, notas = NULL) {
  params <- ordenar_param(unique(coefs$parametro))
  corpo <- do.call(rbind, lapply(params, function(pr) {
    lc <- rotulo_param(pr)
    le <- ""
    for (m in modelos) {
      r <- coefs[coefs$modelo == m & coefs$parametro == pr, ]
      lc <- c(lc, if (nrow(r)) paste0(br(r$estimativa, d), estrelas(r$p_valor)) else "")
      le <- c(le, if (nrow(r)) paste0("(", br(r$erro_padrao, d), ")") else "")
    }
    rbind(lc, le)
  }))
  tab <- rbind(corpo, as.matrix(ajuste[, c("rotulo", modelos)]))
  df <- as.data.frame(tab, stringsAsFactors = FALSE)
  rownames(df) <- NULL
  names(df) <- c(" ", modelos)
  tt(df, notes = notas) |>
    style_tt(j = 2:ncol(df), align = "c") |>
    style_tt(i = nrow(corpo), line = "b", line_width = 0.05)
}

#' Bloco de ajuste a partir das tabelas model_row() do pipeline.
linhas_ajuste <- function(est, modelos, col = "model", extras = list()) {
  e <- est[match(modelos, est[[col]]), ]
  vals <- rbind(br(1000 * e$sigma2, 3), br(e$loglik, 2), br(e$AIC, 2),
                br(e$BIC, 2), br_int(e$nobs))
  out <- data.frame(rotulo = c("$\\hat{\\sigma}^2_a \\times 10^{3}$", "Log-verossimilhança",
                               "AIC", "BIC", "Observações"),
                    vals, stringsAsFactors = FALSE)
  names(out) <- c("rotulo", modelos)
  for (nm in names(extras)) {
    linha <- as.data.frame(t(c(nm, extras[[nm]])), stringsAsFactors = FALSE)
    names(linha) <- c("rotulo", modelos)
    out <- rbind(out, linha)
  }
  out
}

## ---- Questao 1 -------------------------------------------------------------------
t_descritivas <- function() {
  s <- readr::read_csv(file.path("..", "data", "processed", "serie_diaria.csv"),
                       show_col_types = FALSE)
  est <- function(x) {
    m <- mean(x); dp <- stats::sd(x)
    c(n = length(x), media = m, dp = dp, min = min(x), med = stats::median(x),
      max = max(x), assim = mean((x - m)^3) / dp^3, curt = mean((x - m)^4) / dp^4)
  }
  a <- est(s$taxa_esperada)
  b <- est(100 * diff(s$taxa_esperada))
  f <- function(v, d) c(br_int(v["n"]), br(v[c("media", "dp", "min", "med", "max")], d),
                        br(v[c("assim", "curt")], 2))
  df <- data.frame(c("Nível (\\% a.a.)", "Primeira diferença (p.b.)"),
                   rbind(f(a, 3), f(b, 2)), stringsAsFactors = FALSE)
  names(df) <- c("Série", "N", "Média", "DP", "Mín.", "Mediana",
                 "Máx.", "Assim.", "Curt.")
  tt(df, notes = sprintf(paste0(
    "Contrato %s, observações diárias de %s a %s. DP: desvio-padrão; Assim.: assimetria; Curt.: curtose não centrada (normal = 3). ",
    "p.b.: pontos-base."), s$event_ticker[1], data_br(min(s$date)), data_br(max(s$date)))) |>
    style_tt(j = 2:9, align = "r")
}

t_atividade <- function() {
  a <- ler("q1_atividade_semanal.csv")
  nomes <- c(segunda = "Segunda-feira", terca = "Terça-feira", quarta = "Quarta-feira",
             quinta = "Quinta-feira", sexta = "Sexta-feira", sabado = "Sábado",
             domingo = "Domingo")
  df <- data.frame(unname(nomes[a$dia_da_semana]), br_int(a$negocios),
                   br(a$contratos / 1000, 1), br_int(a$dias_no_calendario),
                   br_int(a$dias_com_negocio), br(a$negocios_por_dia, 1),
                   stringsAsFactors = FALSE)
  names(df) <- c("Dia", "Negócios", "Contratos (mil)", "Dias na amostra",
                 "Dias com negócio", "Negócios por dia")
  tt(df, notes = paste0(
    "Negócios do contrato analisado dentro da janela da série. Negócios por dia: ",
    "total dividido pelos dias de calendário do mesmo tipo na amostra.")) |>
    style_tt(j = 2:6, align = "r") |>
    group_tt(i = list("Dias úteis" = 1, "Fim de semana" = 6))
}

## ---- Questao 2 -------------------------------------------------------------------
t_raiz <- function() {
  r <- ler("q2_testes_raiz_unitaria.csv")
  esp <- c(none = "Sem constante", drift = "Constante", trend = "Constante e tendência",
           constant = "Constante", mu = "Constante", tau = "Constante e tendência")
  rejeita <- function(st, cv, kpss) if (kpss) st > cv else st < cv
  sig <- mapply(function(st, c10, c5, c1, t) {
    k <- t == "KPSS"
    if (rejeita(st, c1, k)) "***" else if (rejeita(st, c5, k)) "**"
    else if (rejeita(st, c10, k)) "*" else ""
  }, r$statistic, r$critical_10, r$critical_5, r$critical_1, r$test)
  df <- data.frame(r$test, unname(esp[r$specification]), paste0(br(r$statistic, 3), sig),
                   br(r$critical_10, 2), br(r$critical_5, 2), br(r$critical_1, 2),
                   br_int(r$lags),
                   stringsAsFactors = FALSE)
  names(df) <- c("Teste", "Termos determinísticos", "Estatística", "10\\%", "5\\%",
                 "1\\%", "Defasagens")
  n1 <- sum(r$series == "nivel")
  tt(df, notes = paste0(
    "ADF e PP: H$_0$ de raiz unitária, rejeitada quando a estatística fica abaixo do ",
    "valor crítico. KPSS: H$_0$ de estacionariedade, rejeitada quando fica acima. ",
    "*, ** e *** indicam rejeição de H$_0$ a 10\\%, 5\\% e 1\\%. Defasagens: no ADF, ",
    "a escolhida pelo AIC, com máximo de 12; no PP e no KPSS, a janela curta de Bartlett.")) |>
    style_tt(j = 3:6, align = "r") |>
    group_tt(i = list("Nível" = 1, "Primeira diferença" = n1 + 1),
             j = list("Valores críticos" = 4:6))
}

t_sazonal <- function() {
  z <- ler("q2_sazonal.csv")
  valor <- ifelse(grepl("^nsdiffs", z$criterio), br_int(z$valor),
                  ifelse(grepl("^FAC", z$criterio), br(z$valor, 3), br(z$valor, 1)))
  crit <- c("OCSB: diferenças sazonais sugeridas",
            "Canova-Hansen: diferenças sazonais sugeridas",
            "FAC da primeira diferença, lag 7", "FAC da primeira diferença, lag 14",
            "FAC da primeira diferença, lag 21",
            "AIC($D = 0$) $-$ AIC($D = 1$)", "BIC($D = 0$) $-$ BIC($D = 1$)")
  concl <- sub("dentro da banda", "Dentro da banda", sub("fora da banda", "Fora da banda", z$conclusao))
  df <- data.frame(crit, valor, concl, stringsAsFactors = FALSE)
  names(df) <- c("Evidência", "Valor", "Indica")
  banda <- sub(".*: \\+/- ", "", z$referencia[grepl("banda", z$referencia)][1])
  tt(df, notes = sprintf(paste0(
    "Período sazonal $s = 7$. Banda de 95\\%% da FAC: $\\pm$%s. Nos critérios de ",
    "informação, valor negativo favorece $D = 0$."), br(as.numeric(banda), 3))) |>
    style_tt(j = 2, align = "r")
}

## ---- Questao 3 -------------------------------------------------------------------
#' Texto vindo do pipeline em notacao americana -> notacao brasileira: ponto
#' decimal entre digitos vira virgula, hifen antes de digito vira sinal de menos.
texto_br <- function(x) {
  x <- gsub("+/-", "±", x, fixed = TRUE)
  x <- gsub("(?<=\\d)\\.(?=\\d)", ",", x, perl = TRUE)
  gsub("(?<![A-Za-z0-9])-(?=\\d)", MENOS, x, perl = TRUE)
}

t_candidatos <- function() {
  c3 <- ler("q3_candidatos.csv")
  df <- data.frame(c3$model, c3$justificativa, texto_br(c3$evidencia),
                   stringsAsFactors = FALSE)
  names(df) <- c("Modelo", "Leitura", "Evidência na FAC/FACP")
  tt(df, width = c(0.16, 0.50, 0.34), notes = paste0(
    "Nenhum candidato tem componente sazonal ($P = D = Q = 0$, $s = 7$).")) |>
    format_tt(j = 2:3, escape = TRUE) |>
    style_tt(j = 1:3, align = "l")
}

t_lags <- function() {
  l <- ler("q3_lags_sazonais.csv")
  df <- data.frame(br_int(l$lag), ifelse(l$sazonal, "Sazonal", "Vizinha"),
                   br(l$FAC, 3), br(l$FACP, 3), stringsAsFactors = FALSE)
  names(df) <- c("Defasagem", "Tipo", "FAC", "FACP")
  x <- tt(df, notes = sprintf(paste0(
    "Primeira diferença da série. Banda de 95\\%%: $\\pm$%s. Em negrito, valores fora ",
    "da banda. Nenhuma defasagem sazonal (7, 14, 21) é significativa."), br(l$banda_95[1], 3))) |>
    style_tt(j = 3:4, align = "r")
  for (i in which(l$FAC_significativa))  x <- style_tt(x, i = i, j = 3, bold = TRUE)
  for (i in which(l$FACP_significativa)) x <- style_tt(x, i = i, j = 4, bold = TRUE)
  x
}

## ---- Questao 4 -------------------------------------------------------------------
t_estimacao <- function() {
  est <- ler("q4_estimacao_modelos.csv")
  sel <- ler("q4_selecao.csv")$modelo_selecionado[1]
  modelos <- est$model
  aj <- linhas_ajuste(est, modelos, extras = list(
    "Admissível (Q4f)" = sim_nao(est$admissivel),
    "Selecionado" = ifelse(modelos == sel, "Sim", "")))
  tabela_regressao(ler("q4_coeficientes.csv"), aj, modelos, notas = c(
    NOTA_EP,
    paste0("Estimação por máxima verossimilhança, mesma amostra efetiva em todos os ",
           "modelos. O AIC e o BIC contam a variância residual como parâmetro ",
           "($k = p + q + 1$), o que foi verificado no próprio objeto ajustado."),
    paste0("Admissível: todas as raízes AR e MA com módulo maior que 1 + 0,001. A ",
           "seleção aplica o AIC apenas entre os admissíveis.")))
}

#' Negrito escrito na propria celula. Nao usar style_tt(bold = TRUE) em tabela
#' com group_tt(i = ...): no tinytable 0.18 os indices de linha se deslocam pelo
#' numero de linhas de painel inseridas, e o destaque cai na linha errada.
negrito <- function(df, i, j = seq_along(df)) {
  for (jj in j) df[i, jj] <- sprintf("\\textbf{%s}", df[i, jj])
  df
}

t_raizes <- function() {
  r <- ler("q4_raizes.csv")
  r <- r[!is.na(r$modulo), ]
  df <- data.frame(r$tipo_raiz, br(r$parte_real, 3), br(r$parte_imaginaria, 3),
                   br(r$modulo, 6), sim_nao(r$admissivel), stringsAsFactors = FALSE)
  names(df) <- c("Polinômio", "Parte real", "Parte imaginária", "Módulo", "Admissível")
  df <- negrito(df, which(!r$admissivel))
  inicio <- which(!duplicated(r$modelo))
  tt(df, notes = paste0(
    "Raízes dos polinômios $\\phi(z)$ e $\\theta(z)$ (não as inversas). Condição de ",
    "estacionariedade e de invertibilidade: módulo maior que 1. Seis casas decimais ",
    "para tornar visível a distância das raízes MA do ARIMA(3,1,3) ao círculo unitário; ",
    "em negrito, as raízes inadmissíveis.")) |>
    style_tt(j = 2:4, align = "r") |>
    style_tt(j = 5, align = "c") |>
    group_tt(i = stats::setNames(as.list(inicio), r$modelo[inicio]))
}

t_selecao <- function() {
  s <- ler("q4_selecao.csv")
  df <- data.frame(c("AIC", "BIC"),
                   c(s$vencedor_aic_sem_restricao, s$vencedor_bic_sem_restricao),
                   c(s$vencedor_aic_admissivel, s$vencedor_bic_admissivel),
                   stringsAsFactors = FALSE)
  names(df) <- c("Critério", "Todos os candidatos", "Apenas admissíveis")
  tt(df, notes = sprintf(paste0(
    "%d candidatos, %d admissíveis. Sem a restrição, o AIC elegeria um modelo ",
    "não-invertível; entre os admissíveis, AIC e BIC %s. Modelo levado adiante: %s."),
    s$n_candidatos, s$n_admissiveis, if (s$criterios_divergem) "divergem" else "concordam",
    s$modelo_selecionado)) |>
    style_tt(j = 2:3, align = "c")
}

## ---- Questao 5 -------------------------------------------------------------------
t_diagnostico <- function() {
  d <- ler("q5_diagnostico.csv")
  h <- ler("q5_heterocedasticidade.csv")
  v <- function(txt) h$valor[match(txt, h$medida)]
  nomes <- c("Ljung-Box, 14 defasagens", "Jarque-Bera", "ARCH-LM, 7 defasagens")
  df <- data.frame(
    c(nomes, "Inclinação de $\\log(\\Delta y_t^2)$ nos dias até a reunião",
      "Razão de variâncias, 1.ª metade / 2.ª metade"),
    c(br(d$estatistica, 2), br(v("Estatistica t da inclinacao"), 2), br(v("Estatistica F"), 2)),
    c(paste0("$\\chi^2_{", d$graus_liberdade, "}$"), "$t$", "$F$"),
    c(br_p(d$p_valor), br_p(v("p-valor da inclinacao")), br_p(v("p-valor do teste F"))),
    stringsAsFactors = FALSE)
  names(df) <- c("Teste", "Estatística", "Distribuição", "p-valor")
  tt(df, notes = c(
    paste0("Ljung-Box com graus de liberdade corrigidos pelo número de coeficientes ",
           "estimados. Jarque-Bera: H$_0$ de normalidade. ARCH-LM: H$_0$ de ausência de ",
           "agrupamento de volatilidade."),
    sprintf(paste0("Inclinação estimada: %s (erro-padrão %s), em log-pontos por dia de ",
                   "horizonte; positiva significa dispersão maior longe da reunião. As ",
                   "diferenças nulas saem da regressão por causa do logaritmo."),
            br(v("Inclinacao de log(dif^2) sobre dias ate a reuniao"), 4),
            br(v("Erro-padrao da inclinacao"), 4)))) |>
    style_tt(j = c(2, 4), align = "r") |>
    style_tt(j = 3, align = "c") |>
    group_tt(i = list("Resíduos do modelo selecionado" = 1,
                      "Variância determinística no horizonte" = 4))
}

t_sobreajuste <- function() {
  co <- ler("q5_sobreajuste_coeficientes.csv")
  modelos <- unique(co$modelo)
  est <- rbind(ler("q4_estimacao_modelos.csv")[, c("model", "sigma2", "loglik", "AIC", "BIC", "nobs")],
               ler("q5_sobreacte.csv")[, c("model", "sigma2", "loglik", "AIC", "BIC", "nobs")])
  est <- est[!duplicated(est$model), ]
  tabela_regressao(co, linhas_ajuste(est, modelos), modelos, notas = c(
    NOTA_EP,
    paste0("Sobreajuste deliberado: um termo AR e um termo MA a mais que o modelo ",
           "selecionado (primeira coluna). Nenhum dos termos adicionais é significativo e ",
           "nenhum dos dois modelos reduz o AIC.")))
}

t_descartados <- function() {
  d <- ler("modelos_descartados.csv")
  ev <- gsub("(?<=\\d)\\.(?=\\d)", ",", d$evidencia, perl = TRUE)
  ev <- gsub("-(?=\\d)", MENOS, ev, perl = TRUE)
  df <- data.frame(d$modelo, d$questao, d$motivo, ev, stringsAsFactors = FALSE)
  names(df) <- c("Modelo", "Etapa", "Motivo", "Evidência")
  df$Motivo <- sub("^(.)", "\\U\\1", df$Motivo, perl = TRUE)
  tt(df, width = c(0.15, 0.09, 0.30, 0.46)) |>
    format_tt(j = 3:4, escape = TRUE) |>
    style_tt(j = 1:4, align = "l")
}

## ---- Questao 6 -------------------------------------------------------------------
t_sobrediferenciacao <- function() {
  co <- ler("q6_coeficientes.csv")
  cmp <- ler("q6_comparacao.csv")
  raiz <- ler("q6_ma_raiz.csv")
  rot <- c(selecionado = "Selecionado", sobrediferenciado = "Sobrediferenciado")
  co$modelo <- rot[co$modelo]
  cmp$model <- rot[cmp$model]
  modelos <- unname(rot)
  mod_raiz <- as.numeric(strsplit(as.character(raiz$raiz_modulo), ";")[[1]][1])
  mod_sel <- ler("q4_raizes.csv")
  sel <- ler("q4_selecao.csv")$modelo_selecionado[1]
  m1 <- min(mod_sel$modulo[mod_sel$modelo == sel & mod_sel$tipo_raiz == "MA"])
  aj <- linhas_ajuste(cmp, modelos, extras = list(
    "Módulo da raiz MA" = c(br(m1, 4), br(1 / mod_raiz, 6))))
  tabela_regressao(co, aj, modelos, notas = c(
    NOTA_EP,
    paste0("O sobrediferenciado aumenta $d$ em uma unidade e mantém $p$ e $q$. Seu ",
           "$\\hat\\theta_1$ encosta em $-1$ e a raiz MA cai sobre o círculo unitário: é a ",
           "assinatura da sobrediferenciação. AIC e BIC não são comparáveis entre as ",
           "colunas, porque a variável dependente difere ($\\Delta y$ contra ",
           "$\\Delta^2 y$) e a amostra efetiva perde uma observação.")))
}

## ---- Questao 7 -------------------------------------------------------------------
t_metricas <- function() {
  m <- ler("q7_metricas_previsao.csv")
  nomes <- c(ARIMA = ler("q4_selecao.csv")$modelo_selecionado[1],
             passeio_aleatorio = "Passeio aleatório", sazonal_ingenuo = "Sazonal ingênuo ($s = 7$)")
  df <- data.frame(unname(nomes[m$model]), br(100 * m$RMSE, 2), br(100 * m$MAE, 2),
                   br(m$MAPE, 3), stringsAsFactors = FALSE)
  names(df) <- c("Modelo", "REQM (p.b.)", "EAM (p.b.)", "EAPM (\\%)")
  for (esq in unique(m$scheme)) {
    idx <- which(m$scheme == esq)
    for (j in 2:4) {
      col <- c("RMSE", "MAE", "MAPE")[j - 1]
      df <- negrito(df, idx[which.min(m[[col]][idx])], j)
    }
  }
  x <- tt(df, notes = paste0(
    "Janela de validação: últimas 24 observações. Em negrito, o menor erro de cada ",
    "esquema. REQM: raiz do erro quadrático médio; EAM: erro absoluto médio; EAPM: ",
    "erro absoluto percentual médio. Esquema 2 mantém fixos os coeficientes estimados ",
    "até a origem.")) |>
    style_tt(j = 2:4, align = "r")
  inicio <- which(!duplicated(m$scheme))
  rot <- c(origem_fixa_24_passos = "Esquema 1: origem fixa, 1 a 24 passos",
           origem_movel_1_passo = "Esquema 2: origem móvel, 1 passo")
  group_tt(x, i = stats::setNames(as.list(inicio), rot[m$scheme[inicio]]))
}

t_dm <- function() {
  dm <- ler("q7_diebold_mariano.csv")
  dm <- dm[dm$esquema == "origem_movel_1_passo", ]
  vs <- ifelse(grepl("passeio", dm$comparacao), "Passeio aleatório", "Sazonal ingênuo ($s = 7$)")
  df <- data.frame(vs, br(dm$DM_quadratico, 3), br_p(dm$p_quadratico),
                   br(dm$DM_absoluto, 3), br_p(dm$p_absoluto), stringsAsFactors = FALSE)
  names(df) <- c("Contra", "DM", "p-valor", "DM ", "p-valor ")
  tt(df, notes = paste0(
    "Esquema 2 (um passo, origem móvel). Estatística de Diebold e Mariano com a correção ",
    "de Harvey, Leybourne e Newbold e referência $t_{n-1}$. H$_0$: acurácia igual. Valor ",
    "negativo favorece o ARIMA. O Esquema 1 não recebe o teste: tem uma única origem, e ",
    "com $h = n = 24$ a correção se anula.")) |>
    style_tt(j = 2:5, align = "r") |>
    group_tt(j = list("Perda quadrática" = 2:3, "Perda absoluta" = 4:5))
}

t_cobertura <- function() {
  c7 <- ler("q7_cobertura.csv")
  df <- data.frame(
    c("Cobertura empírica do intervalo de 95\\%", "KS da PIT, Esquema 1", "KS da PIT, Esquema 2"),
    c(paste0(br(100 * c7$cobertura_intervalo_95, 1), "\\%"), br(c7$ks_esquema1, 3), br(c7$ks_esquema2, 3)),
    c(TRACO, br_p(c7$p_ks_esquema1), br_p(c7$p_ks_esquema2)),
    stringsAsFactors = FALSE)
  names(df) <- c("Medida", "Valor", "p-valor")
  tt(df, notes = paste0(
    "KS: Kolmogorov-Smirnov das PIT contra a uniforme; rejeitar indica densidade ",
    "preditiva mal calibrada (Diebold, Gunther e Tay, 1998).")) |>
    style_tt(j = 2:3, align = "r")
}

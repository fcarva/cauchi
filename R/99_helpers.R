# Funcoes compartilhadas do relatorio Box-Jenkins.

OUT_FIG <- "output/figures"
OUT_TAB <- "output/tables"
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_TAB, recursive = TRUE, showWarnings = FALSE)

read_series <- function() {
  x <- readr::read_csv("data/processed/serie_diaria.csv", show_col_types = FALSE)
  x$date <- as.Date(x$date)
  x
}

# Resolve o snapshot congelado com a MESMA regra do 01_build_series.R: variavel de
# ambiente KALSHI_SNAPSHOT, senao o diretorio datado mais recente em data/raw.
# Devolve "" quando nao ha nenhum, para que o chamador decida se isso e fatal.
snapshot_dir <- function() {
  d <- Sys.getenv("KALSHI_SNAPSHOT", "")
  if (nzchar(d)) return(d)
  cand <- list.dirs("data/raw", full.names = TRUE, recursive = FALSE)
  cand <- cand[grepl("snapshot_[0-9]{4}-[0-9]{2}-[0-9]{2}$", cand)]
  if (length(cand)) sort(cand, decreasing = TRUE)[1] else ""
}

# Rotulos de dia da semana sem depender do locale: format(%u) devolve 1=segunda.
DIAS_SEMANA <- c("segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo")
dia_da_semana <- function(d) factor(DIAS_SEMANA[as.integer(format(as.Date(d), "%u"))],
                                    levels = DIAS_SEMANA)

write_table <- function(x, name) {
  readr::write_csv(as.data.frame(x), file.path(OUT_TAB, name))
}

save_gg <- function(plot, name, width = 8, height = 5) {
  ggplot2::ggsave(file.path(OUT_FIG, name), plot, width = width, height = height, dpi = 160)
}

# Valores criticos PELO NOME da coluna. O urca nao usa a mesma ordem em todos os
# testes -- ur.df e ur.pp devolvem (1pct, 5pct, 10pct); ur.kpss devolve (10pct,
# 5pct, 2.5pct, 1pct). A versao anterior lia por posicao: a coluna critical_10
# guardava o valor de 1% no ADF/PP, e a critical_1 do KPSS era o de 2,5%.
cv_por_nome <- function(fit) as.numeric(fit@cval[1, c("10pct", "5pct", "1pct")])

# p-valor aproximado por interpolacao entre os valores criticos de 10%, 5% e 1%,
# censurado em [0,01; 0,10]. 'cauda' importa: ADF e PP rejeitam a raiz unitaria
# quando a estatistica fica ABAIXO do critico; o KPSS rejeita a estacionariedade
# quando fica ACIMA. A versao anterior tratava os tres como cauda esquerda, o que
# invertia o KPSS: um nivel que rejeitava com folga saia com p = 0,10.
critical_p <- function(stat, cv, cauda = c("esquerda", "direita")) {
  cauda <- match.arg(cauda)
  if (!is.finite(stat)) return(NA_real_)
  s <- if (cauda == "esquerda") -stat else stat
  c <- if (cauda == "esquerda") -cv else cv          # agora: rejeita se s > c
  if (s >= c[3]) return(0.01)
  if (s <= c[1]) return(0.10)
  stats::approx(x = c, y = c(0.10, 0.05, 0.01), xout = s)$y
}

run_unit_root_tests <- function(x, label, max_lag = 12) {
  rows <- list()
  linha <- function(test, spec, stat, cv, cauda, lags, criterio) {
    data.frame(series = label, test = test, specification = spec, statistic = stat,
               critical_10 = cv[1], critical_5 = cv[2], critical_1 = cv[3],
               p_value_approx = critical_p(stat, cv, cauda), lags = lags,
               lag_selection = criterio, stringsAsFactors = FALSE)
  }
  for (type in c("none", "drift", "trend")) {
    fit <- urca::ur.df(x, type = type, lags = max_lag, selectlags = "AIC")
    # Q2(a): a defasagem ESCOLHIDA pelo AIC e o numero de termos z.diff.lag que
    # sobraram na regressao de teste -- nao o maximo permitido.
    escolhida <- sum(grepl("^z\\.diff\\.lag", rownames(fit@testreg$coefficients)))
    rows[[length(rows) + 1]] <- linha("ADF", type, as.numeric(fit@teststat[1]),
                                      cv_por_nome(fit), "esquerda", escolhida,
                                      sprintf("AIC (max. %d)", max_lag))
  }
  for (model in c("constant", "trend")) {
    fit <- urca::ur.pp(x, type = "Z-tau", model = model, lags = "short")
    rows[[length(rows) + 1]] <- linha("PP", model, as.numeric(fit@teststat[1]),
                                      cv_por_nome(fit), "esquerda", fit@lag,
                                      "Bartlett curta")
  }
  for (type in c("mu", "tau")) {
    fit <- urca::ur.kpss(x, type = type, lags = "short")
    rows[[length(rows) + 1]] <- linha("KPSS", type, as.numeric(fit@teststat),
                                      cv_por_nome(fit), "direita", fit@lag,
                                      "Bartlett curta")
  }
  do.call(rbind, rows)
}

PERIODO_SAZONAL <- 7L   # calendario de negociacao da Kalshi: 24/7 (ver q1_atividade_semanal.csv)

fit_candidate <- function(x, order, seasonal = c(0, 0, 0), period = PERIODO_SAZONAL) {
  forecast::Arima(x, order = order, seasonal = list(order = seasonal, period = period),
                  method = "ML", include.drift = FALSE)
}

# Tolerancia da restricao de admissibilidade (Q4f). Uma raiz de modulo 1,000034 esta
# NUMERICAMENTE sobre o circulo unitario: o otimizador parou na fronteira, nao dentro
# da regiao admissivel. Testar |raiz| > 1 puro deixaria esse caso passar por 3,4e-05.
TOL_RAIZ <- 1e-3

# Raizes dos polinomios AR e MA de um ajuste do forecast::Arima.
#
# CONVENCAO. Para phi(B) = 1 - phi_1 B - ... e theta(B) = 1 + theta_1 B + ...,
# 'polyroot' devolve as raizes de verdade, e a condicao de estacionariedade /
# invertibilidade e |raiz| > 1. A versao antiga deste bloco gravava 1/polyroot(...)
# -- as raizes INVERSAS, para as quais a condicao se inverte para |.| < 1 -- sob uma
# coluna chamada 'outside_unit_circle = Mod > 1'. O resultado saia FALSE em todas as
# linhas, ou seja, o CSV afirmava que nenhum modelo satisfazia a Q4(f).
raizes_modelo <- function(fit, nome) {
  co <- stats::coef(fit)
  ar_co <- co[grep("^ar", names(co))]
  ma_co <- co[grep("^ma", names(co))]
  raizes <- c(if (length(ar_co)) polyroot(c(1, -ar_co)) else complex(0),
              if (length(ma_co)) polyroot(c(1,  ma_co)) else complex(0))
  tipos <- c(rep("AR", length(ar_co)), rep("MA", length(ma_co)))
  if (!length(raizes)) {
    return(data.frame(modelo = nome, tipo_raiz = NA_character_,
                      parte_real = NA_real_, parte_imaginaria = NA_real_,
                      modulo = NA_real_, modulo_inverso = NA_real_,
                      admissivel = TRUE, stringsAsFactors = FALSE))
  }
  modulo <- Mod(raizes)
  data.frame(
    modelo = nome, tipo_raiz = tipos,
    parte_real = Re(raizes), parte_imaginaria = Im(raizes),
    modulo = modulo, modulo_inverso = 1 / modulo,
    admissivel = modulo > 1 + TOL_RAIZ,
    stringsAsFactors = FALSE
  )
}

# Q5(d): log acumulado de modelos descartados. Cada script acrescenta suas linhas;
# 'reiniciar = TRUE' zera o arquivo no inicio da cadeia (05_estimacao.R).
registrar_descarte <- function(modelo, etapa, motivo, evidencia, questao,
                               reiniciar = FALSE) {
  caminho <- file.path(OUT_TAB, "modelos_descartados.csv")
  novo <- data.frame(modelo = modelo, etapa = etapa, motivo = motivo,
                     evidencia = evidencia, questao = questao,
                     stringsAsFactors = FALSE)
  if (!reiniciar && file.exists(caminho)) {
    antigo <- readr::read_csv(caminho, show_col_types = FALSE)
    novo <- rbind(as.data.frame(antigo), novo)
  }
  readr::write_csv(novo, caminho)
  invisible(novo)
}

model_row <- function(fit, name) {
  cf <- stats::coef(fit)
  se <- sqrt(diag(fit$var.coef))
  data.frame(
    model = name,
    coefficients = paste(names(cf), round(cf, 6), collapse = "; "),
    standard_errors = paste(names(se), round(se, 6), collapse = "; "),
    t_statistics = paste(names(cf), round(cf / se, 3), collapse = "; "),
    sigma2 = unname(fit$sigma2), loglik = as.numeric(logLik(fit)),
    AIC = AIC(fit), BIC = BIC(fit), nobs = stats::nobs(fit),
    stringsAsFactors = FALSE
  )
}

# Coeficientes em formato longo (uma linha por parametro). E a materia-prima das
# tabelas de estimacao do relatorio; model_row() continua existindo para os CSVs
# legados, mas guarda os coeficientes como texto e nao serve para diagramar.
coef_long <- function(fit, nome) {
  cf <- stats::coef(fit)
  se <- sqrt(diag(fit$var.coef))[names(cf)]
  t  <- cf / se
  data.frame(modelo = nome, parametro = names(cf), estimativa = unname(cf),
             erro_padrao = unname(se), estatistica_t = unname(t),
             p_valor = 2 * stats::pnorm(-abs(unname(t))), stringsAsFactors = FALSE)
}

metric_row <- function(actual, predicted, model, scheme) {
  err <- actual - predicted
  data.frame(
    scheme = scheme, model = model,
    RMSE = sqrt(mean(err^2, na.rm = TRUE)),
    MAE = mean(abs(err), na.rm = TRUE),
    MAPE = mean(abs(err / actual), na.rm = TRUE) * 100,
    stringsAsFactors = FALSE
  )
}

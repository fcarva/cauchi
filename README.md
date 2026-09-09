# kalshi-fed-arima

Modelagem Box-Jenkins (ARIMA) de uma serie diaria de **mercado de previsao da Kalshi**
na categoria **Economics** (decisao de juros do Fed / FOMC), como avaliacao parcial de
**Econometria II — PPGEco/UFES** (Lista 01). O enquadramento e um **teste de eficiencia
fraca**: sob eficiencia, a expectativa implicita de mercado e um martingale, logo a serie
deve ser I(1) com variacao ~ ruido branco, e nenhum ARIMA deve bater o *random walk* fora
da amostra. Alinhado a Diercks, Katz & Wright (2026), *Kalshi and the Rise of Macro
Markets* (referencia: `jdkatz21/Prediction_Markets_Public`).

## A serie
- **Fonte:** API publica da Kalshi (`api.elections.kalshi.com/trade-api/v2`), candlesticks
  diarios (`period_interval=1440`). Dados de mercado sao **publicos, sem credenciais**
  (series, events e candlesticks sao leitura anonima; chave de API so serve para ordens).
- **Frequencia:** diaria (a Kalshi existe desde 2021; mensal nao atinge as 120 obs minimas).
- **Snapshot congelado em:** _AAAA-MM-DD_ (preencher).

### Qual serie do Fed? (decisao em aberto — Bloco 1 do `00`)
A Kalshi tem **duas** familias do Fed, e a escolha determina que serie da pra construir:

| `series_ticker` | Pergunta do mercado | Desfechos | Serve para |
|---|---|---|---|
| `KXFED` | "Fed funds rate after \<mes\> meeting?" | **faixas de taxa** (buckets) | `E[taxa] = sum(p_i * taxa_i)` — serie continua, direta |
| `KXFEDDECISION` | "Fed decision in \<mes\>?" | **categorias** (corte/manutencao/alta) | `P(desfecho)`, ou taxa esperada via mapeamento categoria -> bps |

O scaffold vem com `KXFEDDECISION`. Se a serie-alvo for a **taxa esperada implicita**,
`KXFED` tende a ser o caminho mais curto, porque o desfecho ja e numerico. Confirme os
tickers reais rodando a descoberta antes de decidir — a Kalshi renomeia familias.

## Estrutura
```
R/00_pull_kalshi.R       coleta da API -> data/raw/ (rode UMA vez; congela o banco)
R/01_build_series.R      painel bruto -> data/processed/serie_diaria.csv
R/02..08_*.R             Questoes 1 a 7, na ordem de execucao
run_all.R                reproduz 01..08 sobre o banco congelado
data/raw/                o "banco" entregue (snapshot da Kalshi) — VERSIONADO
data/processed/          serie derivada usada na analise
output/figures, tables/  graficos e tabelas do relatorio
report/relatorio.qmd     relatorio em PDF (graficos/tabelas integrados)
```

## Coleta (rodar uma unica vez)
```bash
Rscript R/00_pull_kalshi.R --discover   # lista os series_ticker reais; nao grava nada
# ajuste SERIES_TICKER no topo de R/00_pull_kalshi.R, depois:
Rscript R/00_pull_kalshi.R              # grava data/raw/kalshi_fed_panel.csv
```
O script **se recusa a sobrescrever** um snapshot existente (`FORCE_REPULL <- TRUE`
destrava de proposito). Ao final ele imprime linhas/reunioes/dias e os rotulos exatos
dos desfechos — esses rotulos sao o que o `01_build_series.R` precisa para montar a serie.

Nao e preciso credencial nenhuma. Se voce tiver uma chave de API da Kalshi, ela **nao**
entra neste repo (ver `.gitignore`): serve para ordens/carteira, nao para dados.

## Reprodutibilidade
O criterio do professor e objetivo: rodar o codigo sobre o banco entregue tem de devolver
exatamente os mesmos numeros e graficos. Por isso:

1. **Os dados sao congelados.** `R/00_pull_kalshi.R` puxa da API (dado VIVO) e salva o
   snapshot em `data/raw/`, que e **versionado no git**. A analise (`run_all.R`) **le o
   snapshot congelado e nunca re-puxa** — `run_all.R` nao chama o `00`.
2. **Versoes travadas com `renv`:**
   ```r
   install.packages("renv"); renv::init(); renv::snapshot()   # gera renv.lock
   ```
   Para reproduzir noutra maquina: `renv::restore()`.
3. **Rodar tudo:**
   ```r
   renv::restore()
   source("run_all.R")     # regenera serie, figuras, tabelas e sessionInfo.txt
   ```
- **R:** _versao_ (preencher).  **Pacotes:** `renv.lock` + `sessionInfo.txt`.

## Mapa arquivo -> questao
| Questao | Arquivo |
|--------:|---------|
| 1 | `R/02_inspecao.R` |
| 2 | `R/03_integracao.R` |
| 3 | `R/04_identificacao.R` |
| 4 | `R/05_estimacao.R` |
| 5 | `R/06_diagnostico.R` |
| 6 | `R/07_sobrediferenciacao.R` |
| 7 | `R/08_previsao.R` |
| 8 | manuscrita (a parte) |

## Estado atual
Scaffold + coletor prontos. Falta, nesta ordem:
1. rodar `--discover` e fixar o `series_ticker` (ver tabela acima);
2. rodar o `00` uma vez, conferir o resumo impresso e **commitar** o snapshot;
3. `renv::init()` + commitar `renv.lock`;
4. escrever o `01_build_series.R` sobre os rotulos de desfecho reais;
5. Questoes 1-7 (`02`..`08`), so entao.

Os `_(preencher)_` do README (data do snapshot, versao do R) fecham no passo 2 e 3.

## Licenca
MIT (ver `LICENSE`). Sugestao: manter o repo **privado** ate a entrega/correcao (o professor
pediu para comunicar a serie e evitar duplicacao entre alunos); abrir depois.

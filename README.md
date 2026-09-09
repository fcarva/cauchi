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

### Qual serie do Fed? (resolvido)
A Kalshi tem **duas** familias do Fed, e elas nao sao intercambiaveis:

| `series_ticker` | Ticker do mercado | O preco significa |
|---|---|---|
| **`KXFED`** (ex-`FED`) — *usada aqui* | `FED-22DEC-T4.25` | `P(taxa acima de 4.25)` |
| `KXFEDDECISION` | `KXFEDDECISION-28JAN-H26` | `P(categoria)` (corte/manutencao/alta) |

Usamos a familia de **nivel**, que e a mesma de Diercks-Katz-Wright (o conjunto
`fed_levels` em `code/kalshi_scraping/tickers.py` do replication package). O
strike ja e numerico, entao a taxa esperada sai da distribuicao sem precisar de
um mapa arbitrario categoria -> pontos-base.

**Atencao:** o `yes_price` desses contratos e a probabilidade da **cauda**
(`P(taxa > strike)`), nao a de um balde. Os strikes formam uma funcao de
sobrevivencia, e a massa de cada balde sai por **diferenciacao**. Tratar cada
desfecho como balde independente gera uma serie errada sem levantar erro
nenhum. Ver `docs/metodologia.md`.

## Estrutura
```
R/00_pull_kalshi.R       coleta da API -> data/raw/ (rode UMA vez; congela o banco)
R/fun_distribuicao.R     nucleo matematico (base R puro, testavel isolado)
R/01_build_series.R      painel bruto -> data/processed/serie_diaria.csv
R/02..08_*.R             Questoes 1 a 7, na ordem de execucao
run_all.R                reproduz 01..08 sobre o banco congelado
data/raw/                o "banco" entregue (snapshot da Kalshi) — VERSIONADO
data/processed/          serie derivada usada na analise
output/figures, tables/  graficos e tabelas do relatorio
report/relatorio.qmd     relatorio em PDF (graficos/tabelas integrados)
docs/metodologia.md      cada decisao rastreada ate o codigo do paper
tests/                   validacao do pipeline contra resposta conhecida
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

## Validacao do pipeline
O nucleo matematico (`R/fun_distribuicao.R`) e **base R puro** e e testado
contra uma distribuicao de resposta conhecida — sem depender da API:

```bash
Rscript tests/test_distribuicao.R      # nenhum pacote necessario
```

O teste constroi uma distribuicao cuja media e conhecida, gera dela os precos
que a Kalshi publicaria (a funcao de sobrevivencia, em cents) e verifica se o
pipeline recupera a media original. Resultado (R 4.3.3):

| Verificacao | Resultado |
|---|---|
| Recuperacao da media (4 cenarios) | erro maximo **1,42 bps** |
| Ajuste de meio-balde | vale exatamente **12,50 bps** |
| Metodo ingenuo (sem diferenciar) | erro de ate **44,1 bps**, e **troca de sinal** |
| Nao-arbitragem (middle-out) | sobrevivencia volta a ser nao-crescente |
| Caminho diario com ruido (180 dias) | REQM **0,54 bps**, correlacao **0,992** |

O erro do metodo ingenuo nao e um vies constante: varia com o formato da
distribuicao e com o tamanho da escada de strikes, e chega a inverter de sinal.
Nao da para corrigir a posteriori — tem de diferenciar a sobrevivencia.

### Ponta a ponta, sem a API
```bash
Rscript tests/gera_painel_sintetico.R                                  # fixture
KALSHI_PANEL=tests/fixtures/painel_sintetico.csv Rscript R/01_build_series.R
```
O `01` aceita `KALSHI_PANEL`, `KALSHI_SERIE` e `KALSHI_MODO` por variavel de
ambiente, so para permitir esse teste; os defaults apontam para o snapshot real.

**`tests/fixtures/` nao e dado real.** O snapshot entregue tem de vir da API.

### Por que o default e `contrato_unico`
Medido sobre o painel sintetico (`Rscript tests/demo_roll.R`): na serie
encadeada, o salto medio nos dias de roll e **22,96 bps** contra um
desvio-padrao de **1,48 bps** nos dias normais — **15,6x**. Esse salto nao e
noticia economica, e troca de alvo; entraria na Questao 2 como falsa quebra
estrutural. O contrato unico entrega 180 obs de um alvo so.

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
Scaffold, coletor e construcao da serie prontos. Falta:
1. rodar `--discover` e confirmar que os tickers do `KXFED` tem sufixo `-T<numero>`;
2. rodar o `00` uma vez, conferir o resumo impresso e **commitar** o snapshot;
3. rodar o `01` e validar (ele falha alto se a diferenciacao sair errada);
4. `renv::init()` + commitar `renv.lock`;
5. Questoes 1-7 (`02`..`08`).

O `01_build_series.R` foi escrito a partir da metodologia publicada do paper,
mas **nao foi executado** contra dados reais (a sessao que o escreveu nao tinha
R nem acesso a rede). As checagens internas falham alto de proposito.

Os `_(preencher)_` do README (data do snapshot, versao do R) fecham nos passos 2 e 4.

## Licenca
MIT (ver `LICENSE`). Sugestao: manter o repo **privado** ate a entrega/correcao (o professor
pediu para comunicar a serie e evitar duplicacao entre alunos); abrir depois.

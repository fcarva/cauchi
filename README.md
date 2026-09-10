# kalshi-fed-arima

Modelagem Box-Jenkins (ARIMA) de uma serie diaria de **mercado de previsao da Kalshi**
(taxa esperada implicita da FFR), como avaliacao parcial de **Econometria II —
PPGEco/UFES** (Lista 01).

**Dois artigos, papeis distintos:**

| Artigo | Papel |
|---|---|
| **Kagan & Baiocchi (2026)**, *Calibration in Prediction Markets* | **A hipotese.** Precos da Kalshi se comportam como probabilidades genuinas, e cada vez mais perto da resolucao. Em *Economics*, Brier cai quase linearmente de 0,108 (3 meses) para 0,066 (fechamento). |
| **Diercks, Katz & Wright (2026)**, *Kalshi and the Rise of Macro Markets* | **O metodo.** Como transformar contratos brutos em distribuicao implicita e momentos. E o codigo que o `01_build_series.R` transcreve. |

A justificativa de Kagan & Baiocchi e a Lei dos Grandes Numeros, logo o teste deles e
**transversal** — junta 2,24 milhoes de mercados. Por construcao, nao diz nada sobre a
**trajetoria** de um mercado individual. E ai que este trabalho entra: se o preco e uma
probabilidade bem calibrada que se atualiza com informacao, entao pela lei das
expectativas iteradas ele e um **martingale**. A serie deve ser I(1), suas diferencas
ruido branco, e nenhum ARIMA deve superar o passeio aleatorio fora da amostra.

Ver **`docs/alinhamento.md`** para o mapeamento item-a-item da lista e tres previsoes
concretas sobre os diagnosticos.

## A serie
- **Fonte:** API publica da Kalshi (`api.elections.kalshi.com/trade-api/v2`), candlesticks
  diarios (`period_interval=1440`). Dados de mercado sao **publicos, sem credenciais**
  (series, events e candlesticks sao leitura anonima; chave de API so serve para ordens).
- **Frequencia:** diaria (a Kalshi existe desde 2021; mensal nao atinge as 120 obs minimas).
- **Snapshot congelado em:** _AAAA-MM-DD_ (preencher).

### Desvio declarado: frequencia
A lista pede **"preferencialmente mensal ou trimestral"**. Esta serie e **diaria**, por
tres razoes que vao declaradas no relatorio:

- a Kalshi opera desde 2021 e seus mercados de FFR desde 2022 — uma serie mensal nao
  alcanca as **120 observacoes minimas** exigidas;
- o fenomeno de interesse (atualizacao da expectativa com a chegada de informacao) e
  intrinsecamente de alta frequencia; agregar para mensal o destruiria;
- o minimo de 120 observacoes e cumprido com folga: ~180 obs de um unico contrato.

A serie **nao** esta disponivel em pacote de R ou Python, como a lista exige.

Os itens sazonais da lista (Q2c, Q3a, Q3b, Q7e-ii) **nao** sao respondidos com "nao se
aplica" — isso e ponto perdido. Testa-se **efeito dia-da-semana (s = 5)** e conclui-se
`D = 0` com evidencia. Ver `docs/alinhamento.md`.

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
R/99_helpers.R           funcoes compartilhadas das questoes
scripts/pull_kalshi_trades.py  coleta trades autenticados -> data/raw/
R/01_build_series.R      painel bruto -> data/processed/serie_diaria.csv
R/02..08_*.R             Questoes 1 a 7, na ordem de execucao
run_all.R                reproduz 01..08 sobre o banco congelado
data/raw/                o "banco" entregue (snapshot da Kalshi) — VERSIONADO
data/processed/          serie derivada usada na analise
output/figures, tables/  graficos e tabelas do relatorio
report/relatorio.qmd     relatorio em PDF, estruturado nos itens reais da lista
report/referencias.bib   bibliografia
docs/metodologia.md      cada decisao rastreada ate o codigo do paper
docs/alinhamento.md      mapeamento item-a-item da Lista 01 + previsoes
tests/                   validacao do pipeline contra resposta conhecida
```

## Coleta (rodar uma unica vez)
```bash
Rscript R/00_pull_kalshi.R --discover   # lista os series_ticker reais; nao grava nada
# ajuste SERIES_TICKER no topo de R/00_pull_kalshi.R, depois:
Rscript R/00_pull_kalshi.R --refresh    # grava/atualiza data/raw/kalshi_fed_panel.csv
python scripts/pull_kalshi_trades.py    # trades historicos e recentes (autenticado)
```
O script **se recusa a sobrescrever** um snapshot existente; `--refresh` destrava a
atualizacao de proposito. Ao final ele imprime linhas/reunioes/dias e os rotulos exatos
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
| Questao | Arquivo | Itens |
|--------:|---------|-------|
| 1 | `R/02_inspecao.R` | (a) — a lista tem so este item |
| 2 | `R/03_integracao.R` | (a) ADF/PP/KPSS · (b) constante e tendencia · (c) `d` e `D` · (d) estocastica vs deterministica |
| 3 | `R/04_identificacao.R` | (a) FAC/FACP · (b) leitura · (c) tres candidatos |
| 4 | `R/05_estimacao.R` | (a) tabela unica · (b) amostra efetiva · (c) validade AIC/BIC · (d) convencao de `k` · (e) divergencia · (f) raizes |
| 5 | `R/06_diagnostico.R` | (a) residuos · (b) Ljung-Box g.l. corrigidos · (c) JB e ARCH-LM · (d) modelos descartados · (e) sobreajuste deliberado |
| 6 | `R/07_sobrediferenciacao.R` | (a) theta e raiz MA · (b) sigma^2 · (c) FAC · (d) sinais praticos |
| 7 | `R/08_previsao.R` | (a) H=24 · (b) origem fixa · (c) origem movel sem reestimar · (d) RMSE/MAE/MAPE · (e) RW e sazonal ingenuo · (f) superou? · (g) cobertura |
| 8 | manuscrita | dois exercicios da lista teorica |

### Exigencias de entrega da lista
- codigo completo, comentado, **na ordem de execucao** -> `R/00`..`R/08` + `run_all.R`
- **banco efetivamente utilizado** -> `data/raw/kalshi_fed_panel.csv` (snapshot congelado)
- **versoes** -> `renv.lock` + `sessionInfo.txt` (gerado pelo `run_all.R`)
- Q5(d) exige a **lista de modelos descartados** -> `output/tables/modelos_descartados.csv`
- Q8 e **manuscrita**; digitada nao e aceita

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

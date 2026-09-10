# kalshi-fed-arima

Modelagem Box-Jenkins (ARIMA) de uma serie diaria de **mercado de previsao da Kalshi**
na categoria **Economics** (decisao de juros do Fed / FOMC), como avaliacao parcial de
**Econometria II — PPGEco/UFES** (Lista 01). O enquadramento e um **teste de eficiencia
fraca**: a lista permite confrontar a serie com um passeio aleatorio, mas isso nao e um
teste implementado por Diercks, Katz & Wright (FEDS 2026-010). A serie e um objeto
de precificacao risco-neutra (medida Q), potencialmente afetado por premios de risco;
resultados preditivos nao identificam eficiencia sob a medida fisica P. Alinhado a
Diercks, Katz & Wright (2026), *Kalshi and the Rise of Macro Markets* (referencia:
`jdkatz21/Prediction_Markets_Public`).

## Os dois artigos

| Artigo | Papel |
|---|---|
| **Kagan & Baiocchi (2026)**, *Calibration in Prediction Markets* | **A hipotese.** Precos da Kalshi se comportam como probabilidades genuinas, e cada vez mais perto da resolucao. Em *Economics*, Brier cai quase linearmente de 0,108 (3 meses) para 0,066 (fechamento). |
| **Diercks, Katz & Wright (2026)**, FEDS 2026-010, DOI 10.17016/FEDS.2026.010 | **O metodo.** Converte contratos binarios em distribuicao implicita e momentos. E o codigo que o `01_build_series.R` transcreve. |

A justificativa de Kagan & Baiocchi e a Lei dos Grandes Numeros, logo o teste deles e
**transversal**. Por construcao nao diz nada sobre a **trajetoria** de um mercado
individual. Se o preco e probabilidade calibrada que se atualiza com informacao, pela
lei das expectativas iteradas ele e um **martingale** -- e e isso que Box-Jenkins testa.
Contagem no PDF do FEDS 2026-010: "random walk" 0 ocorrencias, "martingale" 0.

**Ressalva obrigatoria na conclusao:** as probabilidades sao risco-neutras (medida Q),
nao fisicas (medida P), e podem estar distorcidas por premio de risco (FEDS 2026-010,
secao 3). O resultado estabelece martingale **sob a medida risco-neutra**; separar isso
de eficiencia sob a medida fisica exigiria identificar o premio de risco.

## Desvio declarado: frequencia
A lista pede **"preferencialmente mensal ou trimestral"**. A serie e **diaria**:
a Kalshi opera desde 2021 e seus mercados de FFR desde 2022, entao mensal nao alcanca
as **120 observacoes minimas**; e o fenomeno de interesse (atualizacao da expectativa
com a chegada de informacao) e intrinsecamente de alta frequencia. O minimo e cumprido
com folga (181 obs). A serie **nao** esta em pacote de R ou Python, como a lista exige.

Os itens sazonais (Q2c, Q3a, Q3b, Q7e-ii) **nao** podem ser respondidos com "nao se
aplica" -- isso e ponto perdido. Ver `docs/alinhamento.md`.

## O que a serie e, com precisao
Nota de rodape 2 do FEDS 2026-010: o contrato denota o **limite superior** da faixa-alvo.
O balde indexado por `s` e a faixa `[s, s+0,25]`, e somar `+0,125` entrega o **ponto medio
da faixa-alvo do FOMC**. Descreva assim no relatorio, nao como "taxa esperada" generica.

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

**Atencao:** o `yes_price` desses contratos e uma probabilidade risco-neutra da **cauda**
(`P(taxa > strike)`), nao a de um balde. Os strikes formam uma funcao de
sobrevivencia, e a massa de cada balde sai por **diferenciacao**. Tratar cada
desfecho como balde independente gera uma serie errada sem levantar erro
nenhum. Ver `docs/metodologia.md`.

## Estrutura
```
R/00_pull_kalshi.R       coleta da API -> data/raw/ (rode UMA vez; congela o banco)
scripts/pull_kalshi_trades.py coleta trades autenticados -> data/raw/
R/01_build_series.R      painel bruto -> data/processed/serie_diaria.csv
R/02..08_*.R             Questoes 1 a 7, na ordem de execucao
run_all.R                reproduz 01..08 sobre o banco congelado
data/raw/                o "banco" entregue (snapshot da Kalshi) — VERSIONADO
data/processed/          serie derivada usada na analise
output/figures, tables/  graficos e tabelas do relatorio
report/relatorio.qmd     relatorio em PDF (graficos/tabelas integrados)
docs/metodologia.md      cada decisao rastreada ate o codigo do paper
```

## Coleta (rodar uma unica vez)
```bash
Rscript R/00_pull_kalshi.R --discover   # lista os series_ticker reais; nao grava nada
# ajuste SERIES_TICKER no topo de R/00_pull_kalshi.R, depois:
Rscript R/00_pull_kalshi.R --refresh    # grava/atualiza data/raw/kalshi_fed_panel.csv
python scripts/pull_kalshi_trades.py    # coleta trades historicos e recentes autenticados
```
O script **se recusa a sobrescrever** um snapshot existente; `--refresh` destrava a
atualizacao de proposito. Ao final ele imprime linhas/reunioes/dias e os rotulos exatos
dos desfechos — esses rotulos sao o que o `01_build_series.R` precisa para montar a serie.

O coletor de candles e publico. O coletor de trades segue o pacote original e exige
`KALSHI_KEYID` (ou `KALSHI_API_KEY_ID`) e `KALSHI_PRIVATE_KEY` em `.env`; a chave
privada nao entra neste repo (ver `.gitignore`).

Com trades, o pipeline usa o ultimo negocio diario, como no paper. No fallback de
candles, usa `mid` por padrao para reduzir o bid-ask bounce; `yes_close` e usado
apenas quando o mid nao esta disponivel. A reuniao do modo `contrato_unico` e
escolhida por maior volume total, nao apenas por quantidade de dias.

## Reprodutibilidade
O criterio do professor e objetivo: rodar o codigo sobre o banco entregue tem de devolver
exatamente os mesmos numeros e graficos. Por isso:

1. **Os dados sao congelados.** Os coletores puxam da API (dado VIVO) e salvam o
   snapshot em `data/raw/`, que e **versionado no git**. A analise (`run_all.R`) **le o
   snapshot congelado e nunca re-puxa** — `run_all.R` nao chama os coletores.
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

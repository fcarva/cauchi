# Metodologia: do painel bruto da Kalshi a serie diaria

Toda decisao abaixo e rastreada ate o paper **Diercks, Katz & Wright (2026),
FEDS 2026-010, _Kalshi and the Rise of Macro Markets_**,
repositorio `jdkatz21/Prediction_Markets_Public`. Onde eu simplifiquei, esta
dito explicitamente.

## 1. Qual familia de mercado

A Kalshi tem duas familias do Fed, e elas nao sao intercambiaveis:

| Familia | Ticker do mercado | O que o preco significa |
|---|---|---|
| **Nivel** (`KXFED`, ex-`FED`) | `FED-22DEC-T4.25` | `P(taxa acima de 4.25)` |
| **Decisao** (`KXFEDDECISION`) | `KXFEDDECISION-28JAN-H26` | `P(categoria)` (corte/manutencao/alta) |

O paper usa a familia de **nivel** — em `code/kalshi_scraping/tickers.py` o
conjunto se chama `fed_levels` e os tickers sao `FED-<YYMON>-T<strike>`.
Este projeto segue a mesma escolha, por um motivo pratico: o strike ja e
numerico, entao a taxa esperada sai da distribuicao sem precisar de um mapa
arbitrario categoria -> pontos-base.

## 2. O erro que essa estrutura convida

O `yes_price` de `FED-22DEC-T4.25` **nao** e a probabilidade do balde
`[4.25, 4.50)`. E a probabilidade da cauda: `P(taxa > 4.25)`. Os strikes de um
mesmo contrato formam uma **funcao de sobrevivencia** (`1 - CDF`), decrescente
em strike.

Tratar cada desfecho como um balde disjunto e fazer `sum(p_i * taxa_i)` produz
uma serie errada — e errada sem levantar erro nenhum, o que e o pior caso.
A massa de cada balde vem de **diferenciar** strikes adjacentes.

## 3. Pipeline (`R/01_build_series.R`)

Transcrito de `code/convert_trades_to_pdfs/convert_trade_level_data_cdfs.R`,
com os parametros do bloco `FFR levels` de `data_convert_runner.R`:
`strike_int = 0.25`, `days_before_horizon = 180`, `moment_adjustment = .125`.

1. **Strike vem do ticker**, nao do rotulo de texto: `(?<=-T)\d+\.?\d*`.
   Rotulo e texto de marketing e muda; ticker e chave.
2. **Janela de 180 dias** antes do vencimento de cada reuniao (`days_before_horizon`).
3. **Monotonicidade / nao-arbitragem** — algoritmo `middle-out` do paper:
   ancora no strike de preco mais proximo de 49 cents (a Kalshi precifica 1-99,
   entao a mediana e 49, nao 50), forca precos nao-decrescentes a esquerda e
   nao-crescentes a direita. O paper argumenta que o bin central e o mais
   liquido, logo o mais confiavel para ancorar.
4. **Diferenciacao** da sobrevivencia em massa de balde:
   - cauda de baixo (balde extra em `min(strike) - 0.25`): `99 - P(acima do menor strike)`;
   - baldes internos: `P(acima de s_i) - P(acima de s_{i+1})`;
   - cauda de cima: `P(acima de s_n) - 1` (piso de 1 cent).
5. **Normalizacao** para somar 1.
6. **Ponto medio da faixa-alvo** = `sum(p_i * s_i) + 0.125`. O contrato em
   `s_i` denota o limite superior da faixa `[s_i, s_i + 0.25]`, portanto o
   ajuste de meio-balde tem interpretacao economica.

### O `+ 0.125` nao e detalhe de arredondamento
O balde `(s_i, s_i + 0.25]` fica indexado pelo seu limite **inferior** `s_i`.
Sem o ajuste de meio-balde (`strike_int / 2`), **a serie inteira fica 12,5 bps
baixa** — um vies constante que passaria despercebido no grafico e
contaminaria qualquer comparacao de nivel.

## 4. Do painel para UMA serie

O passo 3 entrega um painel `(reuniao, dia) -> taxa esperada`. O ARIMA precisa
de uma serie so. Tres modos em `01_build_series.R`:

| `MODO` | O que faz | Custo |
|---|---|---|
| `contrato_unico` (default) | caminho completo de **uma** reuniao | nenhum roll; 180 dias ja passam das 120 obs |
| `front` | a cada dia, a reuniao vigente mais proxima | **roll**: o alvo troca e cria salto de nivel artificial |
| `horizonte_fixo` | a reuniao ~N dias a frente | interpolacao implicita entre reunioes |

**O default e `contrato_unico` de proposito.** Dentro dele, escolhemos a reuniao
com maior volume total, como proxy de liquidez. No modo `front`, quando uma
reuniao vence e a serie passa a seguir a proxima, o alvo muda — o salto que
aparece nao e noticia economica, e artefato de construcao. Isso entra direto
nos testes de raiz unitaria da **Questao 2** e no diagnostico de residuos da
**Questao 5**, e seria facil interpretar o artefato como quebra estrutural.
Uma reuniao so, com seus 180 dias, evita o problema inteiro e ainda cumpre o
minimo de 120 observacoes.

## 5. Onde eu simplifiquei (validar)

- **Dado de origem.** Com o snapshot de trades, seguimos o paper e tomamos a
   **ultima negociacao de cada dia** (`convert_to_daily(method = 'last')`). Se
   apenas candles estiverem disponiveis, usamos `mid` por padrao e `yes_close`
   apenas como fallback. Nesse caminho, o close de um dia sem negocio pode ser
   um preco velho; o mid reduz o bid-ask bounce, mas nao e a mesma serie do
   ultimo negocio trade-level.
- **`swap_probabilities` nao implementado.** O paper roda um algoritmo extra
  (tipo bubble sort) que empurra massa de baldes vazios em direcao a moda,
  para lidar com dias de liquidez baixa. Nao transcrevi. Se a distribuicao
  diaria vier com buracos, isso pode mexer na media — checar antes de fechar
  a Questao 1.
- **Massa negativa** apos diferenciacao e truncada em 0 antes de normalizar.

## 6. Interpretacao economica e credenciais

Os precos da Kalshi sao probabilidades risco-neutras, sob a medida Q, e podem
ser distorcidos por premios de risco. Assim, comparar com passeio aleatorio
nao identifica sozinho eficiencia sob a medida fisica P. Separar isso de
eficiencia sob P exigiria identificar o premio de risco.

Os endpoints usados aqui (`/series`, `/events`, `/candlesticks`) sao **leitura
publica anonima**. O scraper do paper assina requisicoes com RSA-PSS
(`KALSHI-ACCESS-SIGNATURE`, ver `code/kalshi_scraping/clients_kalshi.py`)
porque puxa trade-level; nada neste projeto precisa disso. Chave de API da
Kalshi assina **ordens** — nao entra neste repo (ver `.gitignore`).

## 7. Um aviso sobre o repo do paper

O README dele diz que os dados derivados vem inclusos ("the data is already
included"), mas `data/` esta no `.gitignore` do proprio repositorio e **nao
existe no clone**. Nao da para pular a coleta: e preciso puxar da API.

---

## Coleta completa: `scripts/pull_kalshi_full.py`

### Por que um coletor novo

Auditando `scripts/pull_kalshi_trades.py` apareceram duas falhas que afetam o que
já está no relatório:

**1. `/events` sem paginação.** Uma única chamada com `limit=200` e nenhum cursor.
Acima de 200 eventos, truncava **em silêncio**. `tests/test_coletor.py` demonstra:
sobre um servidor falso com 401 eventos em 3 páginas, o método novo recupera os 401;
o antigo pararia em 200.

**2. Nenhum metadado de liquidação.** O painel não carrega `close_time`,
`expiration_time`, `status`, `result` nem `settlement`. **Foi essa a raiz do bug em
que `expiry <- max(date)` tratava a data do snapshot como se fosse a reunião** — o
que fez a série do `KXFED-26DEC` terminar a três meses da resolução e o ARCH-LM dar
p = 0,96. Com `markets.csv`, o horizonte até a resolução (τ) passa a ser real, e não
inferido.

### O que ele coleta

| Arquivo | Conteúdo |
|---|---|
| `markets.csv` | metadados por mercado: `close_time`, `expiration_time`, `status`, `result`, `settlement_value`, `open_interest`, `floor_strike`, `cap_strike` |
| `candlesticks.csv` | OHLC diário + bid/ask de fechamento + volume + open interest, com fallback para o endpoint histórico |
| `trades.csv` | negócios individuais, deduplicados por `trade_id`, dos endpoints vivo e histórico |
| `manifest.json` | timestamp UTC, endpoints usados, contagem de chamadas, linhas e **sha256 por arquivo** |

### Diferenças de desenho

- **Credencial é opcional.** Leitura de dados de mercado na Kalshi é pública. O
  script assina apenas se houver credencial no ambiente e informa o que conseguiu
  sem ela. O anterior exigia chave para tudo.
- **Snapshot datado e imutável.** Grava em `data/raw/snapshot_AAAA-MM-DD/` e se
  **recusa** a sobrescrever. `--force` destrava de propósito; `--resume` continua uma
  coleta interrompida.
- **Retomada.** Checkpoint por mercado, gravado a cada 10.
- **Backoff.** Respeita `Retry-After` em 429 e recua exponencialmente em 5xx.

### O procedimento correto ao re-puxar

Os dados da Kalshi são vivos. Re-puxar **muda os números do relatório**. Portanto:

1. `python scripts/pull_kalshi_full.py --series KXFED` — cria um snapshot novo e
   datado, sem tocar no anterior;
2. **não apague o snapshot antigo** — o relatório já entregue depende dele;
3. aponte o `01` para o novo snapshot e rode `run_all.R` **inteiro**;
4. commite o snapshot novo, o `manifest.json` e **todos** os outputs regenerados no
   mesmo commit — números do relatório e banco de dados têm de andar juntos;
5. atualize a data do snapshot no `README.md` e no bloco de declaração da série.

Entregar o relatório antigo com o snapshot novo quebra exatamente o critério que o
professor vai verificar: rodar o código sobre o banco entregue tem de devolver os
mesmos números.

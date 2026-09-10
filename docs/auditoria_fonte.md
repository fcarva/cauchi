# Auditoria do replication package `jdkatz21/Prediction_Markets_Public`

Revisão do código-fonte de Diercks, Katz & Wright (FEDS 2026-010) no commit
`acd02b8`, procurando inconsistências entre a prosa do artigo e o código, e
inconsistências internas ao próprio código.

Nada aqui invalida o método — que continuamos usando. O objetivo é saber **onde
não confiar cegamente** e o que herdar com cuidado.

---

## Achados confirmados

### 1. Bug de escopo em `swap_probabilities` — duplicado em dois arquivos

`convert_trade_level_data_cdfs.R:370-372`:

```r
protected_idx <- which(df_group$adjusted_yes_price > 49)
if (length(protected_idx) == 0) {
  protected_idx <- which.max(df$adjusted_yes_price)   # <- df, não df_group
}
```

A linha de fallback indexa **o painel inteiro** (`df`) em vez do grupo
contrato-dia (`df_group`). O valor retornado é um índice na casa dos milhares,
enquanto `i` percorre as poucas linhas do grupo — logo a guarda `i != protected_idx`
fica **sempre verdadeira** e a proteção nunca se aplica.

O comentário do próprio código diz para que serve a guarda: *"to avoid cycles, we
have to make sure everything goes to where the median is. Never swap the median
location"*. O bug desativa a proteção anticiclo exatamente no ramo degenerado que
ela existe para tratar: contrato-dia em que **nenhum** strike tem preço acima de
49 cents.

Idêntico em `convert_bid_ask_data_cdfs.R:382`. É defeito propagado por
copiar-e-colar, não erro de digitação isolado.

**Para nós:** não transcrevemos `swap_probabilities`. O `redistribute_empty_bins`
da nossa implementação deve ser conferido contra este ramo.

### 2. O Apêndice A contradiz o próprio código de bid-ask

O Apêndice A conclui que o ponto médio bid/ask é pouco confiável *"due to
occasionally large spreads on tail outcomes"* e fixa o último negócio.

Mas `convert_bid_ask_data_cdfs.R:19` define `read_bid_ask(filter_large_spreads = T)`,
que marca `abs(yes_bid_close - yes_ask_close) > 10` cents e **arrasta o último par
bid/ask bom** — tratamento exato do problema que o apêndice usa como argumento.

Pelo material público não dá para saber se a Figura A.1 foi produzida com ou sem o
filtro. **Se foi sem, a comparação do apêndice não é contra o melhor pipeline de
bid/ask deles.** Não é acusação: é uma questão em aberto que muda a leitura do
resultado.

**Para nós:** `spread_largo()` foi acrescentado a `R/fun_distribuicao.R`,
replicando o limiar de 10 cents.

### 3. Três regexes diferentes para o mesmo campo

| Arquivo | Regex | Aceita strike negativo? |
|---|---|---|
| `convert_trade_level_data_cdfs.R:81` | `(?<=-T)\d+\.?\d*` | **não** |
| `convert_bid_ask_data_cdfs.R:28` | `(?<=-T)[^\-]+$` + troca de `U+2212` por `-` | **sim** |
| `convert_bid_ask_data_cdfs.R:141` | `(?<=-T)\d+\.?\d*` | não |
| `convert_trade_level_data_pdfs.R:83` | `[^-]+$` | parcialmente |

O arquivo de bid-ask carrega **duas** implementações conflitantes de leitura de
strike. Só uma trata o sinal de menos Unicode.

### 4. CPI mensal roteado pelo parser que rejeita negativos

`data_convert_runner.R:38` manda `trade_level_data_headline_cpi_releases_mom.csv`
pelo `extract_distributions` de `convert_trade_level_data_cdfs.R` — o que usa
`\d+\.?\d*`.

**CPI mensal pode ser negativo.** Se a escada de strikes da Kalshi inclui valores
abaixo de zero, eles viram `NA`, são descartados pelo `na.omit()` em
`fill_dataless_days`, e **a cauda esquerda da distribuição desaparece em silêncio**,
viesando a média implícita para cima. Não consigo confirmar sem os dados — eles não
estão no repositório (ver achado 9) — mas o caminho de código é esse.

Para a FFR o ponto é inócuo: taxas não são negativas. Ainda assim, `le_strike()` foi
acrescentado ao nosso núcleo aceitando negativo e o sinal Unicode, para não herdar a
fragilidade.

### 5. Remendo de dados presente em dois arquivos e ausente no terceiro

`contract_preamble = ifelse(contract_preamble == 'FED-22JULY', 'FED-22JUL', ...)`
aparece nos dois conversores de CDF e **não** no de PDF. É correção pontual de um
defeito da fonte, aplicada em um caminho e não no outro.

### 6. Colisão de nomes entre os três conversores

Os três definem funções homônimas: `read_data`, `convert_to_daily`, `clean_data`,
`convert_to_probabilities`, `get_moments`, `extract_distributions`.

`data_convert_runner.R` faz `source()` deles em sequência, e cada `source`
**sobrescreve silenciosamente** as definições anteriores. Funciona se o arquivo for
executado de cima para baixo. Quebra sem aviso em uso interativo no RStudio — que é
justamente o que os blocos comentados no fim de cada arquivo convidam a fazer.

Num pacote cujo propósito declarado é *"transparency about methodological
decisions"*, essa é a fragilidade mais séria da lista.

### 7. Exemplos comentados não rodariam

`extract_distributions` exige `output_wide` (sem valor padrão, posição 4). As **10**
chamadas comentadas no fim de `convert_trade_level_data_cdfs.R` omitem o argumento.
Descomentar qualquer uma dá erro de argumento faltante.

### 8. Bloco de bid-ask rotulado "FFR levels" lê o arquivo de decisões

`data_convert_runner.R:83-89`:

```r
# FFR levels
# extract_distributions(input_file = 'data/orderbook_data/daily_bid_ask_fed_decisions_data.csv',
#                       strike_int = 0.25, moment_adjustment = .125)
```

O rótulo diz **levels**, o arquivo é **fed_decisions**, e os parâmetros
(`strike_int = 0.25`) são os de levels. Está comentado, então não roda — mas é
exatamente o tipo de linha que um replicador descomenta.

### 9. O README promete dados que o repositório não tem

O README diz *"To use provided data: Skip this step — the data is already
included."* Mas `data/` está no `.gitignore` do próprio repositório e não existe no
clone. Não dá para pular a coleta.

### 10. Prosa diz moda, código diz mediana

A seção 3 do artigo descreve *"constructing the distribution outward from the
**mode** toward the tails"*. O código ancora em `target = 49`, que é o cruzamento da
**mediana** na escala 1–99 da Kalshi. Nosso `middle_out()` segue o código.

---

## O que NÃO é inconsistência

`convert_trade_level_data_pdfs.R` **não diferencia** a sobrevivência — usa
`probability = yes_price * 100 / sum` diretamente. Isso é **correto por desenho**: o
arquivo trata contratos que pagam se o desfecho cai *dentro de um intervalo*, e não
*acima de um limiar*. O artigo distingue os dois casos explicitamente na seção 3. Os
dois conversores correspondem às duas estruturas de contrato.

---

## O que herdamos de bom: a checagem de robustez deles

`robustness_data_runner.R` roda a mesma série variando dois eixos:

- `convert_to_daily_method` ∈ {`last`, `VWAP`}
- `clean_data_method` ∈ {`middle-out`, `left-to-right`, `right-to-left`}

Nosso núcleo só implementava `middle-out`. `impoe_monotonicidade()` agora oferece os
três, para que o relatório reproduza a mesma checagem. Os três divergem de fato —
sobre os preços `95, 80, 87, 60, 10` (violação no terceiro):

| Método | Resultado |
|---|---|
| `middle-out` | 95, **87**, 87, 60, 10 |
| `left-to-right` | 95, **80**, 80, 60, 10 |
| `right-to-left` | 95, **87**, 87, 60, 10 |

A diferença é qual preço é tratado como autoritativo. Um apêndice de robustez que
mostre a série sob os três métodos responde antecipadamente à pergunta óbvia de
banca: *"e se a regra de monotonicidade fosse outra?"*

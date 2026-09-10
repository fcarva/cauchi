# Alinhamento: os dois artigos e a Lista 01

## Os dois artigos fazem coisas diferentes — e é isso que serve

O scaffold original citava só Diercks, Katz & Wright. Depois de ler os PDFs, a
estrutura correta é de **dois** artigos, e o de calibração **cita** o outro:

| Artigo | Papel neste trabalho |
|---|---|
| **Kagan & Baiocchi (ago/2026)**, *Calibration in Prediction Markets: Theory and Evidence* | **A hipótese.** Preços da Kalshi se comportam como probabilidades genuínas, e cada vez mais conforme a resolução se aproxima. |
| **Diercks, Katz & Wright (2026)**, *Kalshi and the Rise of Macro Markets* (NBER WP 34702) | **O método.** Como transformar contratos brutos em distribuição implícita e seus momentos. É o `replication package` que o `01_build_series.R` transcreve. |

### O que Kagan & Baiocchi encontram (e que importa aqui)

Amostra: 2.243.741 mercados resolvidos da Kalshi, 2021 a meados de 2026.

- Brier agregado cai de ~0,08–0,09 no horizonte de 3 meses para ~0,02 no fechamento.
- Acurácia ingênua sobe de 88,3% (3 meses) para 97,2% (fechamento).
- **Economics é a categoria com o padrão mais limpo.** Brier cai
  *monotonicamente e quase linearmente*: 0,108 → 0,109 → 0,100 → 0,089 → 0,073
  → 0,066 → 0,066 (3 meses, 2 meses, 1 mês, 1 semana, 1 dia, 1 hora, fechamento),
  sobre N = 16.701 mercados. Os autores atribuem isso ao fato de mercados de
  Economics resolverem contra divulgações **pré-agendadas e não-ambíguas** — que é
  exatamente o caso de uma reunião do FOMC.

### A brecha que este trabalho ocupa

A justificativa teórica deles é a **Lei dos Grandes Números** (§3.3): *"Probability
is only testable through repetition."* Calibração, como eles a medem, é um objeto
**transversal** — junta milhões de mercados e compara frequência realizada com
preço declarado. Por construção, esse método **não diz nada sobre a trajetória de
um mercado individual ao longo do tempo**.

É aí que entra a Lista 01. Se o preço é uma probabilidade bem calibrada que se
atualiza com informação, então pela lei das expectativas iteradas ele é um
**martingale**. Logo:

> **Tese do relatório.** Kagan & Baiocchi testam calibração transversalmente, com
> Brier e diagramas de confiabilidade. Eu testo a **implicação em série temporal**
> da mesma hipótese, num único mercado, com Box-Jenkins: se o preço é um
> martingale, a série deve ser I(1), suas diferenças ruído branco, e nenhum ARIMA
> deve superar o passeio aleatório fora da amostra.

Isso não é replicação — é um teste complementar, por um caminho que o método deles
não alcança.

---

## Onde a série escolhida atrita com a lista

A lista pede **"Frequência: preferencialmente mensal ou trimestral"**. A série é
**diária**. Isso é um desvio consciente e precisa ser declarado no relatório:

- A Kalshi existe desde 2021, e os mercados de FFR desde 2022. Uma série mensal
  não chega perto das **120 observações mínimas** exigidas.
- O objeto de interesse — a expectativa de mercado se atualizando com a chegada de
  informação — é intrinsecamente de alta frequência. Agregar para mensal destruiria
  exatamente o fenômeno que Kagan & Baiocchi documentam.
- O mínimo de 120 observações **é cumprido**: um único contrato, com a janela de
  180 dias do paper, entrega ~180 observações.
- A série **não** está disponível em pacote de R ou Python (exigência da lista):
  vem da API pública da Kalshi e é congelada em `data/raw/`.

### Consequência: os itens sazonais

A lista é claramente desenhada para série mensal/trimestral com sazonalidade —
Q2(c) pede `D`, Q3(a) pede "ao menos dois ciclos sazonais completos", Q3(b) pergunta
por picos em `s, 2s, 3s` e vizinhanças `s±1`, Q7(e)(ii) exige benchmark sazonal ingênuo.

**Não responda "não se aplica".** Isso é ponto perdido. Numa série financeira diária
existe um candidato sazonal legítimo: **efeito dia-da-semana, `s = 5`**. Então:

- Q3(a): FAC/FACP com **pelo menos 10 defasagens** (dois ciclos de 5 dias úteis).
- Q3(b): inspecione explicitamente os lags 5, 10, 15 e as vizinhanças 4, 6, 9, 11.
- Q2(c): teste a necessidade de diferença sazonal com `s = 5` e conclua `D = 0`
  **com evidência**, não por omissão.
- Q7(e)(ii): rode o sazonal ingênuo com `s = 5` e mostre que ele perde. Explique
  por quê: não há razão econômica para a expectativa de hoje se parecer com a de
  cinco pregões atrás mais do que com a de ontem.

Assim todo item sazonal é respondido com análise de verdade, e a ausência de
sazonalidade vira **resultado documentado** em vez de lacuna.

---

## Três previsões concretas sobre os diagnósticos

Estas decorrem do dado e dos artigos. Se elas se confirmarem, o relatório tem um
fio condutor; se não, o desvio é em si um achado.

### 1. Q5(c) ARCH-LM deve rejeitar — e isso é o resultado, não uma falha

Kagan & Baiocchi mostram que o Brier de Economics cai monotonicamente com a
aproximação da resolução. Traduzido para a série do aluno: **a variância da variação
diária encolhe conforme a reunião se aproxima**, porque a incerteza se resolve.
Isso é heterocedasticidade por construção.

Portanto o ARCH-LM da Q5(c) é, neste trabalho, **um teste em série temporal da
Figura 8 do paper de calibração** — obtido por um método inteiramente diferente do
deles. Rejeitar homocedasticidade corrobora o artigo. Diga isso com todas as letras.

### 2. Q3 pode exibir um MA(1) **espúrio** de microestrutura

O *bid-ask bounce* induz autocorrelação de primeira ordem **negativa** nas
diferenças. Identificar um MA(1) aí e chamar de previsibilidade é erro: é ruído de
microestrutura, não informação. É por isso que o `01_build_series.R` usa `mid`
(ponto médio bid/ask) e não o preço de fechamento — a decisão vem de
`docs/metodologia.md` e deve ser citada na Q3(b).

### 3. Q7(g) a cobertura empírica deve **exceder** os 95% nominais

A lista manda reservar as **últimas 24 observações**. Numa série de contrato único,
essas 24 observações são justamente os dias **imediatamente anteriores à reunião** —
o trecho de menor variância de toda a amostra, pelo argumento do item 1.

Consequência: os intervalos de 95% do Esquema 1, estimados sobre um período de
variância mais alta, ficam **largos demais** para a janela de validação. A cobertura
empírica deve passar de 95%. Isso não é bug — é a mesma heterocedasticidade vista
pelo lado da previsão, e explicá-la responde a Q7(g) com profundidade.


### 3b. Aviso sério: a janela de validação pode ser degenerada

Kagan & Baiocchi relatam, sobre Diercks et al. (2026), que **as previsões mediana e
modal da FFR na Kalshi acertam com registro perfeito no dia anterior a cada reunião
do FOMC** — melhora estatisticamente significante sobre os futuros de fed funds.

Combine isso com a exigência da Q7(a) de reservar as **últimas 24 observações**: numa
série de contrato único, essas observações são o trecho em que o mercado já
praticamente resolveu a incerteza. A série tende a **achatar** perto de um valor
constante.

Consequências práticas, que precisam ser reportadas em vez de escondidas:

- o RMSE de **todos** os métodos fica pequeno, e as diferenças entre eles, minúsculas;
- o passeio aleatório fica quase imbatível, não por mérito preditivo, mas porque a
  série mal se move no período;
- um teste de Diebold-Mariano terá **pouquíssima potência** — não confunda
  "não rejeito" com "são equivalentes";
- a MAPE fica bem-comportada, mas pouco informativa.

**A lista é explícita: não altere o modelo para forçar resultado favorável (Q7f).**
O procedimento correto é seguir a divisão exigida, reportar as métricas como pedido,
e **acrescentar** um gráfico do perfil de variância ao longo da amostra mostrando por
que a janela de validação é o trecho mais fácil. Isso responde à Q7(f) e à Q7(g) com
profundidade e é coerente com a Q5(c).

---

## Mapa: item da lista → arquivo

| Item | Arquivo | Observação |
|---|---|---|
| Q1(a) | `R/02_inspecao.R` | Descrever tendência, sazonalidade, mudanças de nível, outliers, dispersão. A lista tem **só o item (a)**. |
| Q2(a)–(d) | `R/03_integracao.R` | ADF/PP/KPSS com estatística, valor crítico, p-valor, defasagens **e critério**, termos determinísticos. Justificar constante/tendência. `d` e `D`. |
| Q3(a)–(c) | `R/04_identificacao.R` | FAC/FACP com bandas 95%, ≥ 2 ciclos sazonais (≥10 lags). Três candidatos justificados. |
| Q4(a)–(f) | `R/05_estimacao.R` | Tabela única; amostra efetiva; validade da comparação AIC/BIC; convenção de `k`; divergência AIC vs BIC; raízes com gráfico. |
| Q5(a)–(e) | `R/06_diagnostico.R` | Resíduos, FAC/FACP, histograma, QQ. Ljung-Box **com g.l. corrigidos**. JB e ARCH-LM. **Log de modelos descartados.** Sobreajuste deliberado. |
| Q6(a)–(d) | `R/07_sobrediferenciacao.R` | Reestimar com `d*+1`. θ̂, erro-padrão, raiz do polinômio MA, σ̂²ₐ nas duas versões, FAC dos resíduos, sinais práticos. |
| Q7(a)–(g) | `R/08_previsao.R` | H=24. Esquema 1 (origem fixa, multi-passo, IC 95%) e Esquema 2 (origem móvel, 1 passo, **sem reestimar**). RMSE/MAE/MAPE. RW e sazonal ingênuo. Tabela única. Cobertura empírica. |
| Q8 | manuscrita | Dois exercícios da lista teórica, com todas as passagens. |

---

## Fatos verificados nesta máquina

**Q4(d) — convenção de contagem de parâmetros do R.** A lista manda verificar na
documentação se σ̂²ₐ entra em `k`. Verificado empiricamente em **R 4.3.3**:

```r
fit <- arima(y, order = c(1,0,0))   # coeficientes: ar1, intercept  (2)
attr(logLik(fit), "df")             # 3  <- inclui sigma^2
fit$aic == -2*fit$loglik + 2*3      # TRUE
BIC(fit) == -2*fit$loglik + log(n)*3  # TRUE
```

**Conclusão: o `stats::arima()` do R inclui σ̂²ₐ na contagem `k`.** Um ARMA(p,q)
com intercepto tem `k = p + q + 1 (intercepto) + 1 (sigma²)`. Isso importa na
Q4(e): a penalidade do BIC é `log(n)·k`, e usar `k` errado desloca a comparação.

**Q4(c) — a armadilha.** AIC e BIC só são comparáveis entre modelos estimados sobre
**a mesma variável dependente e a mesma amostra efetiva**. Um candidato com `d`
diferente é estimado sobre uma série *diferente* (nível vs. diferença) e com uma
observação a menos. A comparação direta é **inválida**. Se precisar comparar entre
ordens de integração, compare fora da amostra (Q7) ou reestime todos sobre a mesma
amostra efetiva, descartando as observações iniciais do candidato com maior `d`.

---

# Auditoria da primeira rodada completa

Rodada com dados reais (snapshot de 2026-09-08) e resultados em `output/`.
Reproduza a auditoria com `Rscript tests/audita_contratos.R`.

## Achado principal: o contrato escolhido era o errado

O `01_build_series.R` escolhia a reunião com **mais dias de histórico**. Isso
selecionou o `KXFED-26DEC` — que é justamente o contrato **mais raso da mesa**:

| Contrato | Resolvido? | Volume | dp da diferença | Maior salto | AC(1) |
|---|---|---:|---:|---:|---:|
| **KXFED-26JUL** | **sim** | **3.261.206** | **5,4 bps** | **31 bps** | **−0,115** |
| KXFED-26SEP | não | 1.637.343 | 8,8 bps | 48 bps | −0,104 |
| KXFED-27APR | não | 148.655 | 18,1 bps | 66 bps | −0,287 |
| KXFED-26DEC *(usado)* | não | 129.707 | 8,3 bps | 46 bps | −0,266 |
| KXFED-26OCT | não | 51.271 | 8,2 bps | 56 bps | −0,358 |
| KXFED-27JAN | não | 49.958 | 15,0 bps | 70 bps | −0,409 |
| KXFED-27MAR | não | 35.094 | 13,5 bps | 62 bps | −0,257 |

Isso contraria diretamente o artigo que enquadra o trabalho: Kagan & Baiocchi
mostram que a calibração melhora **quase monotonicamente com volume negociado e
número de traders únicos**. Escolher por número de dias seleciona a reunião mais
distante, que é a mais ilíquida, e maximiza exatamente o ruído que o artigo
documenta. Note a coluna AC(1): quanto mais raso o contrato, mais negativa a
autocorrelação de primeira ordem — a assinatura do *bid-ask bounce*.

Na série efetivamente entregue (`data/processed/serie_diaria.csv`, contrato
26DEC pelo caminho de *trades*) isso produziu um salto de **157 pontos-base em um
único dia** (2026-03-24) e curtose **47,2** — daí o Jarque-Bera de 24.624. Nenhuma
surpresa de FOMC move a expectativa 157 bps num dia; é microestrutura de mercado
raso, não informação.

**Correção aplicada:** `contrato_unico` passa a selecionar por **maior volume**
entre os contratos que cumprem o mínimo de observações. `KALSHI_EVENTO` força um
contrato específico. Há ainda um aviso quando o contrato escolhido **não resolveu**.

## Achado secundário: a série não terminava na reunião

`expiry <- max(date)` assume contrato resolvido. Para um contrato **vivo**, isso é
apenas a data do snapshot. O `KXFED-26DEC` refere-se à reunião de **dezembro de
2026** — a série terminava em setembro, a três meses da resolução.

Consequência direta: a queda de variância com a aproximação da reunião — o
fenômeno central do artigo — ficava **fora da amostra**. É por isso que o ARCH-LM
da Q5(c) deu **p = 0,96**, sem rejeitar.

Trocando para o `KXFED-26JUL`, que de fato resolveu dentro da amostra, os três
testes concordam:

| Teste | Resultado |
|---|---|
| Regressão `log(dif²) ~ dias até a reunião` | inclinação **+0,0168** (t = 2,40, **p = 0,017**) |
| Teste F, 1ª metade vs 2ª metade | F = **3,516**, **p < 0,00001** |
| ARCH-LM (7 lags) | LM = **17,68**, **p = 0,0135** |

A variância da variação diária **cai pela metade** conforme a reunião se aproxima
(8,1 → 4,3 bps). Isso é a Figura 8 de Kagan & Baiocchi vista em série temporal,
obtida por método inteiramente distinto do deles.

### Uma ressalva metodológica que vale ponto

**O ARCH-LM é o teste errado para essa afirmação, e a lista o exige mesmo assim.**
Ele procura *agrupamento* de volatilidade — dependência condicional nos quadrados.
O que o artigo prevê é uma queda **suave e determinística** da variância ao longo
do horizonte, que o ARCH-LM pode não capturar. Rode o ARCH-LM porque a Q5(c) manda,
e **acompanhe-o** da regressão e do teste F acima, explicando a diferença. Isso
transforma um item de checklist em argumento.

## Pendências da lista na rodada atual

| Item | Situação |
|---|---|
| Q2(a) | A coluna `lags` reporta **12**, que é o `max_lag`, não a defasagem escolhida pelo AIC. A lista pede o número de defasagens **e** o critério. Extrair de `fit@testreg` o lag efetivo. |
| Q2(c) | `D = 0` justificado com *"não foi imposta diferença sazonal"* — decisão **por omissão**. Precisa de evidência (teste com `s`). |
| Q2(d) | Não abordado. E os testes **são ambíguos**: ADF com tendência dá −3,19 (não rejeita a 5%, VC −3,43) enquanto KPSS `tau` dá 0,150 (rejeita a 5%, VC 0,146). A lista pede explicitamente que a ambiguidade seja explicitada e a escolha justificada. |
| Q4(d) | Não documentado. Resposta verificada: **o R inclui σ̂²ₐ em `k`**. |
| Q5(d) | `output/tables/modelos_descartados.csv` **não existe**. É entrega obrigatória. |
| Q7(e) | Sazonal ingênuo usa `s = 7`. Defensável — a série é de calendário e inclui fins de semana — mas precisa ser **justificado** no texto, não deixado implícito. |
| Q7(g) | Cobertura = **100%** contra 95% nominais, exatamente como previsto. Falta a explicação (janela de validação é o trecho de menor variância). |
| Q4 | `ARIMA(3,1,2)` selecionado — cinco parâmetros numa série que a hipótese diz ser martingale. Provável ajuste ao ruído de microestrutura do contrato raso. **Reestimar após a troca de contrato.** |

---

# O que o paper FEDS 2026-010 acrescenta

Agora com o PDF em mãos (antes eu só tinha lido o código do *replication package*).
Citação correta: **Diercks, A. M., Katz, J. D. & Wright, J. H. (2026). "Kalshi and
the Rise of Macro Markets", Finance and Economics Discussion Series 2026-010,
Board of Governors of the Federal Reserve System.** DOI 10.17016/FEDS.2026.010.

## 1. O que a nossa série é, com precisão

Nota de rodapé 2 do paper: *"Kalshi's contract is denoted for the upper bound of
the FFR"*. O exemplo deles: strike 4,00 a $0,40 e strike 4,25 a $0,22 dão 18% de
probabilidade para **a faixa-alvo 4,00–4,25**.

Logo, o balde indexado por `s` é a faixa-alvo `[s, s+0,25]`, e somar `+0,125`
entrega o **ponto médio da faixa-alvo do FOMC**. Descreva assim no relatório:

> A série é a **expectativa implícita do ponto médio da faixa-alvo dos *fed funds***
> decidida na reunião de ⟨mês/ano⟩, em pontos percentuais.

Não é "a taxa esperada" genericamente. Essa precisão importa na Questão 1.

## 2. Ponto médio bid/ask: o paper desaconselha, e para o nosso caso a medição inverte

Nota de rodapé 4: *"midpoints of bid-ask spreads seem to introduce additional
issues due to occasionally large spreads on tail outcomes"*. Eles usam o **último
preço negociado**.

**Eu havia recomendado `mid` como virtude do pipeline. Contra o paper, isso estava
errado — mas a medição mostra que o conselho deles não transporta para o nosso
caminho de dados.** Medido no `KXFED-26JUL`:

| Fonte | obs | dp da diferença | Maior salto | Curtose | AC(1) |
|---|---:|---:|---:|---:|---:|
| `yes_close` (último negócio) | 153 | 20,5 bps | 127,8 bps | 21,4 | **−0,379** |
| `mid` (ponto médio) | 179 | **5,4 bps** | **31,2 bps** | **12,9** | **−0,115** |

A explicação: no pipeline **trade-level** deles, "último negócio" é uma transação
real. No nosso caminho por **candlesticks**, o `yes_close` de um dia sem negócios é
preço velho — daí as 26 observações perdidas e os saltos de 128 bps.

O `AC(1)` é a evidência direta: −0,379 no último negócio contra −0,115 no ponto
médio é a assinatura do *bid-ask bounce*, que o `mid` remove. A correlação entre as
variações diárias das duas séries é de apenas **0,135** — são séries diferentes,
não variantes da mesma.

**Decisão:** quando há trades (`data/raw/kalshi_fed_trades.csv`), o pipeline usa o
último negócio e segue o paper. O `COL_PRECO` governa apenas o *fallback* por
candlesticks, onde `mid` é mensuravelmente melhor. Ambas as escolhas ficam
documentadas — é isso que um apêndice de robustez deve conter.

## 3. Liquidez: o paper sustenta a correção do contrato

Seção 2.3: *"Liquidity is important as it helps to ensure prices reflect real-time
information from incoming news."* E na seção 3: *"the outermost (tail) contracts
often suffer from low trading volume, which can lead to stale prices and noisy
estimates in the tails—especially in illiquid markets."*

Isso confirma, pela fonte do método, que selecionar o contrato por **volume** (e
não por número de dias) é a escolha correta.

## 4. Divergência entre a prosa e o código deles

O paper diz construir a distribuição *"outward from the **mode** toward the tails"*.
O código do *replication package* ancora em `target = 49`, que é o cruzamento da
**mediana** na escala 1–99 da Kalshi. Nosso `middle_out()` segue o **código**, não a
prosa. Divergência registrada em `R/fun_distribuicao.R`; vale uma nota de rodapé no
relatório.

## 5. A ressalva que precisa estar na conclusão

Seção 3, *Caveats*: *"it is giving risk-neutral probabilities under the **Q measure**,
not actual physical probabilities under the **P measure**... the probabilities may be
distorted by risk premia. The retail investor base of Kalshi might alter the risk
premia properties."*

**Esta é a principal ameaça à interpretação do resultado da Questão 7.** Sob a medida
Q com prêmio de risco variando no tempo, o preço **não precisa** ser martingale sob a
medida P — e, no sentido inverso, não rejeitar o passeio aleatório não estabelece
eficiência de forma limpa. O que o teste estabelece é mais modesto e ainda assim
válido:

> A série se comporta como martingale **sob a medida risco-neutra**. Separar isso de
> eficiência sob a medida física exigiria identificar o prêmio de risco, o que está
> fora do alcance desta lista.

Escreva isso na conclusão. É a diferença entre um resultado defensável e uma
afirmação que o professor derruba numa linha.

## 6. E a confirmação de que a brecha existe

Contagem de termos no PDF completo do FEDS 2026-010: **"random walk" 0 ocorrências,
"martingale" 0, "efficien" 1**. Somado ao artigo de calibração, cuja justificativa é
a Lei dos Grandes Números e cujo teste é transversal, nenhum dos dois faz o teste em
série temporal que a Lista 01 pede. A afirmação de complementaridade não é retórica.

---

# Rodada com KXFED-26JUL: o que melhorou e o que quebrou

Série regenerada: **181 obs, 2026-01-30 a 2026-07-29** — e agora ela **termina na
reunião**, não na data do snapshot. A troca de contrato funcionou:

| | 26DEC (antes) | 26JUL (agora) |
|---|---:|---:|
| σ̂²ₐ do ARIMA(1,1,0) | 0,02603 | **0,00755** (−71%) |
| média \|diferença\| | 6,72 bps | **3,41 bps** |
| amplitude do nível | 1,76 pp | **0,83 pp** |
| termina na resolução? | não | **sim** |

## O modelo selecionado é inadmissível

`q4_selecao.csv` traz **ARIMA(3,1,3)** pelo AIC. Ele falha a Questão 4(f):

```
raízes MA (módulo): 1,2465 | 1,000034 | 1,000034
raízes AR (módulo): 1,1207 | 1,1207 | 8,8755
```

**Duas raízes MA sobre o círculo unitário — o polinômio não é invertível.** A Q4(f)
exige explicitamente que as raízes estejam *fora* do círculo. E as raízes AR em 1,12
deixam o modelo à beira da não-estacionariedade.

Some-se a isso que **dois dos seis coeficientes não são significantes**: `ar3`
(t = 1,007) e `ma2` (t = −0,448). Seis parâmetros, dois inúteis, e não-invertível.

**Este é o primeiro item de `output/tables/modelos_descartados.csv`** — o arquivo que
a Q5(d) exige e que ainda não existe. Motivo do descarte: falha de invertibilidade.

## AIC e BIC divergem — e isso é a Questão 4(e) inteira

| Modelo | AIC | BIC |
|---|---:|---:|
| ARIMA(1,1,0) | −365,68 | −359,30 |
| **ARIMA(1,1,1)** | −398,47 | **−388,89** ← BIC |
| ARIMA(3,1,3) | **−408,83** ← AIC | −386,48 |

`q4_selecao.csv` reporta **apenas o AIC**. A divergência existe e a resposta se escreve
sozinha: o BIC é consistente e escolhe o modelo parcimonioso; o AIC é eficiente para
previsão mas aqui seleciona um modelo que **viola a invertibilidade**. Como a Q4(f) é
restrição de admissibilidade, e não critério de ajuste, o (3,1,3) sai **independentemente
do AIC**.

O **ARIMA(1,1,1)** é o candidato defensável: raiz MA em **1,2174** (fora do círculo,
invertível), `ar1` = 0,2499 (t = 2,86) e `ma1` = −0,8214 (t = −19,4), ambos significantes.
O `ma1` fortemente negativo já sinaliza proximidade da sobrediferenciação — o que conversa
diretamente com a Questão 6.

## Os outliers são artefato de fim de semana

Curtose da diferença: **43,7**. Daí o Jarque-Bera de 16.603. A causa é visível:

| Data | Dia | Salto |
|---|---|---:|
| 2026-03-16 | segunda | **−82,4 bps** |
| 2026-03-21 | **sábado** | **+47,2 bps** |
| 2026-03-17 | terça | +37,5 bps |

**Uma variação de 47 pontos-base num sábado não é informação.** Não há pregão. É o
carregamento do último preço combinado com cotações rasas. E a mediana de \|diferença\|
é **1,02 bps** contra desvio-padrão de **9,15 bps**: a distribuição inteira é dominada
por um punhado de outliers de março.

Há ainda **23 diferenças exatamente nulas** em 180 (12,8%) — os dias sem negociação.

**Recomendação:** restringir a série a **dias de pregão**. A decisão é justificada por
evidência (o salto de sábado), entra na Questão 1(a) como tratamento de outliers, e
resolve de quebra o período sazonal: passa de `s = 7` (calendário) para `s = 5` (semana
útil), que é o único `s` com sentido econômico.

## O ARCH-LM confirma a ressalva metodológica — nos dados reais

Variância da diferença: **15,53 bps no primeiro terço → 1,80 bps no último**. Queda de
**8,6×** conforme a reunião se aproxima. É a Figura 8 de Kagan & Baiocchi, e é enorme.

E mesmo assim o **ARCH-LM dá p = 0,0669** — não rejeita a 5%.

Isso já estava previsto neste documento e agora está demonstrado em dado real: o ARCH-LM
procura *agrupamento* de volatilidade, não queda *determinística* ao longo do horizonte.
Rode-o porque a Q5(c) manda, e **acompanhe-o** da regressão de log(dif²) contra dias até
a reunião e do teste F entre metades. Sem isso, a Q5(c) reporta um não-resultado e perde
justamente o achado que liga o trabalho ao artigo.

## Previsão: resultado mais interessante do que o previsto

| Esquema | ARIMA | Passeio aleatório | Sazonal ingênuo |
|---|---:|---:|---:|
| Origem fixa, 24 passos (RMSE) | **0,02389** | 0,02816 | 0,02411 |
| Origem móvel, 1 passo (RMSE) | 0,02099 | **0,01959** | 0,03685 |

O ARIMA **vence** em múltiplos passos e **perde** em um passo. O teste limpo de martingale
é o de **um passo à frente**, e ali o passeio aleatório ganha — como a hipótese prevê.
A vitória em 24 passos é pequena em termos absolutos (4,3 bps de RMSE) e merece um
Diebold-Mariano antes de qualquer afirmação.

Cobertura do IC de 95%: **100%**, exatamente como previsto neste documento.

## Ainda pendente

- `output/tables/modelos_descartados.csv` — **exigido pela Q5(d)**, não existe.
- Q2(c): `D = 0` continua justificado por *"não foi imposta diferença sazonal"*.
- Q2(d): não abordada.
- Q4(d): convenção de contagem de `k` não documentada na saída (resposta: o R inclui σ̂²ₐ).
- Q4(e): `q4_selecao.csv` reporta só o AIC, escondendo a divergência.

---

# Questão 7 completa: Diebold-Mariano e PIT

Implementados em `R/08_previsao.R`, com a casa de estilo de `R/99_viz.R`.

## Q7(f) — Diebold-Mariano

| Comparação (esquema 2, h=1) | DM quadrático | p | DM absoluto | p |
|---|---:|---:|---:|---:|
| ARIMA(3,1,3) vs passeio aleatório | +0,278 | 0,783 | **+2,129** | **0,044** |
| ARIMA(3,1,3) vs sazonal ingênuo | **−3,361** | **0,003** | **−3,452** | **0,002** |

Sinal negativo = ARIMA com perda menor.

**Leitura.** Sob perda quadrática o teste **não rejeita** acurácia igual contra o
passeio aleatório (p = 0,78) — que é exatamente o que a hipótese de martingale
prevê. Sob perda absoluta o passeio aleatório é **significativamente melhor**
(p = 0,044). Contra o sazonal ingênuo o ARIMA vence com folga nos dois critérios,
o que confirma que não há sazonalidade semanal a explorar.

Escreva assim: *"não rejeito a hipótese de acurácia preditiva igual à do passeio
aleatório"* — inferência, não a observação frouxa de "meu modelo perdeu".

### Por que o Esquema 1 não recebe DM

O DM compara sequências de erros de **origens repetidas**. O Esquema 1 tem **uma
única origem**: seus 24 erros são um caminho só. Além disso, com `h = n` a correção
de Harvey, Leybourne e Newbold,

```
sqrt((n + 1 − 2h + h(h−1)/n)/n)  com n = h = 24  →  (25 − 48 + 23)/24 = 0
```

**zera exatamente**, e a variância de longo prazo de Newey-West com 23 defasagens
sobre 24 observações deixa de ser positiva. O script reporta "não aplicável" com a
justificativa em vez de imprimir um número degenerado. Isso é resposta, não lacuna.

## Q7(g) — cobertura e PIT

| Diagnóstico | Esquema 1 | Esquema 2 |
|---|---:|---:|
| Cobertura do IC 95% | **100,0%** | — |
| KS da PIT contra U(0,1): D | 0,402 | 0,323 |
| p-valor | **0,0005** | **0,0101** |

**Ambos rejeitam uniformidade.** O histograma de PIT (Figura 2) mostra uma
**corcova no centro**: quase toda a massa entre 0,3 e 0,7, caudas vazias. Essa é a
assinatura de densidades preditivas **superdispersas** — largas demais.

Isso confirma formalmente o que a cobertura de 100% já sugeria, e fecha o argumento
da Q5(c): os intervalos foram estimados sobre um período de variância alta e
aplicados a uma janela de validação de variância baixa. Não é falha do estimador; é
a heterocedasticidade da série vista pelo lado da densidade preditiva.

A cobertura é uma versão **fraca** do teste de PIT — ela olha só um quantil. O
arcabouço de Diebold, Gunther e Tay (1998) olha a distribuição inteira, e é o que os
próprios autores do FEDS aplicam na seção 6.1.

---

# Casa de estilo: `R/99_viz.R`

Rigor do Federal Reserve Board na apresentação, convenção brasileira na notação.

**Figuras.** `theme_feds()` reproduz o padrão do próprio código do Fed Board: em
`code/utilities.R` do replication package, as figuras usam moldura fechada e marcas
de escala **voltadas para dentro** (`par(tck = -0.02)`). Grade recessiva, sem enfeite.

**Notação.** Vírgula decimal e ponto de milhar (`fmt_br()`), rótulos em português,
legendas "Figura N — título" com bloco "Fonte:" obrigatório identificando o snapshot
congelado.

**Tabelas.** `tabela_coef()` entrega o padrão acadêmico: coeficiente com estrelas,
erro-padrão entre parênteses, estatística t e p-valor, tudo com vírgula decimal.
`nota_tabela()` gera a nota de rodapé.

**Paleta.** Validada pelo *six-checks* (superfície `#fcfcfb`, modo claro, pares
"all"):

| Verificação | Resultado |
|---|---|
| Faixa de luminosidade | PASSA (3 dentro de L 0,43–0,77) |
| Piso de croma | PASSA (3 ≥ 0,1) |
| Separação CVD | PASSA — pior par `#1baf7a`↔`#c0392b`, ΔE **12,8** (deuteranopia) |
| Piso de visão normal | PASSA — pior par ΔE **24,0** |
| Contraste vs. fundo | **ALERTA**: `#1baf7a` = 2,74 (< 3:1) |

O primeiro candidato, azul-marinho `#1b4b72` no espírito do FRB, **reprovou** em duas
checagens (fora da faixa de luminosidade, abaixo do piso de croma — lê como cinza).
Foi substituído por `#2a78d6`. A paleta final `#2a78d6 / #c0392b / #1baf7a` passa
tudo e tem separação CVD **melhor** que o padrão de referência (12,8 contra 9,2).

O alerta de contraste obriga **relevo**: a série aqua nunca aparece sozinha na cor —
há legenda, tipo de linha distinto e a tabela de métricas. Identidade nunca fica só
na cor: cada série tem cor **e** tipo de linha.

**Modo único.** O destino é PDF impresso, então a paleta é calibrada só para fundo
claro. É escolha declarada, não omissão.

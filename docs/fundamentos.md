# Fundamentos: a ideia do trabalho, o que os dois artigos fundam, e o cânone que falta

Documento de trabalho para discussão com o professor. Três partes:

1. **§1–§2** — a ideia geral do trabalho e o que cada artigo selecionado efetivamente
   funda, lido dos PDFs originais (FEDS 2026-010; Kagan & Baiocchi 2026).
2. **§3** — a crítica recebida ("estudar processos estocásticos", "usar modelos mais
   canônicos de séries temporais financeiras") traduzida em três afirmações precisas.
   Esta é a parte que muda o trabalho.
3. **§4–§6** — o cânone por camada, o que fazer com ele, e uma ordem de leitura.

Referências novas foram acrescentadas a `report/referencias.bib`.

---

## 1. A ideia geral, em uma página

**O objeto não é um preço.** É a esperança condicional risco-neutra do ponto médio da
faixa-alvo do FOMC para **uma** reunião (`KXFED-26JUL`), medida diariamente ao longo dos
180 dias que a antecedem — 181 observações.

A construção, em quatro passos (`R/01_build_series.R`, transcrito de Diercks-Katz-Wright):

1. Cada contrato `KXFED-<reunião>-T<strike>` paga \$1 se a taxa exceder o strike. O
   conjunto de strikes de uma reunião é, portanto, uma **função de sobrevivência**
   risco-neutra, `P(taxa > s)`, e não um conjunto de baldes disjuntos.
2. Diferenciar strikes adjacentes devolve a massa de cada balde; a monotonicidade é
   imposta *a partir da moda para as caudas* (o algoritmo `middle-out` do paper).
3. Normalizar para somar 1.
4. `E^Q_t[R_T] = Σ p_i·s_i + 0,125`, onde o `+0,125` é o ajuste de meio-balde que
   converte o limite inferior indexador na faixa-alvo efetiva.

**O que a Lista pede que se teste:** Box-Jenkins sobre essa série, com confronto contra
o passeio aleatório. **O que saiu:** `d = 1`, `D = 0` (com `s = 7` justificado pela
atividade de negociação nos sete dias), ARIMA(1,1,1) selecionado após excluir o
ARIMA(3,1,3) por não-invertibilidade, resíduos não-autocorrelacionados, não-normais,
variância caindo por um fator de 55,6 entre a primeira e a segunda metade da amostra,
Diebold-Mariano não rejeitando igualdade de acurácia contra o passeio aleatório,
vitória sobre o ingênuo sazonal, e PIT rejeitando uniformidade — densidades preditivas
largas demais.

**A frase que organiza tudo o que vem depois:** a série é a *esperança condicional de
uma variável que será revelada numa data conhecida*. Tudo o que o professor apontou
decorre de levar essa frase a sério.

---

## 2. O que cada artigo funda — e o que nenhum dos dois faz

### 2.1 Diercks, Katz & Wright (FEDS 2026-010) — o artigo de **medição**

É um paper de mensuração, não de modelagem de trajetória. O que ele estabelece:

| Contribuição | Onde | O que significa aqui |
|---|---|---|
| Contrato Kalshi = título de Arrow-Debreu | §2.1 | Justifica ler o conjunto de contratos como uma pdf risco-neutra completa, com "hipóteses mínimas" — a frase é deles. |
| Conversão preço → distribuição | §3 | Diferenciação de strikes adjacentes; monotonicidade imposta *da moda para fora* ("constructing the distribution outward from the mode toward the tails"); carregamento do último negócio em strikes sem negócio no dia; empates atribuídos ao desfecho mais próximo da moda. |
| Avaliação de ponto | §6, Tab. 3 | EAM/REQM contra futuros de fed funds e contra a Survey of Market Expectations, por dias até a reunião. Mediana e moda da Kalshi: registro perfeito na véspera do FOMC (EAM 0,000\*\*). |
| Avaliação de densidade | §6.1 | PIT + estatísticas K e C de Darling (1957) + bootstrap de Rossi & Sekhposyan (2019). É o precedente direto da Q7(g). |
| Estudos de evento | §7 | Δmomento contra surpresa de anúncio; variância cai em dias de notícia — "consistent with a general resolution of uncertainty". |
| Ressalva Q vs P | §3, *Caveats* | Explícita: "it is giving risk-neutral probabilities under the Q measure, not actual physical probabilities... the probabilities may be distorted by risk premia", e a base retail "might alter the risk premia properties". |
| Último negócio > ponto médio bid/ask | Apêndice A | Já replicado em `tests/replica_apendice_a.R`. |

**O que ele não faz:** nenhum modelo de série temporal da trajetória. Sem raiz unitária,
sem ARIMA, sem teste de martingale ou passeio aleatório. A §4, intitulada "Time-Series
Comparisons", é descritiva e visual. A avaliação preditiva da §6 é **entre reuniões a um
horizonte fixo**, não **dentro de um contrato ao longo do seu caminho**.

### 2.2 Kagan & Baiocchi (2026) — o artigo da **hipótese**

| Contribuição | Onde | O que significa aqui |
|---|---|---|
| Calibração em escala | §4 | 2.243.741 mercados resolvidos, 11 categorias, 2021–meados de 2026. Brier cai de ~0,087 (3 meses) para <0,02 no fechamento. |
| A ponte teórica | §2.2 | Propriedade de *propriety* (Gneiting & Raftery, 2007): uma regra de escore própria torna o relato honesto ótimo, e um contrato com payoff vinculado *funciona como* uma. É isto que liga calibração (estatística) a eficiência (economia). |
| A justificativa probabilística | §3.3 | **A Lei dos Grandes Números, explicitamente.** "Probability is only testable through repetition." |
| *Economics* | §4.3.2 | 16.701 mercados; Brier 0,108 → 0,066; **a única categoria monótona**, porque resolve contra um anúncio pré-agendado e inequívoco. |
| Ressalva de Manski | §2.2 | Preço não é crença média sem hipóteses sobre preferências; Gjerstad (2004) e Wolfers & Zitzewitz (2006) dão condições suficientes. |

**O que ele não faz — e admite não fazer:** o argumento da LGN é **transversal por
construção**. Agregar sobre mercados nada diz sobre o caminho de um mercado. A própria
§6 deles levanta como questão aberta nº 2: *"Markets are well calibrated, but through
what mechanism?"* — e a pergunta do mecanismo é intra-mercado, isto é, de série temporal.

### 2.3 A brecha, dita com precisão

Ambos avaliam o **nível** da previsão contra o **desfecho realizado**. Nenhum avalia os
**incrementos** de um mercado contra o próprio passado. A brecha existe.

Mas é exatamente aí que a crítica do professor morde: **o instrumento que a Lista manda
usar (Box-Jenkins) não é o instrumento canônico para essa brecha.**

---

## 3. A crítica do professor, traduzida em três afirmações

### 3.1 "Processos estocásticos": o martingale aqui é **teorema**, não hipótese

Esta é a correção mais importante, e é de enquadramento, não de código.

Dois resultados clássicos, combinados:

- **Teorema fundamental do apreçamento** (Harrison & Kreps, 1979; Harrison & Pliska,
  1981; Delbaen & Schachermayer, 1994): ausência de arbitragem equivale à existência de
  uma medida equivalente `Q` sob a qual preços descontados são martingales.
- **Propriedade da torre** (esperanças iteradas; Doob, 1953): se `X_t = E[Y | F_t]` para
  um `Y` terminal fixo e uma filtração `F_t`, então `(X_t)` **é** um martingale,
  automaticamente:

  ```
  E[X_t | F_s] = E[ E[Y | F_t] | F_s ] = E[Y | F_s] = X_s,   s < t.
  ```

Como a série é `E^Q_t[R_T]` por construção, ela é um `Q`-martingale **por aritmética**.
Encontrar que ela é I(1) e que nenhum ARIMA supera o passeio aleatório **não é evidência
a favor da eficiência do mercado** — é a lei das esperanças iteradas aparecendo nos
dados. Escrever "a hipótese de martingale é confirmada" inverte o estatuto lógico do
resultado.

Dois corolários que valem parágrafo no relatório:

**(a) O desconto, e por que ele não contamina esta série.** A Kalshi exige colateral
integral e não paga juros sobre a margem. O preço de um contrato individual é, então,
`e^{-r(T-t)}·E^Q[Θ|F_t]` — um *sub*martingale com deriva determinística, não um
martingale. Page & Clemen (2013) atribuem parte do viés favorito-azarão exatamente a
esse desconto temporal de um payoff distante; a 180 dias e ~4–5% ao ano o efeito é de
ordem 2%, nada desprezível para uma probabilidade. **Mas a normalização (`Σ p_i = 1`)
divide o fator de desconto comum para fora da média.** A série de taxa esperada é imune,
e a normalização deixa de ser passo cosmético para ter papel substantivo. Uma frase na
§2 do relatório resolve.

**(b) O que de fato quebra a martingalidade não é o mercado — é a construção.** O
`middle-out` e o truncamento de massa negativa em zero são funções **não-lineares** dos
preços, e `E_t[f(p_{t+1})] ≠ f(E_t[p_{t+1}])`. Qualquer desvio mensurável de
martingalidade pode ser do algoritmo, não do mercado. Isto pede um teste de robustez
(§5.6).

**O que resta empiricamente testável** — e é bastante:

- a propriedade de **diferença-martingale** (MDS), `E[Δx_t | F_{t-1}] = 0`, da série
  **observada**: negociada em grade de 1 centavo, com spread, com taxas, em livro raso;
- a **cunha Q vs P**, que é uma questão empírica, não uma ressalva retórica (§5.5).

### 3.2 "Modelos mais canônicos": a taxonomia RW1 / RW2 / RW3

Campbell, Lo & MacKinlay (1997), cap. 2, é a referência canônica e resolve a confusão de
vocabulário do relatório:

| | Hipótese | O que supõe dos incrementos |
|---|---|---|
| **RW1** | passeio aleatório iid | independentes e **identicamente distribuídos** |
| **RW2** | passeio aleatório | independentes, **não** identicamente distribuídos |
| **RW3** | passeio aleatório com incrementos não-correlacionados | apenas **não-correlacionados** |

O martingale (mais precisamente, a MDS) fica **entre** RW2 e RW3: mais forte que
não-correlação, mais fraco que independência.

Consequências diretas:

1. **RW1 é falsa por construção nesta série.** A variância dos incrementos cai por 55,6×.
   O relatório documenta isso na Q5 e o trata como estorvo de diagnóstico; é, na verdade,
   uma afirmação sobre *qual nula está em teste*.
2. **Box-Jenkins testa apenas RW3**, a mais fraca — dependência **linear**, via FAC. A
   hipótese de martingale é sobre a média condicional dado *todo* o conjunto de
   informação.
3. **Sob heterocedasticidade forte, Ljung-Box e a razão de variâncias padrão
   sobre-rejeitam.** O "não rejeita" da Q5 é tranquilizador, mas a convenção de erro
   padrão importa. A correção canônica é usar versões robustas:
   - Lo & MacKinlay (1988), estatística `z*` consistente sob heterocedasticidade;
   - Escanciano & Lobato (2009), portmanteau automático, explicitamente "robust to the
     presence of conditional heteroskedasticity of unknown form";
   - Kim (2009), razão de variâncias automática com *wild bootstrap*.

   As três estão no pacote **`vrtest`** do CRAN (*Variance Ratio Tests and Other Tests
   for Martingale Difference Hypothesis*), mantido pelo próprio Kim. É R puro, roda em
   vinte linhas.
4. **O Diebold-Mariano contra o passeio aleatório é comparação de acurácia, não teste de
   eficiência** — e o relatório já reconhece que tem pouca potência na cauda calma da
   amostra. Os testes de razão de variâncias usam a amostra inteira e miram a nula certa.

### 3.3 A variância não é estorvo: é a estrutura do objeto

A série é a esperança condicional de uma variável revelada numa data **conhecida**. Pela
decomposição da variância total,

```
Var(R_T) = E[ Var(R_T | F_t) ] + Var( E[R_T | F_t] ),
```

e, ao longo do caminho, a variação quadrática realizada do martingale **telescopa**: a
soma dos incrementos ao quadrado sobre `[0, T]` tem de igualar a incerteza inicial. Isso
é uma **restrição testável ligando o nível de incerteza inicial à trajetória de
volatilidade realizada** — e é o que distingue este objeto de uma ação.

Logo, a variância declinante não é heterocedasticidade a ser diagnosticada e descartada:
é **resolução de incerteza**, e tem cânone próprio — Patell & Wolfson (1979, 1981) sobre
volatilidade implícita colapsando em torno de anúncios agendados; Ederington & Lee (1993)
sobre o efeito de anúncios macro na volatilidade; Beber & Brandt (2006), citado pelo
próprio FEDS; e Wright, *Event-day options* (a sair, *Journal of Time Series Analysis*),
listado na bibliografia do FEDS, que é o tratamento mais próximo de opções cujo
subjacente resolve em data conhecida.

**Consequência prática, e é a mais rentável do documento:** o modelo canônico não é ARIMA
com `σ²` constante, e sim um **martingale com cronograma determinístico de variância** —
um modelo local-level em espaço de estados com `σ²_t = g(τ_t)`, `τ_t` = dias até a
reunião, estimado por filtro de Kalman (Harvey, 1989; Durbin & Koopman, 2012).

E isto **conserta a rejeição de PIT que o relatório já documenta**. O relatório diz, com
todas as letras, que as densidades preditivas são largas demais porque `σ²` foi estimado
numa amostra que inclui a turbulência de março e aplicado a um trecho calmo. Isso não é
uma limitação a lamentar na conclusão: é um **erro de especificação com remédio
canônico**.

---

## 4. O cânone, por camada

Marcação de estrato: **T5** = *top-5* de economia (AER, ECMA, JPE, QJE, REStud); **Q1F** =
Q1 de finanças (JF, JFE, RFS); **Q1** = Q1 da área; **HB** = capítulo de *Handbook*;
**REF** = referência-livro.

### (A) Processos estocásticos e a medida Q — *o que o professor mandou estudar*

| Referência | Veículo | Por que |
|---|---|---|
| Doob (1953), *Stochastic Processes* | REF | Martingale, propriedade da torre, teoremas de parada opcional. A fonte. |
| Harrison & Kreps (1979) | *J. Economic Theory* · Q1 | Ausência de arbitragem ⟺ medida martingale equivalente. Funda o "Q". |
| Harrison & Pliska (1981) | *Stochastic Processes Appl.* · Q1 | A versão que virou padrão. |
| Delbaen & Schachermayer (1994) | *Mathematische Annalen* · Q1 | Versão geral do teorema fundamental. |
| Williams (1991), *Probability with Martingales* | REF | O caminho mais curto para ler os itens acima. Cabe num mês. |

### (B) A hipótese de eficiência e sua taxonomia

| Referência | Veículo | Por que |
|---|---|---|
| Samuelson (1965) | *Industrial Management Review* | "Proof that properly anticipated prices fluctuate randomly". O argumento de 3.1, na origem. |
| Mandelbrot (1966) | *J. Business* · Q1 | A formulação martingale, contemporânea de Samuelson. |
| LeRoy (1989) | *J. Economic Literature* · T5-adj | **A resenha que separa martingale de passeio aleatório.** Se ler só uma coisa desta seção, leia esta. |
| Fama (1970, 1991) | *J. Finance* · Q1F | As duas resenhas canônicas; a de 1991 já incorpora a crítica de hipótese conjunta. |
| Campbell, Lo & MacKinlay (1997), cap. 2 | REF | A taxonomia RW1/RW2/RW3 da §3.2. **Leitura obrigatória para este trabalho.** |

### (C) Testes canônicos da hipótese de martingale — *o instrumento que falta*

| Referência | Veículo | Por que |
|---|---|---|
| Lo & MacKinlay (1988), RFS 1(1), 41–66 | *Rev. Financial Studies* · Q1F | A razão de variâncias, com teoria assintótica e a variante consistente sob heterocedasticidade. |
| Escanciano & Lobato (2009), 151(2), 140–149 | *J. Econometrics* · Q1 | Portmanteau automático: escolhe a defasagem sozinho, robusto a heterocedasticidade condicional de forma desconhecida. |
| Kim (2009), 6(3), 179–185 | *Finance Research Letters* · Q1 | Razão de variâncias automática com *wild bootstrap*. Implementada em `vrtest`. |
| Chow & Denning (1993) | *J. Econometrics* · Q1 | Razão de variâncias **múltipla** — corrige o problema de testar vários horizontes. |
| Wright (2000) | *J. Business & Econ. Statistics* · Q1 | Versões por postos e sinais; exatas em amostra pequena. Relevante com n = 180. |
| Charles & Darné (2009), 23(3), 503–527 | *J. Economic Surveys* · Q1 | Resenha operacional de toda a família. O atalho para escolher qual usar. |

### (D) Microestrutura — *o MA(1) negativo*

| Referência | Veículo | Por que |
|---|---|---|
| **Roll (1984)**, JF 39(4), 1127–1139 | *J. Finance* · Q1F | **A referência canônica do bid-ask bounce.** `cov(Δp_t, Δp_{t-1}) = −s²/4`, logo `ŝ = 2√(−γ̂₁)`. Transforma a asserção da Q3 em medição — ver §5.3. |
| Glosten & Milgrom (1985) | *J. Financial Economics* · Q1F | Spread como seleção adversa. |
| Kyle (1985) | *Econometrica* · T5 | Liquidez e informação; a outra metade do arcabouço. |
| Hasbrouck (2007), *Empirical Market Microstructure* | REF | Como estimar tudo isso na prática. |

### (E) Expectativas de política monetária e o prêmio de risco — *a cunha Q vs P*

| Referência | Veículo | Por que |
|---|---|---|
| Krueger & Kuttner (1996), 16(8), 865–879 | *J. Futures Markets* · Q1 | **O precedente direto:** teste de eficiência do futuro de fed funds como previsor da política. É o antecessor exato deste trabalho, com outro instrumento. |
| Kuttner (2001) | *J. Monetary Economics* · Q1 | Decomposição surpresa/esperado. Já está no `.bib`. |
| **Piazzesi & Swanson (2008)**, 55(4), 677–691 | *J. Monetary Economics* · Q1 | **Prêmio de risco em futuros de fed funds é grande, variável no tempo e previsível por variáveis macro.** É a referência que dá conteúdo empírico à ressalva Q vs P. |
| Gürkaynak, Sack & Swanson (2005) | *Int. J. Central Banking* · Q1 | Medidas de expectativa de política baseadas em mercado. Citado pelo FEDS. |
| Söderlind & Svensson (1997) | *J. Monetary Economics* · Q1 | Extração de expectativas de instrumentos financeiros — a resenha metodológica. |
| Breeden & Litzenberger (1978) | *J. Business* · Q1 | Densidade de estado a partir de preços de opções. O ancestral do passo de diferenciação do `01`. |
| Emmons, Lakdawala & Neely (2006) | *FRB St. Louis Review* | Distribuição da taxa-alvo a partir de opções. Já mapeado em `literatura.md`. |

### (F) Mercados de previsão — teoria e evidência

| Referência | Veículo | Por que |
|---|---|---|
| Wolfers & Zitzewitz (2004), 18(2), 107–126 | *J. Economic Perspectives* · Q1 | A resenha de entrada. |
| Wolfers & Zitzewitz (2006), NBER WP 12200 | WP | *Interpreting prediction market prices as probabilities* — condições sob as quais preço = crença média. |
| **Manski (2006)**, 91(3) | *Economics Letters* · Q1 | Preço **não** é probabilidade sem hipóteses. Está nas duas bibliografias. |
| **Ottaviani & Sørensen (2015)**, AER 105(1), 1–34 | *American Economic Review* · **T5** | **Sub-reação com crenças heterogêneas e efeitos-riqueza: momento e depois reversão.** Dá *teoria* ao teste de §5.5, e prevê o sinal do coeficiente. |
| Ottaviani & Sørensen (2007), 5(2-3) | *J. European Econ. Association* · Q1 | Manipulação de desfecho. |
| Hanson (2003) | *Information Systems Frontiers* | Regra de escore de mercado (LMSR); o desenho de mecanismo por trás. |
| Berg, Nelson & Rietz (2008), 24(2), 285–300 | *Int. J. Forecasting* · Q1 | IEM bate pesquisas eleitorais em 74% das comparações, inclusive a >100 dias. |
| Snowberg & Wolfers (2010) | *J. Political Economy* · **T5** | Favorito-azarão: aversão ao risco ou percepção equivocada. |
| Page & Clemen (2013), 123(568) | *Economic Journal* · Q1 | Calibração **decai com o horizonte** por desconto temporal — o mecanismo do corolário (a) de §3.1. |

### (G) Consenso — agregação, combinação e rigidez informacional

O professor mencionou "consenso" ao lado de "mercado de previsão"; no FEDS, *consensus* é
a Bloomberg/SME, isto é, expectativa de survey. A camada é esta:

| Referência | Veículo | Por que |
|---|---|---|
| Hayek (1945), 35(4) | *American Economic Review* · **T5** | O argumento de agregação, na origem. Kagan & Baiocchi abrem com ele. |
| Bates & Granger (1969), 20(4) | *Operational Research Quarterly* | Combinação de previsões. O ponto de partida de tudo. |
| Timmermann (2006), *Handbook of Econ. Forecasting*, v.1, cap. 4 | HB | *Forecast combinations* — a resenha definitiva. |
| Genest & Zidek (1986) | *Statistical Science* · Q1 | Agregação de opiniões probabilísticas: o análogo bayesiano. |
| **Coibion & Gorodnichenko (2015)**, AER 105(8), 2644–2678 | *American Economic Review* · **T5** | **O teste canônico de eficiência de uma previsão de consenso: erro *ex post* contra revisão *ex ante*.** Aplica-se diretamente a esta série — ver §5.5. |
| Coibion & Gorodnichenko (2012) | *J. Political Economy* · **T5** | A versão anterior, sobre rigidez informacional em surveys. |
| Manski (2004) | *Econometrica* · **T5** | *Measuring expectations* — o que significa medir uma expectativa. |
| Zarnowitz & Lambros (1987) | *J. Political Economy* · **T5** | Discordância ≠ incerteza. Distinção relevante ao ler a dispersão da pdf da Kalshi. |

### (H) Avaliação de previsão

| Referência | Veículo | Por que |
|---|---|---|
| Diebold & Mariano (1995), 13, 253–263 | *J. Business & Econ. Statistics* · Q1 | Já adotado na Q7(f). |
| Harvey, Leybourne & Newbold (1997), 13(2) | *Int. J. Forecasting* · Q1 | Correção de amostra pequena. Já adotada. |
| **Giacomini & White (2006)**, 74(6), 1545–1578 | *Econometrica* · **T5** | Acurácia preditiva **condicional**. É o teste certo quando a habilidade relativa varia com o estado — e aqui varia com `τ`. Ver §5.2. |
| Clark & West (2007) | *J. Econometrics* · Q1 | DM é enviesado para modelos **aninhados**; ARIMA(1,1,1) contra passeio aleatório **é** um par aninhado. Correção pertinente à Q7(f). |
| Diebold, Gunther & Tay (1998), 39, 863–883 | *Int. Economic Review* · Q1 | PIT. Já adotado. |
| Rossi & Sekhposyan (2019), 208 | *J. Econometrics* · Q1 | Bootstrap para a uniformidade da PIT — é o que o FEDS §6.1 usa. |
| Gneiting & Raftery (2007), 102(477) | *J. American Statistical Assoc.* · Q1 | Regras de escore próprias. A ponte teórica de Kagan & Baiocchi. |
| Gneiting, Balabdaoui & Raftery (2007), 69(2) | *JRSS-B* · Q1 | "Maximizar a nitidez sujeito à calibração" — o princípio que Kagan & Baiocchi invocam. |

---

## 5. O que muda no trabalho, em ordem de retorno

### 5.1 Reenquadrar: de "é passeio aleatório?" para "vale a MDS?" — custo zero

Um parágrafo na §1 do relatório e uma frase na conclusão. O martingale sob `Q` é
consequência da torre (§3.1), não achado empírico; o que se testa é a MDS da série
**observada**, com todas as fricções, e é isso que dá conteúdo ao exercício. Sem essa
correção, o resultado principal está descrito com o estatuto lógico invertido — e é
exatamente o que um leitor treinado em processos estocásticos vai apontar primeiro.

### 5.2 Testes de razão de variâncias robustos — alto retorno, ~20 linhas de R

```r
install.packages("vrtest")
library(vrtest)
dx <- diff(serie$taxa_esperada)
Lo.Mac(dx, kvec = c(2, 5, 10, 20))   # z e z* (robusto a heterocedasticidade)
Auto.VR(dx)                           # razão de variâncias automática (Kim 2009)
AutoBoot.test(dx, nboot = 5000, wild = "Normal")
Auto.Q(dx)                            # portmanteau automático (Escanciano-Lobato 2009)
```

Entra na Q2 (como complemento aos testes de raiz unitária, que testam `d`, não MDS) e na
Q7 (como o teste de eficiência que o DM não é). Reportar `z` e `z*` lado a lado é
didático: com queda de variância de 55,6×, a diferença entre eles é o ponto.

Acrescentar também **Giacomini & White (2006)** e/ou **Clark & West (2007)** na Q7(f):
o par ARIMA(1,1,1) × passeio aleatório é **aninhado**, e o DM padrão é enviesado nesse
caso — uma ressalva que hoje falta.

### 5.3 Roll (1984): medir o spread implícito no MA(1) — o item mais original disponível

O relatório afirma, na Q3, que o coeficiente MA(1) negativo é microestrutura e não
previsibilidade econômica. Hoje isso é **asserção**. Roll (1984) a torna **medição**:

```
γ̂₁ = cov(Δp_t, Δp_{t−1}) = −s²/4   ⟹   ŝ = 2·√(−γ̂₁)
```

E o snapshot **tem** bid/ask — `literatura.md` registra que bid e ask existem em 99,5%
das células dia×strike, contra 21% de `yes_close`. Então dá para comparar o spread
*implícito* pelo MA(1) com o spread *observado* no livro. Se baterem em ordem de
grandeza, a atribuição a bid-ask bounce deixa de ser retórica e passa a ser um resultado
— e é um resultado que nenhum dos dois artigos de referência tem.

Cabe na Q3(b) e reaparece na Q5. É barato e é o achado com maior chance de impressionar.

### 5.4 Cronograma determinístico de variância — conserta a PIT

Modelo local-level em espaço de estados com variância de observação/estado função de
`τ_t` (dias até a reunião):

```
x_t = x_{t−1} + η_t,   η_t ~ N(0, σ²_η · g(τ_t)),    g(τ) = exp(a + b·τ)
```

estimado por filtro de Kalman (`KFAS` ou `dlm` em R; Harvey 1989; Durbin & Koopman 2012).
O relatório já **diagnosticou** o problema — densidades preditivas largas demais porque
`σ²` foi estimado com março dentro e aplicado à cauda calma. Isto é o remédio, e é
canônico. Entra na Q6/Q7 como especificação alternativa; a comparação de PIT entre
ARIMA(1,1,1) e local-level com cronograma de variância é, sozinha, uma seção forte.

### 5.5 Q vs P: transformar a ressalva obrigatória em resultado

Hoje a conclusão traz a ressalva Q vs P como advertência retórica. Ela pode virar
exercício, com dois passos canônicos:

1. **Piazzesi & Swanson (2008)** mostram que o prêmio de risco em futuros de fed funds é
   grande, variável no tempo e **previsível** por variáveis macro. O desenho deles
   transporta: regredir o erro de previsão realizado sobre variáveis conhecidas *ex ante*.
   Coeficiente nulo ⟹ a cunha é constante e o martingale sobrevive a menos de deriva;
   coeficiente não-nulo ⟹ a série é previsível sob `P`.
2. **Coibion & Gorodnichenko (2015)** dão a forma canônica para uma previsão de consenso:

   ```
   (R_T − E_t[R_T])  =  α + β · (E_t[R_T] − E_{t−h}[R_T])  +  u_t
   ```

   `β > 0` é sub-reação — rigidez informacional. E **Ottaviani & Sørensen (2015, AER)**
   preveem exatamente sub-reação em mercados binários com crenças heterogêneas e efeitos
   riqueza, seguida de reversão. Teoria (T5) → teste (T5) → dados desta série. É o desenho
   mais defensável que o material comporta, e é literalmente "modelo canônico de mercado
   de previsão e consenso".

   Ressalva honesta: com **uma** reunião há um só erro terminal, então esta regressão
   exige o painel de reuniões, não a série única. O snapshot tem 98 mercados — dá.
   Vale como extensão declarada, ou como a Questão 8.

### 5.6 Robustez: quanto da não-martingalidade é do algoritmo?

Reconstruir a série **sem** o `middle-out` e sem truncamento de massa negativa, e repetir
os testes de §5.2. Se os resultados mudarem, o `middle-out` — que é uma transformação
não-linear dos preços (§3.1b) — está gerando parte da estrutura medida. É um controle que
o próprio FEDS não faz, e o custo é uma flag no `01_build_series.R`.

---

## 6. Ordem de leitura

Se ler oito coisas antes de falar com o professor de novo, leia estas, nesta ordem:

1. **Campbell, Lo & MacKinlay (1997), cap. 2** — RW1/RW2/RW3. Resolve o vocabulário.
2. **LeRoy (1989), JEL** — martingale ≠ passeio aleatório; por que a distinção importa.
3. **Samuelson (1965)** — oito páginas; o argumento da torre na origem.
4. **Lo & MacKinlay (1988), RFS** — a razão de variâncias e a versão robusta.
5. **Roll (1984), JF** — cinco páginas; o spread implícito. Vira seção nova (§5.3).
6. **Piazzesi & Swanson (2008), JME** — a cunha Q vs P com conteúdo empírico.
7. **Coibion & Gorodnichenko (2015), AER** — o teste canônico de eficiência de consenso.
8. **Ottaviani & Sørensen (2015), AER** — a teoria que prevê o sinal do item 7.

Itens 1–3 são o "estudar processos estocásticos". Itens 4–5 são o "usar modelos mais
canônicos de séries temporais financeiras". Itens 6–8 são o "mercado de previsão e
consenso".

---

## 7. Nota sobre bases bibliográficas

O levantamento acima foi feito com Scholar Gateway (corpus de texto completo), busca em
índice de papers (arXiv/PubMed) e busca web, com cada referência conferida em fonte
primária ou no registro do periódico — veículo, volume, número e páginas.

**Não há acesso a Scopus nesta sessão.** Scopus é produto Elsevier sob assinatura, e não
há conector instalado nem disponível no registro. Duas observações práticas:

- Para o recorte por estrato (Q1/T5), a base não é o gargalo: em economia o conjunto
  relevante é conhecido e curto, e a coluna "Veículo" das tabelas da §4 já faz esse
  trabalho, referência a referência.
- Se quiser o recorte formal — CiteScore, SJR, quartil por área, contagem de citações —
  a UFES tem acesso a Scopus e a Web of Science pelo **Portal de Periódicos CAPES**
  (login institucional). Vale rodar lá duas buscas: `"prediction market" AND
  ("martingale" OR "variance ratio")` e `"prediction market" AND "federal funds"`,
  filtrando por *Economics, Econometrics and Finance*, quartil Q1, 2004–2026. Se trouxer
  o resultado, incorporo aqui.

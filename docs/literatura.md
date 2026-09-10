# Literatura: o que reproduzir e quais boas práticas adotar

Levantamento a partir das **bibliografias completas** dos dois artigos enviados,
cruzadas com busca no arXiv. O objetivo é duplo: alinhar o trabalho às práticas
da literatura e satisfazer a Lista 01 com instrumentos que a literatura usa.

---

## 1. O que já reproduzimos

### Apêndice A do FEDS 2026-010 — `tests/replica_apendice_a.R`

Os autores comparam o erro de previsão da taxa esperada construída pelo **último
negócio** contra a construída pelo **ponto médio bid/ask**, medido contra o
**desfecho realizado**. Conclusão deles: *"the forecast errors spike quite a bit
more [com o mid] ... we maintain focus on the last trade for our main results."*

Replicado no `KXFED-26JUL` (contrato já resolvido, desfecho **3,625%**, massa 0,827
no balde vencedor), amostra balanceada de 336 datas:

| Janela | n | EAM último negócio | EAM mid | Melhor |
|---|---:|---:|---:|---|
| **>160d** | 175 | **0,2582** | 0,3563 | último |
| 120–160d | 41 | 0,2535 | **0,2438** | mid |
| 90–120d | 30 | 0,0979 | **0,0945** | mid |
| 60–90d | 30 | **0,0146** | 0,0186 | último |
| 30–60d | 30 | 0,0384 | **0,0302** | mid |
| 7–30d | 23 | 0,0331 | **0,0330** | mid |
| 0–7d | 7 | **0,0590** | 0,0613 | último |
| **Global** | 336 | **0,1824** | 0,2316 | último (t = −10,11; p < 0,0001) |

**A conclusão do paper se confirma, e o mecanismo fica visível:** a vantagem do
último negócio se concentra nos **horizontes longos**, onde o livro é raso e o
spread largo puxa o `mid` para o centro da escada de strikes. Dentro da janela de
180 dias que a análise usa, as duas ficam próximas e o `mid` até ganha em 4 de 6
faixas.

Isto corrige um erro meu anterior: eu defendi o `mid` por **suavidade** (menor
desvio-padrão, menor curtose, AC(1) menos negativo). Suavidade não é acurácia —
uma série mais suave pode ser mais viesada. O critério do paper, erro contra o
desfecho realizado, é o correto, e só é computável num contrato **já resolvido**.

Achado colateral: no painel de candlesticks o `yes_close` está **ausente em 79%**
das células (dia × strike), enquanto bid/ask existem em 99,5%. E o `mid` degenera
em exatamente 0,5 quando o livro está vazio (`bid = 0`, `ask = 1`) — 0,2% das
linhas, concentradas no último dia. O script descarta essas linhas.

---

## 2. Bibliografia do FEDS 2026-010 — o que é diretamente aplicável à Lista

### Avaliação preditiva (Questão 7)
- **Diebold, F. X. & Mariano, R. S. (1995).** "Comparing predictive accuracy."
  *JBES* 13, 253–263. — **Adotar na Q7(f).** É o teste canônico para dizer se a
  diferença de RMSE entre o ARIMA e o passeio aleatório é estatisticamente
  significante. Sem ele, "não superou o benchmark" é observação; com ele, é
  inferência.
- **Diebold, F. X., Gunther, T. A. & Tay, A. S. (1998).** "Evaluating density
  forecasts." *IER* 39, 863–883. — A **transformada integral de probabilidade
  (PIT)**. O FEDS 2026-010 tem uma seção inteira (6.1) aplicando-a. **Relevante à
  Q7(g):** a cobertura empírica do IC de 95% é uma versão fraca do teste de PIT.
  Reportar o histograma de PIT eleva a resposta.
- **Darling, D. A. (1957).** Kolmogorov-Smirnov e Cramér-von Mises. — Testes de
  uniformidade da PIT.
- **Rossi, B. & Sekhposyan, T. (2019).** "Alternative tests for correct
  specification of conditional predictive densities." *J. Econometrics* 208.
- **Clements, M. P. (2018).** "Are macroeconomic density forecasts informative?"
  *IJF* 34(2).

### Precedente direto da série
- **Emmons, W. R., Lakdawala, A. K. & Neely, C. J. (2006).** "What are the odds?
  Option-based forecasts of FOMC target changes." *FRB St. Louis Review* 88. — O
  precedente clássico: extrair distribuição da taxa-alvo de opções. A Kalshi faz o
  mesmo com contratos binários.
- **Gürkaynak, R. S. & Wolfers, J. (2005).** "Macroeconomic derivatives."
- **Wright, J. H. (2018).** "Options-implied probability density functions for real
  interest rates." *IJCB* 12.
- **Kitsul, Y. & Wright, J. H. (2013).** "The economics of options-implied inflation
  probability density functions." *JFE* 110(3).
- **Duffee, G. R. (2012).** "Forecasting interest rates." *Handbook of Economic
  Forecasting* vol. 2.

### Prêmio de risco — a ressalva da conclusão
- **Manski, C. F. (2006).** "Interpreting the predictions of prediction markets."
  *Economics Letters* 91(3). — **Aparece nas duas bibliografias.** É a referência
  para dizer que preço não é probabilidade sem hipóteses adicionais.
- **Snowberg, E. & Wolfers, J. (2010).** "Explaining the favorite-longshot bias:
  is it risk-love or misperceptions?" *JPE* 118(4).
- **Burgi, C., Deng, W. & Whelan, K. (2025).** "Makers and takers: the economics of
  the Kalshi prediction market."

---

## 3. Bibliografia de Kagan & Baiocchi — o arcabouço de calibração

- **Brier, G. W. (1950).** *Monthly Weather Review* 78(1). — O escore.
- **Dawid, A. P. (1982).** "The well-calibrated Bayesian." *JASA* 77(379).
- **DeGroot, M. H. & Fienberg, S. E. (1983).** "The comparison and evaluation of
  forecasters." *The Statistician* 32.
- **Murphy, A. H. & Winkler, R. L. (1987).** "A general framework for forecast
  verification." *Monthly Weather Review*.
- **Gneiting, T. & Raftery, A. E. (2007).** "Strictly proper scoring rules."
- **Gneiting, T., Balabdaoui, F. & Raftery, A. E. (2007).** "Probabilistic
  forecasts, calibration and sharpness."
- **Page, L. & Clemen, R. T. (2013).** "Do prediction markets produce
  well-calibrated probability forecasts?" *Economic Journal* 123(568).
- **Wolfers, J. & Zitzewitz, E. (2004).** "Prediction markets." *JEP* 18(2).
- **Hayek, F. A. (1945).** "The use of knowledge in society." *AER* 35(4).

---

## 4. arXiv: o que saiu recentemente e muda o trabalho

### `arXiv:2607.08199` — Xi, Moallemi, Pai & Wang (Columbia), *Volatility in Prediction Markets: A Structural Approach*

**O achado mais importante desta busca.** Duas contribuições que entram direto no
relatório:

**(a) Formaliza a nossa hipótese.** Com `p_t = P(Θ=1 | F_t) = E[Θ | F_t]`, os autores
escrevem: *"By the tower property, (p_t) is a bounded F_t-martingale, and terminal
settlement reveals the true state, so p_T = Θ ∈ {0,1}."* É exatamente o argumento
da lei das expectativas iteradas, publicado e citável — **sob a medida risco-neutra**,
o que também sustenta a ressalva Q vs P.

**(b) Diz que ARCH/GARCH é a ferramenta errada aqui, e por quê.** *"ARCH and GARCH
models are natural workhorses ... in ordinary financial assets, where prices are
positive-valued stochastic processes. A prediction-market contract instead has a
price that is a bounded probability, a payoff that is binary, and a resolution date
that is known in advance."* Empiricamente: *"Plain ARCH/GARCH benchmarks are
dominated by structural specifications."*

O modelo estrutural deles decompõe a variância condicional em dois canais:

```
h²_t = p_t(1 − p_t)/τ_t   +   K · ν(V_t) · s²_t/4
       └ resolução no prazo ┘   └ seleção adversa ┘
```

O primeiro termo (Wright-Fisher) diz que a incerteza binária remanescente
`p(1−p)` é liberada ao longo do tempo restante `τ`. O segundo (Glosten-Milgrom)
liga spread e volume à variância de seleção adversa.

**Consequência para a Q5(c):** nosso ARCH-LM deu p = 0,0669 apesar de a variância
cair 8,6× ao longo da amostra. Eu havia atribuído isso a o ARCH-LM procurar
*agrupamento* em vez de queda determinística. Este artigo **publica** essa crítica e
dá a alternativa. Rode o ARCH-LM porque a Q5(c) exige, e acompanhe de: (i) regressão
de `log(dif²)` contra dias até a reunião; (ii) o termo `p(1−p)/τ` como covariável.
Citar 2607.08199 transforma a ressalva em argumento de literatura.

Nota de precisão: eles observam que *"volatility ... rises near resolution"* para a
**probabilidade** de um contrato individual, porque `τ → 0`. A nossa série é a **taxa
esperada** (média ponderada entre strikes), cuja variância cai porque `p → 0` ou `1`
domina. São objetos diferentes; não confundir os dois no relatório.

Detalhe útil: *"Economics contracts are closer to smooth deadline-resolution
dynamics, while sports contracts exhibit more event-concentrated, jump-like
behavior."* Mais uma justificativa para a categoria escolhida.

### Outros achados relevantes

| ID | Título | Por que importa |
|---|---|---|
| `arXiv:2510.15205` | *Toward Black Scholes for Prediction Markets* | Trata a probabilidade negociada `p_t` como **Q-martingale** explicitamente; logit jump-diffusion. |
| `arXiv:2606.30040` | *The Shape of Macroeconomic Beliefs* | Constrói distribuições implícitas da Kalshi **convertendo contratos de limiar adjacentes** — o mesmo método do nosso `01`, aplicado a CPI. |
| `arXiv:2604.01431` | *Do Prediction Markets Forecast Cryptocurrency Volatility?* | Usa os contratos **KXFED** diretamente; mede "Fed rate repricing". |
| `arXiv:2602.19520` | *Decomposing Crowd Wisdom* | Citado por Kagan & Baiocchi. 353 milhões de negócios; calibração por domínio e tempo até resolução. |
| `arXiv:2607.14430` | *Prices, Probabilities, and Parlays* | Citado por Kagan & Baiocchi (Moshrefi 2026). Calibração **não é estática** dentro do ciclo de vida do contrato. |
| `arXiv:2606.07811` | *When Do Markets Fully Process Public Information?* | Eficiência em tempo real; preços ficam mais acurados perto da resolução. |

---

## 5. Boas práticas a adotar, item por item da lista

| Item | Prática | Fonte |
|---|---|---|
| Q1(a) | Descrever a dispersão **como função do horizonte**, não só globalmente | Kagan & Baiocchi, Fig. 8; arXiv:2607.08199 |
| Q1(a) | Declarar a série como **ponto médio da faixa-alvo do FOMC** | FEDS 2026-010, nota 2 |
| Q2 | Reportar defasagem **selecionada** (não o `max_lag`) e o critério | exigência da lista |
| Q3(b) | Não confundir MA(1) negativo com previsibilidade: é microestrutura | Glosten-Milgrom via arXiv:2607.08199 |
| Q4(d) | R inclui σ̂²ₐ em `k` — verificado | `docs/alinhamento.md` |
| Q4(f) | Invertibilidade é **restrição de admissibilidade**, não critério de ajuste | exigência da lista |
| Q5(c) | ARCH-LM **mais** regressão de `log(dif²)` no horizonte | arXiv:2607.08199 |
| Q7(f) | **Diebold-Mariano** para a diferença de RMSE | Diebold & Mariano (1995) |
| Q7(g) | Cobertura empírica **mais** histograma de PIT | Diebold, Gunther & Tay (1998); FEDS §6.1 |
| Conclusão | Ressalva Q vs P explícita | Manski (2006); FEDS §3; arXiv:2607.08199 |
| Fonte de preço | Último negócio no caminho principal | FEDS Apêndice A, replicado |

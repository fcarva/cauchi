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

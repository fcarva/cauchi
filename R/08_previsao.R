# 08_previsao.R  --  QUESTAO 7: avaliacao preditiva contra benchmarks.
#
# Q7(a) H = 24 ultimas observacoes como validacao. T0 = T - H.
# Q7(b) ESQUEMA 1 (origem fixa, multiplos passos): estimar so ate T0, prever
#       h = 1..H com intervalos de 95%, e GRAFICO com observado + previsao + IC.
# Q7(c) ESQUEMA 2 (origem movel, um passo): MANTER FIXOS os coeficientes de (b)
#       -- NAO REESTIMAR -- e percorrer t = T0..T-1 gerando so y_{t+1|t}.
# Q7(d) RMSE, MAE e MAPE para os dois esquemas.
# Q7(e) Benchmarks sob os MESMOS dois esquemas: passeio aleatorio e sazonal
#       ingenuo com s = 5. TABELA UNICA: esquemas nas colunas, modelos nas linhas.
# Q7(f) Superou? Se nao, NAO alterar o modelo para forcar resultado favoravel
#       (exigencia explicita da lista). Nao superar E o resultado esperado sob a
#       hipotese de martingale. Diebold-Mariano, se possivel, para dizer se a
#       diferenca e estatisticamente significante.
# Q7(g) Proporcao das 24 observacoes dentro do IC de 95% do Esquema 1.
#       PREVISAO: a cobertura deve EXCEDER 95%. As 24 obs reservadas sao os dias
#       imediatamente anteriores a reuniao, o trecho de MENOR variancia; os
#       intervalos, estimados sobre periodo de variancia maior, ficam largos.

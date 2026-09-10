# 05_estimacao.R  --  QUESTAO 4: estimacao MV e criterios de informacao.
#
# Q4(a) Estimar os tres candidatos por MV. TABELA UNICA com: coeficientes,
#       erros-padrao, estatisticas t, sigma^2_a, log-verossimilhanca, AIC, BIC.
# Q4(b) Tamanho da amostra efetiva de cada estimacao.
# Q4(c) Validade da comparacao: AIC/BIC so comparam modelos sobre a MESMA
#       variavel dependente e a MESMA amostra efetiva. Candidato com d distinto
#       torna a comparacao direta INVALIDA.
# Q4(d) Convencao de contagem de parametros. VERIFICADO em R 4.3.3:
#       stats::arima() INCLUI sigma^2_a em k -- attr(logLik(fit), "df") e igual
#       ao numero de coeficientes MAIS UM. ARMA(p,q) com intercepto: k = p+q+2.
# Q4(e) AIC e BIC concordam? Se nao, discutir consistencia vs eficiencia.
# Q4(f) Raizes dos polinomios AR e MA fora do circulo unitario, COM GRAFICO.

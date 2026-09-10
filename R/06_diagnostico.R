# 06_diagnostico.R  --  QUESTAO 5: verificacao dos residuos.
#
# Q5(a) Residuos contra o tempo, FAC, FACP, histograma e QQ plot.
# Q5(b) Ljung-Box com GRAUS DE LIBERDADE CORRIGIDOS (m - p - q). Reportar
#       estatistica, g.l. usados e p-valor.
# Q5(c) Jarque-Bera e ARCH-LM.
#       ESPERA-SE REJEICAO NO ARCH-LM, e isso e o RESULTADO, nao falha: a
#       variancia da variacao diaria encolhe conforme a reuniao se aproxima.
#       E a contraparte em serie temporal da Figura 8 de Kagan & Baiocchi (2026).
# Q5(d) Se um diagnostico falhar, voltar a Q3. A LISTA DE MODELOS DESCARTADOS e
#       o motivo de cada descarte FAZEM PARTE DA ENTREGA -- gravar em
#       output/tables/modelos_descartados.csv.
# Q5(e) Sobreajuste deliberado: duas especificacoes vizinhas (+1 AR, +1 MA).
#       Os coeficientes adicionais sao significativos?

# 04_identificacao.R  --  QUESTAO 3: FAC/FACP e candidatos.
#
# Q3(a) FAC e FACP da serie ja diferenciada, bandas de 95%, defasagens cobrindo
#       ao menos DOIS ciclos sazonais (com s = 5, no minimo 10 lags; usar 20).
# Q3(b) Truncamento, decaimento exponencial ou amortecido? Picos em 5, 10, 15?
#       Vizinhancas 4, 6, 9, 11 sugerindo estrutura multiplicativa?
#       CUIDADO: pico NEGATIVO no lag 1 pode ser bid-ask bounce (microestrutura),
#       nao previsibilidade. O 01 usa `mid` justamente para mitigar isso.
# Q3(c) Tres especificacoes candidatas, cada uma justificada pelo padrao.

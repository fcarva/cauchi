# 01_build_series.R  ---------------------------------------------------------
# Painel bruto (data/raw/kalshi_fed_panel.csv) -> serie diaria unica.
# Entrada: data/raw/kalshi_fed_panel.csv   (snapshot CONGELADO)
# Saida:   data/processed/serie_diaria.csv
#
# TODO: reconstruir a taxa esperada implicita / P(desfecho) e encadear reunioes.
#
# BLOQUEADO ATE O SNAPSHOT EXISTIR. Este script depende dos ROTULOS EXATOS da
# coluna `outcome`, que variam conforme a familia escolhida:
#   - KXFED         -> rotulos sao faixas de taxa; parseia os bps e faz
#                      E[taxa] = sum(p_i * taxa_i) por dia, normalizando sum(p_i)=1.
#   - KXFEDDECISION -> rotulos sao categorias; precisa de um mapa categoria -> bps.
# O 00 imprime os rotulos observados no fim da coleta. Escrever o parser antes
# disso e adivinhar formato de string -- e o jeito mais facil de gerar uma serie
# silenciosamente errada.
#
# Decisoes que ficam aqui quando for escrito:
#   - usar `mid` (mitiga bid-ask bounce) com fallback para `yes_close`;
#   - encadear reunioes: prefixo por reuniao vigente vs. horizonte fixo;
#   - tratar dias sem pregao (a serie tem de ser regularmente espacada pro ARIMA);
#   - garantir n >= 120 obs (exigencia da lista).

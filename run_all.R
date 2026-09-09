# run_all.R -- reproduz toda a analise na ordem de execucao.
# Pre-requisito:  renv::restore()   (instala as versoes travadas em renv.lock)
#
# ATENCAO: NAO re-executa 00_pull_kalshi.R. Os dados da Kalshi sao VIVOS; re-puxar
# depois muda os numeros. A analise le o snapshot CONGELADO em data/raw/.
source("R/01_build_series.R")        # painel -> serie diaria unica
source("R/02_inspecao.R")            # Questao 1
source("R/03_integracao.R")          # Questao 2
source("R/04_identificacao.R")       # Questao 3
source("R/05_estimacao.R")           # Questao 4
source("R/06_diagnostico.R")         # Questao 5
source("R/07_sobrediferenciacao.R")  # Questao 6
source("R/08_previsao.R")            # Questao 7
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("Reproducao concluida. Veja output/figures e output/tables.\n")

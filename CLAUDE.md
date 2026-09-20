## Arquitetura: fontes de sinal

Duas fontes independentes alimentam uma única variável ENERGIA (0-100):

- lib/foco/  — sessão de foco. Ativa, por evento. +15 concluída, -10 interrompida.
- lib/uso/   — monitor de redes sociais. Passiva, agregado diário. Penalidade por excesso.
- lib/mascote/ — ponto ÚNICO de escrita da energia. Nenhum outro módulo
  altera energia diretamente.

O estado (Feliz/Neutro/Cansado) é DERIVADO da energia, nunca armazenado.
Limiares 70/30.

## Parâmetros provisórios

+15 / -10 / 70 / 30 / limiar 120 min / -5 por 30 min / teto -30.
Todos provisórios, a calibrar no teste piloto. Manter em arquivo único
e nomeados — nunca literais espalhados no código.

## Requisitos em andamento

RF07 (histórico diário e sequência) — DENTRO do escopo desde o
replanejamento de 11/09. Já implementados os dados e a regra: registro
diário em caixa Hive própria (lib/dominio/registro_diario.dart,
lib/dados/repositorio_historico.dart) e cálculo de sequência
(lib/dominio/calculo_sequencia.dart), expostos no EstadoApp. A camada
visual ainda não existe.

## Restrições de plataforma

Histórico retroativo do UsageStatsManager limitado a ~7 dias — medido
no S23 pelo spike F2.0, evidência em
docs/evidencias/F20_retencao_usage_s23.csv. Além desses ~7 dias o
INTERVAL_BEST devolve o bucket semanal ou mensal ecoado em cada dia da
faixa, e não dias de verdade.

Consequência direta para o RF07: o registro diário PRECISA ser gravado
no dia corrente. Não é reconstruível depois — um dia perdido é perdido.

## Fora do escopo do MVP

RF05 (loja), RF06 (minigames), notificações locais, sync em nuvem
(RNF02). Não implementar, não sugerir.

## Registro de IA

Todo arquivo gerado ou modificado com auxílio de IA deve ser anotado em
docs/uso_ia.md: arquivo, data, o que foi gerado. Exigência dos Arts. 6º e 7º
do regulamento de TCC.
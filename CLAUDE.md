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

## Fora do escopo do MVP

RF05 (loja), RF06 (minigames), RF07 (histórico visual), RNF02 (nuvem),
animações Rive/Lottie. Não implementar, não sugerir.

## Registro de IA

Todo arquivo gerado ou modificado com auxílio de IA deve ser anotado em
docs/uso_ia.md: arquivo, data, o que foi gerado. Exigência dos Arts. 6º e 7º
do regulamento de TCC.
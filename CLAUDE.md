## Escopo do MVP

Numeração vigente desde o replanejamento de 11/09. A versão do artigo do
PC1 usa a numeração antiga: não usar como referência de IDs.

- Dentro: RF01–RF04 e RF07 (histórico diário e sequência).
- Fora: RF05 (loja), RF06 (minigames/respiração), notificações locais,
  sync em nuvem. Não implementar, não sugerir.

## Arquitetura: fontes de sinal

Duas fontes independentes alimentam uma única variável ENERGIA (0-100):

- lib/dominio/controlador_sessao.dart — sessão de foco. Ativa, por evento.
  +15 concluída, -10 interrompida.
- lib/uso/ — monitor de redes sociais. Passiva, agregado diário. Penalidade
  por excesso. Mede e devolve minutos; NÃO toca em energia.
- lib/dominio/controlador_mascote.dart — ponto ÚNICO de escrita da energia.
  Nenhum outro módulo altera energia diretamente. O ControladorUso calcula o
  delta, mas quem aplica é este.

O estado (Feliz/Neutro/Cansado) é DERIVADO da energia, nunca armazenado.
Limiares 70/30.

- Gerência de estado: provider. EstadoApp agrega e expõe tudo para a UI.
- lib/ui/casca_app.dart: barra de 3 abas (Casa, Foco, Sequência) e DONA do
  ciclo de vida. Saída do app = somente `paused` (`inactive` não é saída).
  Trocar de aba não é sair do app.
- A medição de uso no boot é agendada para DEPOIS do primeiro frame
  (agendador injetável; testes fora de frame passam um agendador síncrono).

## Uso de redes sociais (lib/uso/)

- Lista curada em ClassificadorRedesSociais.packages. Critério: função
  principal é consumo de feed algorítmico com rolagem infinita. Excluídos
  por uso misto: YouTube, WhatsApp, Telegram, LinkedIn.
- O `<queries>` do AndroidManifest ESPELHA a lista (visibilidade de package,
  Android 11+). test/uso/manifest_queries_test.dart quebra se divergirem.
  Mudança no manifesto exige reinstalar o app; hot reload não basta.
- Log de diagnóstico por package: NAO_INSTALADO | INSTALADO_SEM_USO_HOJE |
  USO_<n>_MIN (minutos do package, não o total do dia).
- Baseline e intervenção usam o MESMO método (queryAndAggregateUsageStats).
  O spike F2.0 usou queryUsageStats: seus minutos não são comparáveis nem
  citáveis como medida de uso.

## Parâmetros provisórios

+15 / -10 / 70 / 30 / limiar 120 min / -5 por 30 min / teto -30.
Todos provisórios, a calibrar no teste piloto. Manter em arquivo único
e nomeados — nunca literais espalhados no código.

## Restrições de plataforma

Histórico retroativo do UsageStatsManager limitado a ~7 dias — medido
no S23 pelo spike F2.0, evidência em
docs/evidencias/F20_retencao_usage_s23.csv. Além desses ~7 dias o
INTERVAL_BEST devolve o bucket semanal ou mensal ecoado em cada dia da
faixa, e não dias de verdade.

Consequências:
- O registro diário PRECISA ser gravado no dia corrente. Não é
  reconstruível depois — um dia perdido é perdido.
- Baseline retroativo fixado em 7 dias (CapturaBaseline): captura única,
  ao fim de avaliarUso, só com permissão concedida.

## Estado dos requisitos

- RF07: dados, regra e tela implementados (aba Sequência; dias de baseline
  com borda tracejada, legenda "Antes do app").
- RF01 visual: mascote Lottie ligado à FSM, implementado.

## Direção visual (fase visual liberada em 20/09)

- Animação: Lottie (Rive e Flame fora do MVP).
- Mascote: 3 animações do mesmo gato, em assets/mascote/ — CatLove = Feliz,
  CatLaugh = Neutro, CatCry = Cansado. Autor Abdul Latif (Animoox), Lottie
  Simple License. NÃO baixar assets: se faltar algum, pedir ao autor.
- Paleta (arquivo de tema único): primária #4C5FD5, feliz #35B87A,
  neutro #E8C547, cansado #6B7A99, fundo #FBF7F2, alerta #D9534F (só para
  uso acima do limite). Mascote NUNCA em vermelho.
- Tipografia: Nunito empacotada em assets (sem google_fonts em runtime: o
  piloto não pode depender de rede).
- Créditos de assets e fontes em docs/creditos_assets.md.

## Testes e validação

- Suíte completa passando e `flutter analyze` limpo antes de cada commit.
- Validação real só no Samsung S23 (SM-S911B, Android 15). Emulador não
  gera dados reais de UsageStatsManager.
- Commits no formato `tipo(RFxx): descrição` (feat, fix, perf, test, docs...).

## Registro de IA

Todo arquivo gerado ou modificado com auxílio de IA deve ser anotado em
docs/uso_ia.md: arquivo, data, o que foi gerado. Exigência dos Arts. 6º e 7º
do regulamento de TCC.
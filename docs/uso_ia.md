# Registro de uso de IA

Exigência dos Arts. 6º e 7º do regulamento de TCC: todo arquivo gerado ou
modificado com auxílio de ferramenta de IA fica registrado aqui, com data e
descrição do que foi gerado.

Ferramenta: Claude (Anthropic), via Claude Code.

| Data | Arquivo | O que foi gerado |
|---|---|---|
| 2026-09-20 | `lib/spikes/spike_retencao_usage.dart` | Gerado integralmente por IA a partir de especificação do autor. Spike descartável (F20) que mede quantos dias de histórico retroativo o `UsageStatsManager` devolve no Galaxy S23: entrypoint próprio, tela com botão "Rodar", varredura de hoje até 44 dias atrás em janelas de meia-noite local, saída CSV no console e em arquivo. Fora do fluxo do app; não toca `lib/uso/`, `lib/foco/` nem `lib/mascote/`. |
| 2026-09-20 | `pubspec.yaml` | Modificado por IA: `path_provider` promovido de dependência transitiva (vinha pelo `hive_flutter`) a dependência explícita, porque o spike acima chama `getExternalStorageDirectory()` diretamente. |
| 2026-09-20 | `docs/uso_ia.md` | Arquivo criado por IA (estrutura da tabela e primeiras entradas). |
| 2026-09-20 | `docs/evidencias/F20_retencao_usage_s23.csv` | Dados colhidos no aparelho pelo spike (nao gerados por IA). O bloco de comentarios `#` com a LEITURA DO RESULTADO foi redigido por IA a partir da analise das linhas repetidas do proprio CSV. |
| 2026-09-20 | `lib/estado/estado_mascote.dart` | Gerado por IA. Classe `EstadoApp` (ChangeNotifier) que agrega os tres controladores de dominio e expoe getters somente-leitura + acoes para a UI. Nao contem regra de energia, FSM nem Hive: delega tudo. |
| 2026-09-20 | `lib/ui/tela_foco.dart` | Refatorado por IA: passou a consumir `EstadoApp` via `Consumer`/`context.read` em vez de instanciar os controladores e usar `ListenableBuilder` + `setState`. Layout e textos inalterados. |
| 2026-09-20 | `lib/main.dart` | Refatorado por IA: registra `ChangeNotifierProvider<EstadoApp>` acima do `MaterialApp`; `TelaFoco` passou a ser construida sem parametros. |
| 2026-09-20 | `pubspec.yaml` | Modificado por IA: adicionado `provider: ^6.1.2` como dependencia explicita. |
| 2026-09-20 | `test/ui/tela_foco_test.dart` | Modificado por IA, apenas o wiring de montagem: `montar()` passou a criar o `EstadoApp` e registra-lo num `ChangeNotifierProvider` acima do `MaterialApp`, com dispose no `tearDown`. Nenhuma assercao, cenario ou expectativa alterada. |
| 2026-09-20 | `lib/dominio/registro_diario.dart` | Gerado por IA. Modelo do RF07: uma entrada por data (chave `yyyy-MM-dd`), com minutos de rede social, contagem de sessoes, energia final e flag de medicao valida. `limiteRespeitado`/`cumprido`/`falhou` sao getters derivados de RegrasEnergia, nunca gravados. |
| 2026-09-20 | `lib/dominio/calculo_sequencia.dart` | Gerado por IA. Regra de sequencia (streak) do RF07: funcao pura, com o "hoje" injetado. Dia cumprido soma, dia acima do limite zera, lacuna atravessa. |
| 2026-09-20 | `lib/dados/repositorio_historico.dart` | Gerado por IA. Caixa Hive `historico`, chaveada por data; registros ilegiveis sao pulados. |
| 2026-09-20 | `lib/estado/estado_mascote.dart` | Modificado por IA: passou a receber o RepositorioHistorico e um relogio opcional, grava o registro do dia ao fim de `avaliarUso()` (mesmo caminho do RF04) e expoe `sequenciaAtual`, `maiorSequencia`, `ultimos30Dias` e `primeiraAvaliacao`. |
| 2026-09-20 | `lib/main.dart` | Modificado por IA: abre a caixa `historico` e injeta o RepositorioHistorico no EstadoApp. |
| 2026-09-20 | `test/dominio/calculo_sequencia_test.dart`, `test/dados/repositorio_historico_test.dart`, `test/estado/estado_app_test.dart` | Testes gerados por IA para o RF07 (38 casos): classificacao do dia, sequencia simples, quebra por excesso, travessia de lacuna, dia corrente em andamento, historico vazio, round-trip no Hive e gravacao nos gatilhos do RF04. |
| 2026-09-20 | `test/ui/tela_foco_test.dart` | Modificado por IA, so o wiring: injeta o RepositorioHistorico e passou a criar o EstadoApp dentro de `runAsync` antes do `pumpWidget`, porque o gatilho a frio do RF07 grava em disco. Nenhuma assercao ou cenario alterado. |
| 2026-09-20 | `lib/estado/estado_mascote.dart` | Modificado por IA: getter `medicaoUsoPendente`, falso ate a primeira avaliacao terminar (inclusive quando a permissao e negada), com notifyListeners na transicao. Separa "ainda nao sei" de "medi, deu 0". |
| 2026-09-20 | `lib/ui/tela_foco.dart` | Modificado por IA: a linha de redes sociais mostra "medindo..." enquanto `medicaoUsoPendente` for verdadeiro, em vez de afirmar 0 min antes de ter medido. |
| 2026-09-20 | `test/estado/estado_app_test.dart` | Tres testes gerados por IA para o estado de carregamento: pendente antes e resolvido depois, permissao negada tambem resolve, e a notificacao na transicao. |

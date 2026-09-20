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

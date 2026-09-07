# habitos_digitais — TCC II

Serious game (Flutter/Android) para reduzir uso de redes sociais.
Público: universitários 18–25. Mascote virtual + timer de foco.

## Escopo do MVP
- Android apenas. Sem iOS, sem web.
- Flame Engine está EXCLUÍDO. A FSM do mascote é regra de negócio,
  não game loop. Animações via Rive/Lottie (pós-PC2).
- Sincronização em nuvem (RNF02) adiada. Persistência local com Hive.
- RF07 (histórico visual) fora do MVP.

## Requisitos em andamento
- RF02: timer de foco, detecção de saída via WidgetsBindingObserver
- RF01: mascote com ENERGIA 0–100, FSM Feliz/Neutro/Cansado
- RF03/RF04: sessão concluída soma energia, interrompida subtrai
- RF04: classificação de "rede social" é decisão metodológica,
  não técnica. Não inventar lista sem critério documentado.

## Restrições
- usage_stats só funciona em device físico (Samsung via USB).
  Emulador não gera dados reais de UsageStatsManager.
- Prazo PC2: 16/09. Prioridade é evidência para o artigo,
  não polimento de UI.

## Convenções
- Comentários e nomes de domínio em português; código em inglês.
- Rodar `flutter analyze` antes de commit.
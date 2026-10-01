# Assets de terceiros

Registro de origem, autoria e licença de todo material gráfico não
produzido pelo autor deste trabalho.

## Animações do mascote

Personagem: gato laranja, três estados emocionais do mesmo conjunto,
usados como representação visual da FSM do mascote (RF01). Arquivos em
`assets/mascote/`.

| Arquivo | Estado | Origem |
|---|---|---|
| `CatLove.json` | Feliz (energia ≥ 70) | LottieFiles |
| `CatLaugh.json` | Neutro (energia 30–69) | LottieFiles |
| `CatCry.json` | Cansado (energia < 30) | LottieFiles |

- **Autor:** Abdul Latif (perfil Animoox — https://lottiefiles.com/animoox)
- **Plataforma:** LottieFiles (https://lottiefiles.com)
- **Licença:** Lottie Simple License (FL 9.13.21)
- **Formato:** Lottie JSON, 500×500, 30 fps, vetorial
- **Modificações:** nenhuma até o momento. Eventual ajuste de cor em
  tempo de execução via `ValueDelegate` não altera os arquivos.

### Termos da licença

A Lottie Simple License permite download, reprodução, modificação,
publicação e distribuição das animações públicas da plataforma,
inclusive para fins comerciais, desde que qualquer redistribuição
mantenha os mesmos termos. Obras derivadas ficam sujeitas à mesma
licença. Atribuição não é obrigatória, mas é recomendada pela
plataforma e adotada aqui.

Vedações que não afetam este uso: compilar o acervo para criar serviço
concorrente, redistribuir os arquivos como animações avulsas e revender
os originais.

## Tipografia

- **Nunito** — The Nunito Project Authors
  (https://github.com/googlefonts/nunito), SIL Open Font License 1.1.
- **Arquivos:** `assets/fontes/Nunito-Regular.ttf` (400),
  `Nunito-SemiBold.ttf` (600) e `Nunito-Bold.ttf` (700), empacotados no
  app. Texto da licença em `assets/fontes/OFL.txt`, que a OFL exige que
  acompanhe a redistribuição.
- **Origem:** os mesmos arquivos estáticos que o pacote `google_fonts`
  baixava em runtime (fonts.gstatic.com), conferidos pelo SHA-256 que o
  próprio pacote fixa para cada peso. Empacotados para o piloto não
  depender de rede.
- **Modificações:** nenhuma.

## Observações

Nenhum dos itens acima é conteúdo gerado por inteligência artificial; a
declaração de uso de IA exigida pelo Cap. IV do regulamento está em
`docs/uso_ia.md`.
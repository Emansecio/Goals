# Goals

Hub de tarefas diárias no notch do MacBook. Fica recolhido como um contorno fino
em volta do notch; ao passar o mouse na borda de cima, o painel desce com as
tarefas do dia e o grid de sequência.

## Rodar

```bash
./scripts/build-app.sh            # gera build/Goals.app
open build/Goals.app
./scripts/build-app.sh --install  # copia para /Applications (recomendado p/ "abrir ao iniciar sessão")
```

Para colocar no Dock, arraste `/Applications/Goals.app` até ele.
O ícone é gerado por `swift scripts/make-icon.swift` (cria `Resources/AppIcon.icns`).

Para abrir no Xcode: `open Package.swift`. Para notificações funcionarem, rode
sempre como `Goals.app` (via script), não pelo `swift run`.

## Uso

- **Hover no notch**: abre. Sair com o mouse: recolhe (exceto enquanto edita).
- **‹ ›**: dia anterior / próximo. Clicar na data volta para hoje.
- **Adicionar tarefa**: digite e ⏎. Dia e horário no texto são entendidos:
  "Ligar pro contador amanhã 15h", "Reunião sex 14:30", "Treino às 7h".
- **Clicar numa tarefa**: edita inline (título, descrição, horário, avisos). ⏎ salva, esc cancela.
- **Arrastar uma tarefa**: sobre outra, reordena; sobre um dia do calendário, muda de dia.
- **☆** (aparece no hover): fixa a tarefa no topo.
- **Avisos** (precisam de horário): Notificação do macOS e/ou Pulso (o hub desce sozinho).
- **Pendentes**: no dia seguinte aparece "N pendentes de ontem → Mover p/ hoje".
  O dia original continua registrando a tarefa como não feita.
- **Revisão do fim do dia**: às 21h (ajustável no ⋯) o hub desce se ainda houver tarefas abertas,
  com "Mover p/ amanhã".
- **Calendário do mês**: um quadrado por dia (1…N), hoje no seu número. Clique para ir ao dia; ao navegar para outro mês, o calendário acompanha.
- **Ícone de calendário** no topo: mostra ou esconde o calendário; escondido, as tarefas ocupam a largura toda.
- **⋯** no canto do hub: abrir ao iniciar sessão, mostrar dados, **sair**.
  (O mesmo menu fica no ícone ☑︎ da barra de menus, que pode ficar escondido atrás do notch.)
- Clicar no ícone do Dock, ou abrir o app de novo, mostra o hub.

Dados: `~/Library/Application Support/Goals/tasks.json`.

## Animações

As curvas ficam em `Motion` (`Views/Theme.swift`). Ajuste `response` para deixar mais
rápido ou mais lento e `dampingFraction` para mais ou menos "quique".

- Notch magnético: cresce conforme o mouse se aproxima.
- Abertura em cascata: barra do topo → cards → linhas → grid em onda → linha em U.
- Check: círculo enche com mola, ✓ desenhado, onda e risco que corre pelo título.
- Linha ↔ editor com morph do fundo; troca de dia desliza na direção navegada.
- Contadores com dígitos animados; brilho na borda ao completar o dia ou no pulso.

## Desempenho

- Mouse via eventos (sem polling): 0% de CPU e nenhuma ativação com o mouse parado.
- Janela pequena quando recolhida; grande só enquanto aberta.
- Índice por dia em cache (progresso/níveis em O(1)), sequência memorizada.
- Linhas e grid recebem valores (só redesenham o que mudou).
- Salvamento agrupado (0,4 s) e gravado fora da thread principal.
- Sem animações em loop infinito: nada roda em segundo plano.

## Estrutura

```
Sources/Goals/
  main.swift, AppDelegate.swift   ciclo de vida, hover, pulso, barra de menus
  NotchPanel.swift                janela sobre o notch + geometria
  HubController.swift             estado da UI (aberto, dia, edição)
  TaskStore.swift, Models.swift   dados e persistência JSON
  Reminders.swift                 notificações
  Views/                          SwiftUI (hub, tarefas, editor, sequência)
scripts/                          build-app.sh (empacota/instala), make-icon.swift (ícone)
```

## Próximos passos (fora da v1)

Tarefas recorrentes · timer de foco · monitor externo · sync via iCloud.

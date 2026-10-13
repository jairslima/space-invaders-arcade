# Space Invaders Arcade by Jair Lima

Space Invaders em modo texto (terminal), Harbour 3.0.0 + GTWIN, segundo jogo da série de fliperama ASCII (depois do Snake Arcade).

## Stack e dependências

- Harbour 3.0.0 (Rev. 16951) em `C:\hb30\bin`, GT `-gtwin`, `hbwin.hbc` (`wapi_PlaySound`)
- Bloco C embutido (`#pragma BEGINDUMP`): `KEYDOWN`, `TIMERRES`, `SLEEPMS` (usa `winmm` e `user32`, já linkados)
- Sem dependências externas; WAVs sintetizados em `%TEMP%\inv_*.wav` a cada execução

## Estrutura

```
invaders.prg   - todo o jogo (abertura, jogo, regras, recordes, som, C embutido, autoteste)
invaders.hbp   - projeto hbmk2
build.bat      - compila invaders.exe
invaders.sco   - recordes (criado ao lado do .exe)
REVIEW.md / BEST_PRACTICES.md - segunda opinião e guia de reuso
```

## Comandos

```
build.bat                     REM compila invaders.exe
invaders.exe                  REM joga (terminal mínimo 80x25)
invaders.exe --selftest       REM 54 verificações, grava invaders_selftest.log, código de saída 0/1
invaders.exe --bot            REM bot joga sozinho, invulnerável, ~100 s (invaders_bot.log)
invaders.exe --botdie         REM bot joga até o game over
invaders.exe --play           REM pula a abertura (depuração)
Se o jogo cair: ler invaders_crash.log ao lado do .exe
```

## Decisões arquiteturais

- Estado do jogo em `STATIC s_*` do módulo; regras em funções pequenas (`FindAlien`, `StepFormation`, `BunkerHit`, `ShipHit`, `StepTicks`, `CheckExtra`, `CanPlay`) testáveis sem tela.
- Tick de 30 ms por relógio com `SleepMs(1)` e `timeBeginPeriod(1)` (hb_idleSleep é impreciso, ver BEST_PRACTICES).
- Colisão por posição lógica (não leitura de tela); tiro x bomba checado todo tick.
- Formação em grade (4 colunas por invasor, 2 linhas por fileira); velocidade por `StepTicks( vivos, onda )` com piso de 2 ticks.
- Som com prioridade e duração (canal único); efeito de menor prioridade é descartado.
- Teclado direto (`GetAsyncKeyState` + foco da janela) com fallback para `Inkey` e histerese.

## Estado atual (2026-10-09)

Compila sem avisos, autoteste 54/54, bot 5 ondas limpas e game over sem erro. Incidente corrigido em 2026-10-09: o jogo fechava após o ENTER (nome de som march2.00 por `%` + hb_ntos, ver BEST_PRACTICES). Revisão do Grok aplicada. Aguarda teste de jogabilidade do usuário (KeyDown no terminal dele, velocidade e som).

## Próximos passos

- Teste do usuário; ajustar dificuldade e volume
- Medir o flicker do `DrawAliens` no terminal real
- Próximos jogos: Pong, Tetris (reaproveitar o molde)

## Problemas conhecidos

- `KeyDown` pode não detectar o foco em alguns terminais (Windows Terminal); o jogo cai para `Inkey` automaticamente, mas aí depende do auto-repeat do teclado.

## Atualização 2026-10-12: teclado direto sem depender do foco

O teste do usuário mostrou lag nas setas (modo de reserva por eventos do Inkey, com atraso inicial de ~0,5 s). A checagem de foco da função C falhava no Windows Terminal. Agora: `KEYRAW` (estado físico da tecla) + `KEYFOCUS` (foco do conhost); `KeyDown()` vale se há foco OU se a janela recebeu algum evento de teclado nos últimos 2,5 s. O modo começa em "direto" e a linha 2 do HUD mostra `TECLADO DIRETO` ou `TECLADO EVENTOS`. Confirmado pelo usuário em 2026-10-12.

## Atualização 2026-10-13: cores

Cores corrigidas: as letras C, M e Y não existem no Harbour 3.0 (viram cinza ou preto); o jogo agora usa BG, RB e GR e o autoteste tem a verificação `cores validas no fonte`. Ver `BEST_PRACTICES.md`.

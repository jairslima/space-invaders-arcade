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
invaders.exe --selftest       REM 53 verificações, grava invaders_selftest.log, código de saída 0/1
```

## Decisões arquiteturais

- Estado do jogo em `STATIC s_*` do módulo; regras em funções pequenas (`FindAlien`, `StepFormation`, `BunkerHit`, `ShipHit`, `StepTicks`, `CheckExtra`, `CanPlay`) testáveis sem tela.
- Tick de 30 ms por relógio com `SleepMs(1)` e `timeBeginPeriod(1)` (hb_idleSleep é impreciso, ver BEST_PRACTICES).
- Colisão por posição lógica (não leitura de tela); tiro x bomba checado todo tick.
- Formação em grade (4 colunas por invasor, 2 linhas por fileira); velocidade por `StepTicks( vivos, onda )` com piso de 2 ticks.
- Som com prioridade e duração (canal único); efeito de menor prioridade é descartado.
- Teclado direto (`GetAsyncKeyState` + foco da janela) com fallback para `Inkey` e histerese.

## Estado atual (2026-10-08)

Compila sem avisos, autoteste 53/53. Revisão do Grok aplicada (bomba x tiro, bunker, HUD, dificuldade, prioridades de som, timer). Aguarda teste de jogabilidade do usuário (KeyDown no terminal dele, sensação de velocidade e som).

## Próximos passos

- Teste do usuário; ajustar dificuldade e volume
- Medir o flicker do `DrawAliens` no terminal real
- Próximos jogos: Pong, Tetris (reaproveitar o molde)

## Problemas conhecidos

- `KeyDown` pode não detectar o foco em alguns terminais (Windows Terminal); o jogo cai para `Inkey` automaticamente, mas aí depende do auto-repeat do teclado.

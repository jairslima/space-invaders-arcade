# Segunda opinião: Space Invaders Arcade by Jair Lima

Revisão feita pelo Grok (modelo DeepSeek Pro, via WSL, somente texto, com o código dentro do prompt) em 2026-10-08. Cada achado foi conferido contra o código; as afirmações "NÃO VERIFICADO" foram testadas por compilação. Resultado atual: `invaders.exe --selftest` com 53 verificações e 0 falhas.

## Achados do Grok e veredito

| # | Achado | Veredito | Ação |
|---|--------|----------|------|
| 1 | Bomba atravessa o tiro (colisão só checada quando a bomba anda, a cada 2-3 ticks) | **Real, grave** | `BulletBombHit()` roda todo tick em `MovePlayerBullet`; o autoteste varre as 3 defasagens |
| 2 | `KillPlayerBullet` apaga o glifo recém-redesenhado do bunker ou do efeito | **Real** | No recheque após o passo da formação, só `s_lPb := .F.` (sem apagar) |
| 3 | Bomba recém-criada só aparece um tick depois, pulando uma célula | **Real** | `EnemyFire` desenha no nascimento |
| 4 | `L2Bin`/`I2Bin`/`Bin2L` não definidas | **Falso** | São funções nativas do Harbour; o build e o autoteste (que valida os WAVs) provam |
| 5 | `ProbeAsync` desliga o teclado direto para sempre após toques rápidos | **Real** | Reavalia a cada evento, histerese de 8 eventos, religa se a tecla aparece pressionada, e toque já solto ainda move 1 célula |
| 6 | Fallback depende do auto-repeat e `hb_keyClear()` "descarta repetições a cada laço" | **Parcial** | `hb_keyClear()` roda só no início da onda (leitura do Grok errada). O fallback depende mesmo do auto-repeat do sistema: limitação documentada |
| 7 | HUD com 5 vidas passa da coluna 79 | **Real** | Ícones sem espaço final, colunas 60 a 78 |
| 8 | Tiro nasce em cima de invasor perto do pouso e não acerta | **Real** | `CheckBulletHit()` no nascimento do tiro |
| B1 | Chance de bomba de 12% por tick com intervalo 1 vira "parede" nas ondas altas | Plausível | Teto de 8% e intervalo mínimo de 2 ticks |
| B2 | `StepTicks` com razão de 22x deixa o último invasor impossível | Plausível | Piso de 2 ticks por passo (~11x) |
| B3 | Prêmio de 300 do UFO em 25% das vezes | Plausível | Peso de 1 em 8 |
| S1 | UFO com prioridade 1 é cortado pela marcha | **Real** | Prioridade 2 |
| S2 | Warble de 140 ms repetido a cada 300 ms deixa silêncio | **Real** | Repete a cada 5 ticks (150 ms) |
| S3 | Comentário de `CanPlay` engana ("espera acabar") | **Real** | Comentário corrigido: prioridade menor é descartada |
| E1 | Risco do `KeyDown` no Windows Terminal (ConPTY) e teclas presas | Risco válido | Fallback por `Inkey` com histerese; depende do teste do usuário |
| P1 | Flicker no `DrawAliens` (apaga 5 linhas inteiras) | Não medido | Não aplicado; observar no teste real |

## O que o teste achou e nenhum revisor viu

`hb_idleSleep( 0.002 )` não dorme 2 ms: 50 chamadas levaram 1548 ms (~31 ms cada). Com `timeBeginPeriod(1)` ainda ~21 ms. Corrigido com a função C `SleepMs` (Sleep nativo) mais `TimerRes(1)`. Medição no autoteste: 30 chamadas de `SleepMs(2)` em ~88 ms. Isso estabiliza o tick de 30 ms.

## Afirmações "NÃO VERIFICADO" fechadas por teste

- `hb_RandomInt( 1, 4 )` é inclusivo nas duas pontas (20000 amostras: mín 1, máx 4).
- `hb_DirBase()` devolve o caminho com separador final.
- `hb_MemoWrit`/`hb_MemoRead` preservam o WAV binário (cabeçalhos conferidos no autoteste).
- `wapi_PlaySound`, `hb_ADel`/`hb_AIns` com `.T.`, `hb_gtInfo( HB_GTI_WINTITLE )` e o bloco `#pragma BEGINDUMP` compilam e rodam.
- Ainda dependem do teste do usuário: `KeyDown` no terminal dele, glifos `Chr()` na fonte dele e a sensação de jogo.

## Pendentes

- Medir o flicker do `DrawAliens` no terminal real e, se houver, limpar só a faixa ocupada em vez de linhas inteiras.
- Invulnerabilidade curta ao renascer e som próprio para vida extra (baixa prioridade).
- Marcha com 4 notas mais distintas (opinião; hoje 98, 87, 78 e 73 Hz, como o original).

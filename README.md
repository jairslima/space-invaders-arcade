# Space Invaders Arcade by Jair Lima

Space Invaders em modo texto, escrito em Harbour 3.0 (estilo Clipper), com a experiência de fliperama:

- 55 invasores em 3 tipos que aceleram conforme morrem, bunkers que se desgastam, disco voador misterioso e bombas
- Mover e atirar ao mesmo tempo (estado real das teclas via função C embutida, com fallback automático)
- 3 vidas, vida extra a cada 2000 pontos, ondas cada vez mais difíceis, recordes com iniciais
- Efeitos sonoros sintetizados na hora, com prioridade (canal único): marcha grave, tiro, explosões com ruído, UFO
- Autoteste sem interface: `invaders.exe --selftest` (53 verificações)

## Controles

Setas ou A/D movem, espaço atira, P pausa, M liga/desliga o som, ESC sai. Terminal mínimo 80x25.

## Compilar

Requer Harbour 3.0.0 em `C:\hb30\bin`:

```
build.bat
```

## Documentação

- `PROJECT.md`: estado do projeto e decisões
- `REVIEW.md`: segunda opinião (Grok) conferida por testes
- `BEST_PRACTICES.md`: boas práticas para jogos ASCII em Harbour/Clipper (Snake + Space Invaders)

Licença MIT.

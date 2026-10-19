# Lupi Game API Reference

(Modelo oficial de https://lupi.api.br/docs/#agents, com as diferenças encontradas no simulador Lupinho no fim.)

## System Overview
- Resolution: 480x270 pixels (16:9 widescreen)
- Color: 256-color indexed palette (RGB555 format)
- Frame rate: 60 FPS target
- Main callback: `update(frame)` - called 60 times per second with frame number
- **Important:** Palette must be registered each frame using `ui.palset(index, color)`

## Global Constants
- `LEFT`, `RIGHT`, `UP`, `DOWN` - Directional buttons
- `BTN_Z`, `BTN_X` - Action buttons
- `BTN_F`, `BTN_G` - Secondary action buttons
- `BTN_Q`, `BTN_E` - Shoulder buttons
- `ALIGN_START`, `ALIGN_CENTER`, `ALIGN_END` - Layout alignment
- `LEFT_TO_RIGHT`, `TOP_TO_BOTTOM` - Layout direction

## Graphics API (ui.*)

### Screen
- `ui.cls([color])` - Clear screen with color
- `ui.clip([x, y, w, h])` - Set/reset clipping region (screen coordinates)
- `ui.camera([x, y])` - Set/reset camera offset for drawing (drawn at coord - camera)

### Primitives
- `ui.rect(x0, y0, x1, y1, color)` - Draw rectangle outline
- `ui.rectfill(x0, y0, x1, y1, color)` - Draw filled rectangle
- `ui.circ(x, y, radius, color)` - Draw circle outline
- `ui.circfill(x, y, radius, color)` - Draw filled circle
- `ui.line(x0, y0, x1, y1, color)` - Draw line
- `ui.trisfill(x1, y1, x2, y2, x3, y3, color)` - Draw filled triangle
- `ui.grid(x, y, cell_w, cell_h, data)` - Draw pixel grid from 2D table

### Sprites & Maps
- `ui.spr(sprite_ref, x, y, [flip_x], [flip_y])` - Draw sprite (tile 0)
- `ui.tile(sprite_ref, tile_id, x, y, [flip_x], [flip_y])` - Draw specific tile (0-1023)
- `ui.map(map_data, cam_x, cam_y)` - Draw map with camera offset
- Sprite refs come from the `Sprites` table (`require "sprites"`), built from `lupi_manifest.txt`:
  `img/carros/vermelho/reto1.png` -> `Sprites.img.carros.vermelho.reto1` = `{ path, width, height, ntiles }`

### Text
- `ui.print(text, x, y, color)` - Draw text string (5x8 font, 6 px advance, ASCII only)

### Palette & Patterns
- `ui.palset(index, color)` - Set palette color (index 0-255)
- `ui.fillp([b0, b1, b2, b3, b4, b5, b6, b7])` - Set fill pattern (8 bytes) or reset

### Utility
- `ui.mid(a, b, c)` - Return middle value (useful for clamping)
- `ui.stat(option)` - Get system stats: 0=memory, 1=CPU, 7=FPS

## Input API
- `ui.btn(button_id, [player])` - Button held (false or pressure 0-255)
- `ui.btnp(button_id, [player])` - Button just pressed
- Player index: 0-2 (default: 0)
- `ui.mouse()` - x, y, buttons, wheel_x, wheel_y
- `ui.peektext()` / `ui.readtext()` - keyboard characters

## Audio API (sfx.*)
- `sfx.music(music_name)` - Play music file (string), use -1 to stop
- `sfx.fx(sample_id, midi_note, [pan])` - Play sound effect
- `sfx.volume(vol)` - Set global volume (0.0-1.0)

## Layout API (Clay)
- `ui.layout(root_node)` with `Box()`, `Text()`, `Image(sprite_ref)`, `Custom(callback)` and chainable builders
  (`.size.width.set.fixed(px)`, `.padding.set.all(px)`, `.color.set(idx)`, `.add.child(node)`...).

---

## Limites do hardware real (issue oficial lupi-org-br/lupinho#12, set/2026)

O simulador ainda NÃO aplica estes limites (PR #24 começou só pela paleta); no GearX, `medidor.lua` mede (opção "desempenho"). No aparelho:
- **Sprite bank de 46 KB**: cada imagem com no máximo ~46 mil pixels (a esteira recusa acima de 46059 bytes).
- **SD**: no máximo **150 KB** de imagens lidas por quadro e **32** cargas de sprite por quadro.
- **Lua**: ~**50-60 mil instruções da VM por quadro** (3,6 M/s, perto do Pico-8). Um watchdog fecha o jogo se o loop travar muitos quadros.
- **Drawlist**: no máximo **18 KB** de comandos por quadro; comandos além disso são ignorados.
- **Cores**: 255 + transparente (índices acima de 255 são recusados).

Custo de cada comando na drawlist:

| Comando | Bytes |
|---|---|
| `ui.line`, `ui.rect`, `ui.rectfill`, `ui.circ`, `ui.circfill` | 12 |
| `ui.trisfill` | 20 |
| `ui.spr` / `ui.tile` (primeiro do lote / lote contínuo) | 8 / 4 |
| `ui.clip` (definir / resetar) | 12 / 4 |
| `ui.fillp` (definir / resetar) | 12 / 4 |
| `ui.cls` | 16 |
| `ui.camera`, `ui.palset` | 0 |
| `ui.print` | 16 + texto arredondado para múltiplo de 4 |

---

## Diferenças encontradas no simulador Lupinho (lupi-org-br/lupinho, out/2026)

- Lua 5.5 no simulador; o console usa **Lua 5.4**. Escreva código compatível com 5.4.
- `update(frame)`: `frame` chega como número decimal (`63.0`). Use contadores próprios.
- Cores: `ui.palset` interpreta o valor como **BGR555** (vermelho nos bits baixos), igual ao `lupi-codec`.
  A documentação diz RGB555. Use sempre `Palette.hex(0xRRGGBB)` e nunca números de cor fixos.
- Índice 0 da paleta é **transparente** (inclusive na tela).
- `ui.rectfill(x0, y0, x1, y1)`: no simulador `x1`/`y1` são **exclusivos** (largura = x1 - x0).
- `ui.btn`/`ui.btnp` devolvem `true`/`false`.
- Os valores numéricos das constantes de botão diferem da documentação: use sempre os nomes.
- Não existem no simulador: `sfx.*`, `ui.stat`, `ui.circ`, `ui.grid`, `ui.mouse`, `ui.peektext`, `ui.readtext`, `ui.layout`.
  Proteja com `if sfx then ... end` etc.
- Existem a mais: `ui.log(texto)` (aparece no console da página do simulador).
- `ui.spr` aceita só `flip_x` como 4º argumento.
- Teclado: W A S D = direcional, K = Z, J = X, L = Q, M = E, G = F, H = G. O teclado aciona **todos** os jogadores.

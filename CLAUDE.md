# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

**Hell Farm** — entrada para el "Tiny Game, Big Twist Jam" (3 días, tema "Everything Changes"). Híbrido de granja + bullet hell en **LÖVE/Love2D** (Lua). El giro: lo que cultivas en la fase calmada se convierte en tu arsenal durante el bullet hell. Segundo giro (estilo *Shotgun King*): cada mejora que compra el jugador vuelve al jefe más peligroso.

**Estado actual:** prototipo jugable y completo de un ciclo de niveles (granja → jefe → tienda → taunt → siguiente nivel).

## Cómo ejecutar

```powershell
& "C:\Program Files\LOVE\love.exe" "C:\Users\Ivenaccip\Documents\hell_farm"
```

No hay tests ni build: LÖVE interpreta los `.lua` directamente. Para una verificación rápida de carga sin abrir la ventana de forma permanente, se puede lanzar con LÖVE unos segundos y revisar `stderr` (un error de sintaxis o de `love.load` aparece ahí).

## Decisiones ya cerradas (no re-litigar)

- **Motor:** LÖVE/Love2D (se descartó Godot 4).
- **Estética:** ASCII sobre fuente monoespaciada; el jefe puede usar un sprite (`assets/boss.png`) con fallback automático a ASCII.
- **Semillas:** solo dos. **Maíz** = básica infinita (disparo recto, único cultivo plantable). **Calabaza** = poder de `Espacio` (escopeta de 5 balas), NO se planta; se desbloquea en la tienda. Cualquier cambio que permita "plantar" la calabaza rompe el balance (genera arsenal masivo) — mantenerla solo como poder.
- **Trigger híbrido:** nivel 1 = completar una hilera horizontal; nivel 2+ = cuenta regresiva de `FARM_COUNTDOWN` segundos.
- **Movimiento del jefe:** el rebote libre 2D es comportamiento base desde el nivel 1 (no es un patrón comprable).

## Arquitectura

### Máquina de estados (en `main.lua`)

`FARM → WARNING → BATTLE → SHOP → TAUNT → (next_level) → FARM …`
Más `GAMEOVER` (muerte del jugador, `R` reinicia) y `WIN` (definido pero no usado aún).

- **FARM:** flechas mueven en grid discreto; `1` ara, `2` planta maíz. El trigger pasa a WARNING.
- **WARNING:** pantalla de aviso (`WARNING_DURATION`) y luego crea el jefe con `Boss.new(level, boss_abilities, boss_buffs)`.
- **BATTLE:** movimiento libre + auto-farm; el jefe y las balas se actualizan. Si el jefe muere → `open_shop()`; si el jugador muere → GAMEOVER.
- **SHOP:** dos mejoras aleatorias (`Shop.roll`) o guardar (`S`). Comprar llama `buy_upgrade` → potencia al jugador **y** `grant_boss_pattern()`.
- **TAUNT:** "¿Creíste que iba a ser tan fácil?" + anuncia el patrón que aprendió el jefe.

### "La bala es el cultivo" + auto-farm (lo que hace único al juego)

El núcleo está repartido entre `grid.lua` y `player.lua`:
- En batalla, una celda plantada crece y, al madurar, **dispara una vez y se resetea a arado** (`Grid:updateBattle`). No es tower defense: los cultivos se consumen.
- El jugador **re-siembra en automático** parándose sobre las celdas: cada `player.farm_rate` segundos, la celda bajo sus pies avanza un paso (`Grid:autoFarmStep`: vacío→arado→plantado→acelera). Siempre maíz (la calabaza nunca se cultiva).
- Mantener el fuego = moverse sobre el campo. Esquivar y farmear son el mismo acto.

### Evolución del jefe acoplada a la tienda (segundo giro)

Implementado en `main.lua` (estado del pool) + `boss.lua` (efecto):
- **+5 de vida por nivel** siempre (`C.BOSS_HP + (level-1)*5`), compres o no.
- Al **comprar**, el jefe aprende un patrón aleatorio del pool, **sin repetir**; al **guardar**, no aprende nada (solo la vida del nivel).
- Pool por tiers (`BOSS_PATTERN_TIERS`): **tier 1** `{spin}` se aprende primero (garantizado en la 1ª compra); **tier 2** `{chase, enrage, spiral, summon, wall, teleport}` aleatorio. Si el pool se agota → fallback numérico (`boss_buffs`: +vida/+cadencia).
- El acumulado de patrones y buffs vive entre niveles en `boss_abilities`/`boss_buffs` (se resetea solo en `full_reset`).

### Patrones del jefe (flags `can_*` en `boss.lua`)

| Flag | Patrón |
|------|--------|
| (base) | Rebote libre 2D en su franja superior |
| `can_spin` | Ataque radial giratorio periódico (rota sobre su eje) |
| `can_chase` | Persecución: invade la granja (`max_y` extendido) + daño por contacto |
| `can_enrage` | Segunda forma al 50% de vida: magenta, +velocidad, +cadencia (una vez) |
| `can_spiral` | Ráfaga de balas con ángulo de emisión rotando (molinete) |
| `can_summon` | Invoca 2–3 minijefes (5 HP) que rebotan y disparan; mueren con los cultivos |
| `can_wall` | Muro de balas que cae con un hueco aleatorio |
| `can_teleport` | Salta a una zona aleatoria (con destello) y suelta un radial |

Los **minijefes** viven en `boss.minions`. `Boss:checkHit` los comprueba **antes** que al cuerpo del jefe, así que las balas de cultivo les pegan sin restarle vida al jefe principal.

### Stats persistentes del jugador (`player.lua`)

`Player.new()` define stats que persisten entre niveles y se mejoran en la tienda: `speed`, `hp_max`, `farm_rate`, `corn_dmg`, `corn_cadencia`, `pumpkin_unlocked`. `resetForLevel()` conserva los stats pero restaura posición/vida.

## Archivos clave

- **`main.lua`** — máquina de estados, flujo de niveles, tienda/taunt, pool de patrones del jefe (`BOSS_PATTERN_TIERS`, `grant_boss_pattern`, `buy_upgrade`), HUD y pantallas.
- **`src/constants.lua`** — **tuning central de TODO el juego.** Casi cualquier ajuste de balance se hace aquí (no esparcir números mágicos en otros archivos).
- **`src/grid.lua`** — la granja: celdas, crecimiento, auto-farm en batalla y disparo de cultivos maduros.
- **`src/player.lua`** — jugador: movimiento (discreto en granja, continuo en batalla), focus, auto-farm, stats.
- **`src/bullets.lua`** — balas de cultivo (suben, chocan con jefe/minijefes vía `Boss:checkHit`) y enemigas (bajan, chocan con el jugador). Reusar `spawnEnemy`/`spawnCrop` para patrones nuevos.
- **`src/boss.lua`** — jefe: movimiento, patrones, minijefes, sprite/ASCII. `Boss.new(level, abilities, buffs)`.
- **`src/shop.lua`** — `Shop.UPGRADES`, `Shop.roll`, `Shop.apply`, dibujo de cartas.
- **`conf.lua`** — ventana 800×600.

## Convenciones

- **Todo número de balance va en `constants.lua`.** Al agregar un patrón o ajustar dificultad, define constantes ahí (prefijo `BOSS_`, `PLAYER_`, etc.).
- **Patrones nuevos del jefe:** agregar la constante en `constants.lua`, el flag `can_*` + lógica en `boss.lua`, y registrar el patrón en `BOSS_PATTERN_TIERS` + `PATTERN_NAMES` en `main.lua`. No hace falta tocar `bullets.lua` si se reusa `spawnEnemy`.
- **Acentos en strings de Lua dibujados con la fuente por defecto:** usar escapes UTF-8 (p. ej. `\xc2\xbf` para `¿`, `\xc3\xa1` para `á`), como en `draw_taunt`. Los archivos `.md`/`.txt` sí van con acentos normales.
- El método `Boss:chase` y el flag `can_chase` están separados a propósito (un campo booleano `self.chase` sombrearía el método).

## Pendiente / abierto

- **Nivel 5 "infinito":** se habló de que el 5º nivel sea de supervivencia continua; aún no implementado (hoy los niveles solo siguen incrementando).
- **Más patrones del jefe:** el tier 2 está pensado para crecer; se irán platicando y agregando.
- **Balance:** densidades de minijefes/muro/espiral y números de la tienda son provisionales.
- **Audio y export web (itch.io)** no están hechos.

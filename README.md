# Hell Farm

**Híbrido de granja + bullet hell** hecho para la *Tiny Game, Big Twist Jam* (3 días, tema **"Everything Changes"**).

El giro: **lo que cultivas es tu arsenal.** Primero siembras tu hilera con calma; cuando baja el jefe, el juego se vuelve un bullet hell y tus cultivos disparan solos mientras tú solo esquivas. Y hay un segundo giro estilo *Shotgun King*: **cada mejora que compras vuelve al jefe más peligroso.**

Estética **ASCII** sobre fuente monoespaciada (con sprite opcional para el jefe). Hecho en **LÖVE / Love2D** (Lua).

---

## Cómo instalar y jugar

El juego necesita **LÖVE 11.x** (Love2D), un motor ligero y gratuito.

### 1. Instala LÖVE

- Descárgalo desde **[love2d.org](https://love2d.org)** e instálalo.
- Windows: el instalador lo deja normalmente en `C:\Program Files\LOVE\love.exe`.
- macOS: arrastra `love.app` a Aplicaciones.
- Linux: `sudo apt install love` (o el paquete de tu distro).

### 2. Ejecuta el juego

**Opción fácil (Windows/macOS):** arrastra la carpeta del proyecto (`hell_farm`) sobre el ejecutable de LÖVE.

**Por terminal**, apuntando LÖVE a la carpeta del proyecto:

- **Windows (PowerShell):**
  ```powershell
  & "C:\Program Files\LOVE\love.exe" "C:\Users\Ivenaccip\Documents\hell_farm"
  ```
- **macOS:**
  ```bash
  /Applications/love.app/Contents/MacOS/love /ruta/a/hell_farm
  ```
- **Linux:**
  ```bash
  love /ruta/a/hell_farm
  ```

> El jefe usa `assets/boss.png` si existe; si no, cae automáticamente a un jefe en ASCII. No hace falta el PNG para jugar.

---

## Cómo se juega

El juego es un ciclo de **niveles**. Cada nivel tiene dos fases:

### Fase 1 — Granja (calma)
Siembras tu hilera de maíz sin presión.
- En el **nivel 1** el jefe baja cuando **completas una hilera horizontal**.
- Del **nivel 2 en adelante** tienes una **cuenta regresiva de 5 segundos**: planta todo lo que puedas antes de que baje el jefe (tensión codicia vs. seguridad).

### Fase 2 — Bullet hell (tormenta)
Aparece un **WARNING**, baja el jefe y la granja se transforma en tu campo de esquive.
- **Solo esquivas** con las flechas; los cultivos **disparan solos** al jefe.
- Mientras te mueves sobre las celdas, **vuelves a sembrar en automático**: la celda bajo tus pies avanza sola (arar → plantar → madurar → disparar → repetir). Cultivar *es* mantener el fuego.

### Tienda y evolución del jefe
Al derrotar al jefe ganas **5 monedas** y entras a la tienda:
- Eliges **1 de 2 mejoras** aleatorias o **guardas** las monedas.
- **Comprar te potencia, pero el jefe aprende un patrón nuevo** (giro, persecución, segunda forma, espiral, minijefes, muro de balas o teletransporte). Si guardas, el jefe solo sube de vida.

El jefe se mueve libremente desde el primer nivel y se va volviendo más letal a cada compra: **ningún par de partidas es igual.**

---

## Controles

| Fase | Tecla | Acción |
|------|-------|--------|
| Granja | Flechas | Mover personaje |
| Granja | `1` | Arar la celda |
| Granja | `2` | Plantar maíz |
| Batalla | Flechas | Esquivar (único control activo) |
| Batalla | `Shift` | Focus: te mueves lento y se ve tu hitbox |
| Batalla | `Espacio` | Poder de calabaza (si lo desbloqueaste en la tienda) |
| Tienda | `1` / `2` | Comprar la mejora izquierda / derecha |
| Tienda | `S` | Guardar las monedas |
| Taunt | Cualquier tecla | Continuar |
| Game Over | `R` | Reiniciar |
| Cualquier momento | `Escape` | Salir |

---

## Semillas

| Semilla | Rol | Comportamiento |
|---------|-----|----------------|
| **Maíz** | Básica, infinita | Disparo recto hacia arriba. Es lo único que se cultiva. Mejorable en daño y cadencia. |
| **Calabaza** | Poder | Escopeta de 5 balas en abanico. No se planta: es el poder de `Espacio` (con cooldown), y se desbloquea comprándola en la tienda. |

---

## Estructura del proyecto

```
hell_farm/
├── main.lua            # Loop principal: máquina de estados, tienda, taunt, evolución del jefe
├── conf.lua            # Configuración de ventana (800×600)
├── src/
│   ├── constants.lua   # Tuning central de TODO el juego (números en un solo lugar)
│   ├── grid.lua        # La granja: celdas, crecimiento, auto-farm y disparo de cultivos
│   ├── player.lua      # Jugador: movimiento, stats persistentes, auto-farm en batalla
│   ├── bullets.lua     # Balas: de cultivo (suben) y enemigas (bajan)
│   ├── boss.lua        # Jefe: movimiento, patrones, minijefes y sprite
│   └── shop.lua        # Tienda: mejoras, sorteo y aplicación
└── assets/
    └── boss.png        # Sprite opcional del jefe (fallback a ASCII si no existe)
```

¿Quieres tocar el balance? Casi todo se ajusta desde **`src/constants.lua`**.

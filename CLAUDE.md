# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

**Hell Farm** — entrada para el "Tiny Game, Big Twist Jam" (3 días). Híbrido de simulador de granja + bullet hell. El giro: lo que cultivas en la fase calmada se convierte en tu arsenal durante el bullet hell.

**Estado actual:** fase de diseño — sin código aún. El documento de diseño completo está en `handoff_1.txt`.

## Stack técnico

- **Motor recomendado: LÖVE/Love2D** (Lua). Ultraligero, sin editor, iteración instantánea, ideal para ASCII.
- **Alternativa: Godot 4** (GDScript). Más complejo pero viable; requiere cabeceras COOP/COEP para web.
- **Estética: ASCII** sobre fuente monoespaciada. Los glifos se posicionan con `float`, no como cuadrícula de terminal — el bullet hell requiere movimiento sub-celda suave.
- **Hosting objetivo: itch.io** (soporta SharedArrayBuffer nativamente). Alternativas sin servidor: Netlify, Cloudflare Pages, GitHub Pages.

## Arquitectura del juego

### Dos fases (el corazón del diseño)

**Fase 1 — Granja (calma):** el jugador se mueve con flechas y usa `1`/`2`/`3` (arar/plantar/regar) para cultivar su hilera. Sin presión temporal.

**Trigger:** se completa la primera hilera (o cuenta regresiva) → aparece "WARNING" de shmup, baja el jefe, la granja queda **bloqueada**.

**Fase 2 — Bullet hell:** solo flechas para esquivar. Los cultivos ya plantados **disparan solos** al jefe. El jugador no controla el ataque, solo la supervivencia.

**Principio de diseño:** lo que cultivaste en la fase 1 *es* tu arsenal en la fase 2. La granja no debe sentirse como trámite.

### Semillas (~3–4 tipos, se diferencian por comportamiento)

| Tipo | Rol | Ejemplo de bala |
|------|-----|-----------------|
| Básica | Infinita (nunca sin recurso) | Proyectil simple |
| Defensiva | Bloquea balas enemigas | Enredadera = pared |
| Ofensiva A | Dispersión | Escopeta |
| Ofensiva B | Área | Explosión |

### Slot 4 — Poder/Bomba

Recurso limitado de alto impacto. Se carga jugando (cosechar/disparar/matar), no por tiempo. Se dispara automáticamente al cargarse (para mantener la fase 2 en un solo input: flechas).

### Rendimiento ASCII

- Dibujar todas las balas en **una sola pasada** (TileMap de glifos / `draw_char`), nunca un nodo por glifo.
- Color + glifo distinto por rol: jugador / balas / cultivos / enemigo.

## Controles

| Fase | Input | Acción |
|------|-------|--------|
| 1 | Flechas | Mover personaje |
| 1 | `1` / `2` / `3` | Arar / plantar / regar |
| 2 | Flechas | Esquivar (único control activo) |
| 2 | Automático | Poder al cargarse; `Espacio` si se prefiere manual |
| Ambas | (Opcional) Focus | Mantener = movimiento lento + hitbox visible |

El giro de control es intencional: el set de teclas se *reduce* al entrar al bullet hell, reforzando el tema "Everything Changes".

## Decisiones abiertas

Estas decisiones no están cerradas y deben resolverse antes o durante la implementación:

1. **Poder fijo vs. rotativo** — Fijo: el jugador elige (más estratégico). Rotativo: el cargado va girando (más caótico, más on-theme). Recomendación: arrancar fijo, rotativo como stretch goal.
2. **Trigger exacto** — "primera hilera completa" (mínimo) vs. cuenta regresiva que premia sembrar más rápido (tensión codicia/seguridad).
3. **Estética final** — ASCII vs. sprites (no afecta el hosting).
4. **Motor final** — LÖVE vs. Godot 4.
5. **Definición concreta de las 3–4 semillas** y patrones de bala de cada una.
6. **Diseño del jefe** — patrones de bullet hell para la fase 2.

## Scope del jam

Un solo ciclo granja → jefe. Sin loops, sin múltiples niveles. La meta es una experiencia memorable y completa en una sola pasada.

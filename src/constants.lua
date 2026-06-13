local M = {}

M.WIN_W = 800
M.WIN_H = 600

-- Grid layout
M.COLS   = 8
M.ROWS   = 3
M.CELL_W = 64
M.CELL_H = 56
M.GRID_X = 144   -- (800 - 8*64) / 2
M.GRID_Y = 412   -- grid goes from 412 to 580, 20px bottom margin

-- Cell states
M.CELL_EMPTY   = 0
M.CELL_PLOWED  = 1
M.CELL_PLANTED = 2
M.CELL_MATURE  = 3

-- Seed types
M.SEED_CORN    = 1
M.SEED_PUMPKIN = 2

-- Game states
M.STATE_FARM     = "farm"
M.STATE_WARNING  = "warning"
M.STATE_BATTLE   = "battle"
M.STATE_SHOP     = "shop"
M.STATE_TAUNT    = "taunt"
M.STATE_GAMEOVER = "gameover"
M.STATE_WIN      = "win"

-- Timing
M.GROW_TIME        = 4.0   -- seconds to mature without watering
M.WATER_SPEEDUP    = 2.0   -- regar halves remaining grow time
M.WARNING_DURATION = 2.5   -- seconds of WARNING screen before boss
M.FARM_COUNTDOWN   = 5.0   -- nivel 2+: segundos de siembra antes de que baje el jefe

-- Bullet base speed (px/s)
M.BASE_SPEED = 230

-- Corn: single straight shot
M.CORN_SPEED_MULT  = 1.0
M.CORN_DAMAGE      = 1.0
M.CORN_FIRE_RATE   = 1.2   -- seconds between shots per cell

-- Pumpkin: 5-bullet spread (escopeta)
M.PUMPKIN_SPEED_MULT = 1.1
M.PUMPKIN_DAMAGE     = 1.5
M.PUMPKIN_BULLETS    = 5
M.PUMPKIN_SPREAD     = math.pi / 6   -- 30 degrees total fan
M.PUMPKIN_FIRE_RATE  = 2.2

-- Boss
M.BOSS_HP        = 10
M.BOSS_SPEED     = 85
M.BOSS_FIRE_RATE = 1.6
M.BOSS_FIRE_MIN  = 0.6   -- piso del intervalo de disparo (no baja de aquí por más buffs)

-- Boss: evolución acoplada a la tienda (estilo Shotgun King).
-- Cada mejora que compra el jugador fortalece al jefe del próximo nivel.
M.BOSS_BUY_HP    = 3     -- vida extra al jefe por cada compra
M.BOSS_BUY_FIRE  = 0.12  -- segundos que se restan al intervalo de disparo por compra

-- Boss: ataque especial radial (gira y dispara en círculo)
M.BOSS_SPECIAL_INTERVAL = 5.0    -- segundos entre ataques especiales
M.BOSS_SPECIAL_BULLETS  = 10     -- balas en el círculo
M.BOSS_SPECIAL_SPEED    = 150    -- velocidad de las balas radiales
M.BOSS_SPIN_DURATION    = 0.7    -- cuánto dura la animación de giro
M.BOSS_SPIN_SPEED       = 18     -- rad/s de la rotación visual

-- Boss: persecución (exclusivo de nivel 3+, se mueve por toda la pantalla)
M.BOSS_CHASE_INTERVAL = 6.0      -- segundos entre persecuciones
M.BOSS_CHASE_DURATION = 2.0      -- cuánto dura cada persecución
M.BOSS_CHASE_SPEED    = 150      -- velocidad mientras persigue (rebote normal ≈ 110)
M.BOSS_CONTACT_DAMAGE = true     -- el cuerpo del jefe daña al jugador al tocarlo

-- Boss: segunda forma (enrage al 50% de vida)
M.BOSS_ENRAGE_THRESHOLD  = 0.5   -- fracción de vida que dispara la furia
M.BOSS_ENRAGE_FIRE_MULT  = 0.6   -- multiplica el intervalo de disparo (más cadencia)
M.BOSS_ENRAGE_SPEED_MULT = 1.4   -- multiplica la velocidad de movimiento

-- Boss: espiral giratoria (ráfaga de balas con ángulo que rota)
M.BOSS_SPIRAL_INTERVAL = 6.0     -- segundos entre ráfagas de espiral
M.BOSS_SPIRAL_COUNT    = 24      -- disparos por ráfaga
M.BOSS_SPIRAL_GAP      = 0.06    -- segundos entre cada disparo de la espiral
M.BOSS_SPIRAL_SPEED    = 130     -- velocidad de las balas de espiral
M.BOSS_SPIRAL_STEP     = 0.5     -- rad que avanza el ángulo de emisión por disparo

-- Boss: invocación de minijefes
M.BOSS_SUMMON_INTERVAL     = 8.0 -- segundos entre oleadas (solo si no quedan minions)
M.BOSS_MINION_MIN          = 2   -- mínimo de minions por oleada
M.BOSS_MINION_MAX          = 3   -- máximo de minions por oleada
M.BOSS_MINION_HP           = 5   -- vida de cada minion
M.BOSS_MINION_SPEED        = 70  -- velocidad de rebote del minion
M.BOSS_MINION_FIRE_RATE    = 2.2 -- segundos entre disparos del minion
M.BOSS_MINION_BULLET_SPEED = 150 -- velocidad de las balas del minion
M.BOSS_MINION_HITBOX       = 14  -- radio de colisión del minion

-- Boss: muro de balas con hueco
M.BOSS_WALL_INTERVAL = 7.0       -- segundos entre muros
M.BOSS_WALL_SPEED    = 130       -- velocidad de caída del muro
M.BOSS_WALL_GAP      = 48        -- medio ancho del hueco (px libres a cada lado del centro)
M.BOSS_WALL_SPACING  = 34        -- separación horizontal entre balas del muro

-- Boss: teletransporte (reaparece en otra zona y dispara radial)
M.BOSS_TELEPORT_INTERVAL = 5.5   -- segundos entre teletransportes

-- Boss: cinemática de muerte (se desvanece poco a poco antes de la tienda)
M.BOSS_DEATH_DURATION = 1.5      -- segundos del fade de muerte (igual al fade de música)

-- Player
M.PLAYER_SPEED      = 200
M.PLAYER_FOCUS_MULT = 0.45
M.PLAYER_HP         = 3
M.PLAYER_HITBOX     = 5    -- collision radius (px)
M.BULLET_HITBOX     = 5

return M

local Grid    = require("src.grid")
local Player  = require("src.player")
local Bullets = require("src.bullets")
local Boss    = require("src.boss")
local Shop    = require("src.shop")
local C       = require("src.constants")
local Sfx     = require("src.sfx")

local state, grid, bullets, boss
local player       -- persiste entre niveles
local level        = 1
local warn_timer   = 0
local warn_pulse   = 0
local farm_countdown = 0   -- nivel 2+: cuenta regresiva de siembra (5→0)
local taunt_timer  = 0
local shop_opt_a, shop_opt_b
-- Evolución del jefe acoplada a la tienda (estilo Shotgun King).
-- Al comprar, el jefe aprende un PATRÓN aleatorio nuevo (desacoplado del nivel).
-- Pool por prioridad: el jefe aprende primero todo el tier 1 (movimiento + giro,
-- en orden aleatorio entre ellos), luego el tier 2, etc. Se ampliará con patrones futuros.
-- El movimiento libre es base del jefe (siempre activo); no entra al pool.
local BOSS_PATTERN_TIERS = {
    { "spin" },           -- tier 1: garantizado en la primera compra
    { "chase", "enrage", "spiral", "summon", "wall", "teleport" },  -- tier 2: aleatorios
}
local PATTERN_NAMES = {
    spin     = "spinning attack",
    chase    = "chases you",
    enrage   = "second form (rage at 50%)",
    spiral   = "spinning spiral",
    summon   = "summons minibosses",
    wall     = "bullet wall",
    teleport = "teleport",
}
local boss_abilities = {}                                -- patrones que el jefe ya tiene { spin=true,... }
local boss_buffs     = { extra_hp = 0, fire_speedup = 0 } -- fallback cuando el pool se agota
local boss_last_learned = nil                            -- texto de lo último aprendido (para el taunt)
local boss_evolved_by_purchase = false                   -- ¿se compró algo el último nivel?

local small_font, big_font

local function full_reset()
    player     = Player.new()
    level      = 1
    state      = C.STATE_FARM
    grid       = Grid.new()
    bullets    = Bullets.new()
    boss       = nil
    warn_timer = 0
    warn_pulse = 0
    boss_abilities = {}
    boss_buffs = { extra_hp = 0, fire_speedup = 0 }
    boss_last_learned = nil
    boss_evolved_by_purchase = false
    Sfx.playMusic("farm")
end

local function next_level()
    level = level + 1
    player:resetForLevel()
    state      = C.STATE_FARM
    grid       = Grid.new()
    bullets    = Bullets.new()
    boss       = nil
    warn_timer = 0
    warn_pulse = 0
    farm_countdown = C.FARM_COUNTDOWN   -- nivel 2+ arranca con la cuenta regresiva
    Sfx.playMusic("farm")
end

local function go_taunt()
    state       = C.STATE_TAUNT
    taunt_timer = 4.0
    Sfx.play("taunt")
end

local function open_shop()
    player.coins = player.coins + 5
    shop_opt_a, shop_opt_b = Shop.roll(player)
    state = C.STATE_SHOP
    -- La música de la tienda ya entró con fade al iniciar la cinemática de muerte.
end

-- El jefe aprende un patrón aleatorio que aún no tenga. Si ya los tiene todos,
-- cae a un refuerzo numérico (+vida/+cadencia) para no quedarse sin consecuencia.
local function grant_boss_pattern()
    -- Recorre los tiers en orden; dentro de cada uno elige aleatorio entre los no aprendidos.
    for _, tier in ipairs(BOSS_PATTERN_TIERS) do
        local available = {}
        for _, p in ipairs(tier) do
            if not boss_abilities[p] then available[#available + 1] = p end
        end
        if #available > 0 then
            local pick = available[math.random(#available)]
            boss_abilities[pick] = true
            boss_last_learned = PATTERN_NAMES[pick]
            return
        end
    end
    -- Todos los patrones aprendidos: fallback numérico (+vida/+cadencia)
    boss_buffs.extra_hp     = boss_buffs.extra_hp + C.BOSS_BUY_HP
    boss_buffs.fire_speedup = boss_buffs.fire_speedup + C.BOSS_BUY_FIRE
    boss_last_learned = "grows tougher and faster"
end

-- Comprar una mejora: el jugador se potencia y, a cambio, el jefe aprende un
-- patrón nuevo aleatorio (acoplamiento estilo Shotgun King).
function buy_upgrade(opt)
    Shop.apply(opt.id, player)
    player.coins = player.coins - opt.cost
    grant_boss_pattern()
    boss_evolved_by_purchase = true
    Sfx.play("buy")
    go_taunt()
end

function love.load()
    math.randomseed(os.time())
    small_font = love.graphics.newFont(20)
    big_font   = love.graphics.newFont(52)
    love.graphics.setFont(small_font)
    Boss.loadAssets()   -- carga opcional del sprite (diferida: love ya esta listo)
    Sfx.load()
    full_reset()
end

function love.update(dt)
    warn_pulse = warn_pulse + dt * 7
    Sfx.update(dt)

    if state == C.STATE_FARM then
        grid:update(dt)
        local trigger
        if level == 1 then
            -- Nivel 1: fase calmada, el trigger es completar una hilera
            trigger = grid:anyRowComplete()
        else
            -- Nivel 2+: cuenta regresiva de siembra, baja el jefe al llegar a 0
            local prev = math.ceil(farm_countdown)
            farm_countdown = farm_countdown - dt
            local cur = math.ceil(farm_countdown)
            if cur < prev and cur >= 1 then Sfx.play("tick") end   -- tic por segundo
            trigger = farm_countdown <= 0
        end
        if trigger then
            state      = C.STATE_WARNING
            warn_timer = C.WARNING_DURATION
            Sfx.play("warning")
            Sfx.playMusic("battle")   -- la música intensa arranca con el aviso
        end

    elseif state == C.STATE_WARNING then
        warn_timer = warn_timer - dt
        if warn_timer <= 0 then
            state = C.STATE_BATTLE
            boss  = Boss.new(level, boss_abilities, boss_buffs)
            player:syncPixelFromGrid()
            grid:fireMatureCells(bullets, player)
        end

    elseif state == C.STATE_BATTLE then
        grid:updateBattle(dt, bullets, player)
        player:update(dt, grid)
        boss:update(dt, bullets, player)
        bullets:update(dt, boss, player)

        if boss.dying then
            -- Cinemática de muerte en curso: esperar a que el jefe se desvanezca
            if boss:isDeathDone() then open_shop() end
        elseif boss.hp <= 0 then
            -- Arranca la cinemática: el jefe se desvanece y la música baja con él
            boss:startDying()
            bullets.enemy = {}   -- limpiar balas enemigas (no morir durante la animación)
            Sfx.play("boss_die")
            Sfx.playMusic("shop", C.BOSS_DEATH_DURATION)
        elseif player.hp <= 0 then
            Sfx.play("gameover")
            Sfx.stopMusic()
            state = C.STATE_GAMEOVER
        end

    elseif state == C.STATE_TAUNT then
        taunt_timer = taunt_timer - dt
        if taunt_timer <= 0 then
            next_level()
        end
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end

    if state == C.STATE_FARM then
        if     key == "left"  then player:moveGrid(0, -1)
        elseif key == "right" then player:moveGrid(0,  1)
        elseif key == "up"    then player:moveGrid(-1,  0)
        elseif key == "down"  then player:moveGrid( 1,  0)
        elseif key == "1"     then if grid:plow(player.grid_row, player.grid_col) then Sfx.play("plow") end
        elseif key == "2"     then if grid:plant(player.grid_row, player.grid_col, C.SEED_CORN) then Sfx.play("plant") end
        end

    elseif state == C.STATE_BATTLE then
        -- Poder de calabaza (Space)
        if key == "space" and player.pumpkin_unlocked and player.space_cd <= 0 then
            bullets:spawnCrop(player.x, player.y, C.SEED_PUMPKIN)
            player.space_cd = 4.0
        end

    elseif state == C.STATE_SHOP then
        if key == "1" then
            if player.coins >= shop_opt_a.cost then buy_upgrade(shop_opt_a) else Sfx.play("deny") end
        elseif key == "2" then
            if player.coins >= shop_opt_b.cost then buy_upgrade(shop_opt_b) else Sfx.play("deny") end
        elseif key == "s" then
            boss_evolved_by_purchase = false   -- guardaste: el jefe sube solo por nivel
            go_taunt()
        end

    elseif state == C.STATE_TAUNT then
        if key ~= "escape" then next_level() end   -- cualquier tecla salta el taunt

    elseif state == C.STATE_GAMEOVER then
        if key == "r" then full_reset() end
    end
end

-- ─── Draw ────────────────────────────────────────────────────────────────────

function love.draw()
    love.graphics.clear(0.04, 0.04, 0.07)

    if state == C.STATE_SHOP then
        Shop.draw(player, shop_opt_a, shop_opt_b, small_font, big_font)
        return
    end

    draw_arena_divider()

    if state == C.STATE_BATTLE then
        grid:draw(state, player.x, player.y)
    else
        grid:draw(state)
    end

    if state == C.STATE_FARM then
        player:draw(C.STATE_FARM)
        draw_farm_hud()
        if level >= 2 then draw_farm_countdown() end

    elseif state == C.STATE_WARNING then
        player:draw(C.STATE_FARM)
        draw_warning()

    elseif state == C.STATE_BATTLE then
        bullets:draw()
        boss:draw()
        player:draw(C.STATE_BATTLE)

    elseif state == C.STATE_TAUNT then
        draw_taunt()

    elseif state == C.STATE_GAMEOVER then
        draw_end_screen("GAME OVER", {1.0, 0.20, 0.20})
    end
end

function draw_arena_divider()
    love.graphics.setColor(0.30, 0.28, 0.20, 0.6)
    love.graphics.line(0, C.GRID_Y - 4, C.WIN_W, C.GRID_Y - 4)
end

function draw_farm_hud()
    love.graphics.setColor(0.75, 0.75, 0.65)
    if player.pumpkin_unlocked then
        love.graphics.print("Pumpkin: [Space] power in battle", 10, C.WIN_H - 46)
    end
    love.graphics.print("[1] Plow   [2] Plant corn", 10, C.WIN_H - 24)
    -- Recordatorio de pantalla completa (web), centrado entre corazones y monedas
    love.graphics.setColor(0.55, 0.75, 0.55)
    local fs = "Press Go Fullscreen"
    love.graphics.print(fs, (C.WIN_W - small_font:getWidth(fs)) * 0.5, 10)
    -- Monedas
    love.graphics.setColor(1.0, 0.85, 0.2)
    local c = "Coins: " .. player.coins
    love.graphics.print(c, C.WIN_W - small_font:getWidth(c) - 10, 10)
end

function draw_warning()
    love.graphics.setFont(big_font)
    local alpha = 0.55 + (math.sin(warn_pulse) + 1) * 0.225
    love.graphics.setColor(1.0, 0.05, 0.05, alpha)
    local txt = "!! WARNING !!"
    local w   = big_font:getWidth(txt)
    love.graphics.print(txt, (C.WIN_W - w) * 0.5, C.WIN_H * 0.32)
    love.graphics.setFont(small_font)
end

function draw_farm_countdown()
    local n = math.max(1, math.ceil(farm_countdown))
    -- Etiqueta
    love.graphics.setColor(0.85, 0.55, 0.20)
    local label = "Boss arrives in..."
    love.graphics.print(label, (C.WIN_W - small_font:getWidth(label)) * 0.5, 22)
    -- Número grande pulsante (más rojo conforme baja)
    love.graphics.setFont(big_font)
    local t     = farm_countdown / C.FARM_COUNTDOWN     -- 1 → 0
    local pulse = 0.7 + (math.sin(warn_pulse) + 1) * 0.15
    love.graphics.setColor(1.0, 0.20 + 0.5 * t, 0.10, pulse)
    local s = tostring(n)
    love.graphics.print(s, (C.WIN_W - big_font:getWidth(s)) * 0.5, 44)
    love.graphics.setFont(small_font)
end

function draw_taunt()
    love.graphics.clear(0.02, 0.02, 0.04)
    love.graphics.setFont(big_font)
    -- Pulso rojo en el texto
    local pulse = 0.75 + (math.sin(warn_pulse * 0.8) + 1) * 0.125
    love.graphics.setColor(1.0, 0.12, 0.12, pulse)
    local msg = "Did you think"
    local msg2 = "it would be that easy?"
    local w1 = big_font:getWidth(msg)
    local w2 = big_font:getWidth(msg2)
    local fh = big_font:getHeight()
    love.graphics.print(msg,  (C.WIN_W - w1) * 0.5, C.WIN_H * 0.35)
    love.graphics.print(msg2, (C.WIN_W - w2) * 0.5, C.WIN_H * 0.35 + fh + 8)

    -- Evolución del jefe, acoplada a tu decisión en la tienda
    love.graphics.setFont(small_font)
    local evo
    if boss_evolved_by_purchase then
        evo = "The boss learned: " .. (boss_last_learned or "a new trick")
    else
        evo = "You saved your coins: the boss learns nothing new"
    end
    love.graphics.setColor(1.0, 0.55, 0.15)
    love.graphics.print(evo, (C.WIN_W - small_font:getWidth(evo)) * 0.5, C.WIN_H * 0.60)

    love.graphics.setColor(0.45, 0.45, 0.42)
    local hint = "Press any key to continue..."
    love.graphics.print(hint, (C.WIN_W - small_font:getWidth(hint)) * 0.5, C.WIN_H * 0.72)
end

function draw_end_screen(msg, color)
    love.graphics.setFont(big_font)
    love.graphics.setColor(unpack(color))
    local w = big_font:getWidth(msg)
    love.graphics.print(msg, (C.WIN_W - w) * 0.5, C.WIN_H * 0.38)
    love.graphics.setFont(small_font)
    love.graphics.setColor(0.80, 0.80, 0.75)
    local sub = "Press R to restart"
    local sw  = small_font:getWidth(sub)
    love.graphics.print(sub, (C.WIN_W - sw) * 0.5, C.WIN_H * 0.55)
end

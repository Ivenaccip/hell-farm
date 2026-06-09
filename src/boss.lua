local C = require("src.constants")

local Boss = {}
Boss.__index = Boss

local HITBOX_R = 28
local BAR_W    = 120
local BAR_H    = 7

-- Sprite opcional: si assets/boss.png existe se usa; si no, fallback a ASCII.
-- Se carga una sola vez (no por instancia).
local SPRITE       = nil
local SPRITE_SCALE = 1
do
    local ok, img = pcall(love.graphics.newImage, "assets/boss.png")
    if ok then
        SPRITE = img
        SPRITE:setFilter("nearest", "nearest")   -- pixel-art nítido al escalar
        -- Escala para que el sprite mida ~ 2*HITBOX_R de ancho visual
        SPRITE_SCALE = (HITBOX_R * 2.4) / SPRITE:getWidth()
    end
end

-- Límites del área del jefe (no puede bajar a la zona de cultivos)
local MIN_X = 60
local MAX_X = C.WIN_W - 60
local MIN_Y = 40
local MAX_Y = C.GRID_Y - 70

function Boss.new(level, buffs)
    local self      = setmetatable({}, Boss)
    self.x          = C.WIN_W * 0.5
    self.y          = -50
    self.target_y   = 80
    self.entering   = true
    self.level      = level or 1
    buffs           = buffs or {}
    -- +5 de vida por nivel + vida extra acumulada por las compras del jugador.
    -- nivel 1 = 10, nivel 2 = 15, nivel 3 = 20... (+ BOSS_BUY_HP por cada mejora comprada)
    local hp        = C.BOSS_HP + (self.level - 1) * 5 + (buffs.extra_hp or 0)
    self.hp         = hp
    self.max_hp     = hp
    -- Cadencia propia: más rápida cuanto más haya comprado el jugador (con piso).
    self.fire_rate  = math.max(C.BOSS_FIRE_MIN, C.BOSS_FIRE_RATE - (buffs.fire_speedup or 0))
    self.fire_timer = 0
    self.special_timer = 0       -- acumula hacia el ataque especial
    self.spin_timer = 0          -- > 0 mientras gira (animación)
    self.spin_angle = 0          -- rotación visual actual del sprite
    self.chase_cd   = 0          -- acumula hacia la próxima persecución
    self.chase_timer = 0         -- > 0 mientras persigue

    -- Límites de movimiento. Nivel 3+ baja a toda la pantalla (invade la granja).
    self.min_x = MIN_X
    self.max_x = MAX_X
    self.min_y = MIN_Y
    self.max_y = (self.level >= 3) and (C.WIN_H - 40) or MAX_Y

    if self.level >= 2 then
        -- Movimiento libre 2D: velocidad aleatoria en dirección diagonal
        local angle = math.pi * 0.25 + math.random() * math.pi * 0.5
        local spd   = C.BOSS_SPEED * 1.3
        self.vx = math.cos(angle) * spd
        self.vy = math.sin(angle) * spd * 0.6   -- algo más lento en Y para que no sea frenético
    else
        -- Nivel 1: patrulla horizontal
        self.dir = 1
    end

    return self
end

-- Rectángulo de la barra de vida (compartido por draw y checkHit para que coincidan)
function Boss:barRect()
    local offset
    if SPRITE then
        offset = SPRITE:getHeight() * SPRITE_SCALE * 0.5 + 12
    else
        offset = love.graphics.getFont():getHeight() + 10
    end
    return self.x - BAR_W * 0.5, self.y + offset, BAR_W, BAR_H
end

function Boss:checkHit(bx, by, damage)
    if self.entering then return false end

    local dx = bx - self.x
    local dy = by - self.y
    if dx * dx + dy * dy <= HITBOX_R * HITBOX_R then
        self.hp = self.hp - damage
        return true
    end

    local bar_x, bar_y, bw, bh = self:barRect()
    if bx >= bar_x and bx <= bar_x + bw and
       by >= bar_y and by <= bar_y + bh then
        self.hp = self.hp - damage
        return true
    end

    return false
end

function Boss:update(dt, bullets, player)
    -- Entrada desde arriba
    if self.entering then
        self.y = self.y + 200 * dt
        if self.y >= self.target_y then
            self.y = self.target_y
            self.entering = false
        end
        return
    end

    -- Movimiento según nivel
    if self.level >= 3 then
        if self.chase_timer > 0 then
            -- Persiguiendo al jugador
            self.chase_timer = self.chase_timer - dt
            self:chase(dt, player)
            if self.chase_timer <= 0 then
                -- Termina: vuelve al rebote en la dirección que traía
                local nx = self.last_nx or 0.7
                local ny = self.last_ny or 0.7
                local spd = C.BOSS_SPEED * 1.3
                self.vx = nx * spd
                self.vy = ny * spd
            end
        else
            self:moveFree(dt)
            self.chase_cd = self.chase_cd + dt
            if self.chase_cd >= C.BOSS_CHASE_INTERVAL then
                self.chase_cd = 0
                self.chase_timer = C.BOSS_CHASE_DURATION
            end
        end
    elseif self.level >= 2 then
        self:moveFree(dt)
    else
        self:moveHorizontal(dt)
    end

    -- Daño por contacto: el cuerpo del jefe toca al jugador
    if C.BOSS_CONTACT_DAMAGE then
        local pdx = player.x - self.x
        local pdy = player.y - self.y
        local r   = HITBOX_R + C.PLAYER_HITBOX
        if pdx * pdx + pdy * pdy <= r * r then
            player:tryHit()
        end
    end

    -- Animación de giro (decae sola)
    if self.spin_timer > 0 then
        self.spin_timer = self.spin_timer - dt
        self.spin_angle = self.spin_angle + C.BOSS_SPIN_SPEED * dt
    end

    -- Ataque especial radial (exclusivo de nivel 2+)
    if self.level >= 2 then
        self.special_timer = self.special_timer + dt
        if self.special_timer >= C.BOSS_SPECIAL_INTERVAL then
            self.special_timer = self.special_timer - C.BOSS_SPECIAL_INTERVAL
            self:specialAttack(bullets)
        end
    end

    -- Disparo normal (pausado durante el giro para que el especial destaque)
    if self.spin_timer <= 0 then
        self.fire_timer = self.fire_timer + dt
        if self.fire_timer >= self.fire_rate then
            self.fire_timer = self.fire_timer - self.fire_rate
            self:fire(bullets, player)
        end
    end
end

-- Gira y dispara N balas en círculo (360°)
function Boss:specialAttack(bullets)
    self.spin_timer = C.BOSS_SPIN_DURATION
    local n   = C.BOSS_SPECIAL_BULLETS
    local spd = C.BOSS_SPECIAL_SPEED
    for i = 1, n do
        local angle = (i - 1) / n * (2 * math.pi)
        bullets:spawnEnemy(
            self.x, self.y,
            math.cos(angle) * spd,
            math.sin(angle) * spd
        )
    end
end

function Boss:moveHorizontal(dt)
    self.x = self.x + C.BOSS_SPEED * self.dir * dt
    if self.x >= self.max_x then self.x = self.max_x; self.dir = -1 end
    if self.x <= self.min_x then self.x = self.min_x; self.dir =  1 end
end

function Boss:moveFree(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if self.x <= self.min_x then self.x = self.min_x; self.vx =  math.abs(self.vx) end
    if self.x >= self.max_x then self.x = self.max_x; self.vx = -math.abs(self.vx) end
    if self.y <= self.min_y then self.y = self.min_y; self.vy =  math.abs(self.vy) end
    if self.y >= self.max_y then self.y = self.max_y; self.vy = -math.abs(self.vy) end
end

-- Persecución (nivel 3+): se mueve hacia el jugador con velocidad aumentada.
-- Devuelve la dirección normalizada para reusarla como vector de rebote al terminar.
function Boss:chase(dt, player)
    local dx  = player.x - self.x
    local dy  = player.y - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        local nx, ny = dx / len, dy / len
        local spd = C.BOSS_CHASE_SPEED
        self.x = self.x + nx * spd * dt
        self.y = self.y + ny * spd * dt
        -- Clamp a los límites (toda la pantalla en nivel 3)
        self.x = math.max(self.min_x, math.min(self.max_x, self.x))
        self.y = math.max(self.min_y, math.min(self.max_y, self.y))
        self.last_nx, self.last_ny = nx, ny
    end
end

function Boss:fire(bullets, player)
    local spd = 175
    local dx  = player.x - self.x
    local dy  = player.y - self.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        bullets:spawnEnemy(self.x, self.y + HITBOX_R, dx / len * spd, dy / len * spd)
    end
    for _, off in ipairs({-0.35, 0.35}) do
        local angle = math.pi * 0.5 + off
        bullets:spawnEnemy(self.x, self.y + HITBOX_R,
            math.cos(angle) * (spd * 0.8),
            math.sin(angle) * (spd * 0.8))
    end
end

function Boss:draw()
    if self.y < -40 then return end

    if SPRITE then
        -- Tinte según estado: persecución = rojo intenso, especial = rosado
        if self.chase_timer > 0 then
            love.graphics.setColor(1.0, 0.25, 0.25)
        elseif self.spin_timer > 0 then
            love.graphics.setColor(1.0, 0.6, 0.6)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.draw(
            SPRITE, self.x, self.y, self.spin_angle,
            SPRITE_SCALE, SPRITE_SCALE,
            SPRITE:getWidth() * 0.5, SPRITE:getHeight() * 0.5   -- origen centrado
        )
    else
        -- Fallback ASCII (también rota sobre su eje durante el ataque especial)
        local font = love.graphics.getFont()
        local fh   = font:getHeight()
        local lines = { "[-BOSS-]", "\\|||||/" }
        if self.chase_timer > 0 then
            love.graphics.setColor(1.0, 0.45, 0.0)   -- naranja brillante al perseguir
        else
            love.graphics.setColor(1.0, 0.15, 0.15)
        end
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.spin_angle)   -- 0 cuando no hace el especial
        for i, line in ipairs(lines) do
            local fw = font:getWidth(line)
            -- centrado: bloque de 2 líneas alrededor de (0,0)
            love.graphics.print(line, -fw * 0.5, -fh + (i - 1) * fh)
        end
        love.graphics.pop()
    end

    -- Barra de vida
    local bar_x, bar_y, bw, bh = self:barRect()
    local pct = math.max(0, self.hp / self.max_hp)
    love.graphics.setColor(0.35, 0.05, 0.05)
    love.graphics.rectangle("fill", bar_x, bar_y, bw, bh)
    love.graphics.setColor(1.0, 0.10, 0.10)
    love.graphics.rectangle("fill", bar_x, bar_y, bw * pct, bh)
end

return Boss

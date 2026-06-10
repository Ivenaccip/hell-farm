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

function Boss.new(level, abilities, buffs)
    local self      = setmetatable({}, Boss)
    self.x          = C.WIN_W * 0.5
    self.y          = -50
    self.target_y   = 80
    self.entering   = true
    self.level      = level or 1
    abilities       = abilities or {}
    buffs           = buffs or {}
    -- Patrones aprendidos: se desbloquean COMPRANDO en la tienda, no por nivel.
    self.can_spin     = abilities.spin     or false   -- ataque radial giratorio periódico
    self.can_chase    = abilities.chase    or false   -- persecución al jugador por toda la pantalla
    self.can_enrage   = abilities.enrage   or false   -- segunda forma al 50% de vida
    self.can_spiral   = abilities.spiral   or false   -- espiral giratoria de balas
    self.can_summon   = abilities.summon   or false   -- invoca minijefes
    self.can_wall     = abilities.wall     or false   -- muro de balas con hueco
    self.can_teleport = abilities.teleport or false   -- teletransporte + radial
    -- +5 de vida por nivel (siempre). El fallback de compras suma vida extra.
    -- nivel 1 = 10, nivel 2 = 15, nivel 3 = 20...
    local hp        = C.BOSS_HP + (self.level - 1) * 5 + (buffs.extra_hp or 0)
    self.hp         = hp
    self.max_hp     = hp
    -- Cadencia propia (el fallback de compras la acelera, con piso).
    self.fire_rate  = math.max(C.BOSS_FIRE_MIN, C.BOSS_FIRE_RATE - (buffs.fire_speedup or 0))
    self.fire_timer = 0
    self.special_timer = 0       -- acumula hacia el ataque especial
    self.spin_timer = 0          -- > 0 mientras gira (animación)
    self.spin_angle = 0          -- rotación visual actual del sprite
    self.chase_cd   = 0          -- acumula hacia la próxima persecución
    self.chase_timer = 0         -- > 0 mientras persigue

    -- Estado de la segunda forma (enrage)
    self.enraged    = false
    self.speed_mult = 1.0        -- multiplicador de velocidad (sube con el enrage)

    -- Timers de los patrones nuevos
    self.spiral_cd         = 0   -- cooldown entre ráfagas de espiral
    self.spiral_shots      = 0   -- disparos restantes de la ráfaga actual
    self.spiral_gap        = 0   -- tiempo hasta el próximo disparo de la espiral
    self.spiral_angle_emit = 0   -- ángulo de emisión (rota para formar la espiral)
    self.summon_cd         = 0   -- cooldown de invocación
    self.wall_cd           = 0   -- cooldown del muro
    self.teleport_cd       = 0   -- cooldown del teletransporte
    self.teleport_flash    = 0   -- > 0: destello visual tras reaparecer

    self.minions = {}            -- minijefes vivos { x, y, hp, vx, vy, fire_timer }

    -- Si aprendió a perseguir, invade toda la pantalla (baja a la zona de cultivos).
    self.min_x = MIN_X
    self.max_x = MAX_X
    self.min_y = MIN_Y
    self.max_y = self.can_chase and (C.WIN_H - 40) or MAX_Y

    -- El jefe se mueve libre (rebote 2D) desde el primer nivel para que no sea estático.
    local angle = math.pi * 0.25 + math.random() * math.pi * 0.5
    local spd   = C.BOSS_SPEED * 1.3
    self.vx = math.cos(angle) * spd
    self.vy = math.sin(angle) * spd * 0.6   -- algo más lento en Y para que no sea frenético

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

    -- Minijefes primero: si la bala pega a uno, le resta vida a ÉL (no al jefe principal).
    for _, m in ipairs(self.minions) do
        if m.hp > 0 then
            local mdx = bx - m.x
            local mdy = by - m.y
            if mdx * mdx + mdy * mdy <= C.BOSS_MINION_HITBOX * C.BOSS_MINION_HITBOX then
                m.hp = m.hp - damage
                return true
            end
        end
    end

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

    -- Segunda forma: al 50% de vida se enfurece una sola vez (más cadencia y velocidad)
    if self.can_enrage and not self.enraged and self.hp <= self.max_hp * C.BOSS_ENRAGE_THRESHOLD then
        self.enraged    = true
        self.fire_rate  = self.fire_rate * C.BOSS_ENRAGE_FIRE_MULT
        self.speed_mult = C.BOSS_ENRAGE_SPEED_MULT
        if self.vx then self.vx = self.vx * C.BOSS_ENRAGE_SPEED_MULT end
        if self.vy then self.vy = self.vy * C.BOSS_ENRAGE_SPEED_MULT end
    end

    -- Movimiento según los patrones que el jefe haya aprendido
    if self.can_chase then
        if self.chase_timer > 0 then
            -- Persiguiendo al jugador
            self.chase_timer = self.chase_timer - dt
            self:chase(dt, player)
            if self.chase_timer <= 0 then
                -- Termina: vuelve al rebote en la dirección que traía
                local nx = self.last_nx or 0.7
                local ny = self.last_ny or 0.7
                local spd = C.BOSS_SPEED * 1.3 * self.speed_mult
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
    else
        self:moveFree(dt)
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
    if self.teleport_flash > 0 then self.teleport_flash = self.teleport_flash - dt end

    -- Ataque especial radial (solo si aprendió el patrón de giro)
    if self.can_spin then
        self.special_timer = self.special_timer + dt
        if self.special_timer >= C.BOSS_SPECIAL_INTERVAL then
            self.special_timer = self.special_timer - C.BOSS_SPECIAL_INTERVAL
            self:specialAttack(bullets)
        end
    end

    -- Espiral giratoria: ráfaga de balas con el ángulo de emisión rotando
    if self.can_spiral then self:updateSpiral(dt, bullets) end

    -- Muro de balas con hueco
    if self.can_wall then
        self.wall_cd = self.wall_cd + dt
        if self.wall_cd >= C.BOSS_WALL_INTERVAL then
            self.wall_cd = 0
            self:wallAttack(bullets)
        end
    end

    -- Teletransporte: reaparece en otra zona y suelta un radial
    if self.can_teleport then
        self.teleport_cd = self.teleport_cd + dt
        if self.teleport_cd >= C.BOSS_TELEPORT_INTERVAL then
            self.teleport_cd = 0
            self.x = self.min_x + math.random() * (self.max_x - self.min_x)
            self.y = self.min_y + math.random() * (self.max_y - self.min_y)
            self.teleport_flash = 0.3
            self:specialAttack(bullets)
        end
    end

    -- Invocación de minijefes (solo reinvoca cuando ya no queda ninguno)
    if self.can_summon then
        self.summon_cd = self.summon_cd + dt
        if self.summon_cd >= C.BOSS_SUMMON_INTERVAL and #self.minions == 0 then
            self.summon_cd = 0
            self:summonMinions()
        end
    end
    self:updateMinions(dt, bullets, player)

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

-- Espiral: dispara de a poco mientras el ángulo de emisión rota, formando un molinete.
function Boss:updateSpiral(dt, bullets)
    if self.spiral_shots > 0 then
        self.spiral_gap = self.spiral_gap - dt
        if self.spiral_gap <= 0 then
            self.spiral_gap   = C.BOSS_SPIRAL_GAP
            self.spiral_shots = self.spiral_shots - 1
            local a   = self.spiral_angle_emit
            local spd = C.BOSS_SPIRAL_SPEED
            -- Dos brazos opuestos para una espiral doble
            bullets:spawnEnemy(self.x, self.y, math.cos(a) * spd, math.sin(a) * spd)
            bullets:spawnEnemy(self.x, self.y, math.cos(a + math.pi) * spd, math.sin(a + math.pi) * spd)
            self.spiral_angle_emit = self.spiral_angle_emit + C.BOSS_SPIRAL_STEP
            self.spin_timer = math.max(self.spin_timer, 0.12)   -- mantener el giro visual
        end
    else
        self.spiral_cd = self.spiral_cd + dt
        if self.spiral_cd >= C.BOSS_SPIRAL_INTERVAL then
            self.spiral_cd    = 0
            self.spiral_shots = C.BOSS_SPIRAL_COUNT
            self.spiral_gap   = 0
        end
    end
end

-- Muro horizontal de balas que cae, con un hueco aleatorio por donde esquivar.
function Boss:wallAttack(bullets)
    local gap_x = MIN_X + math.random() * (MAX_X - MIN_X)
    local x = 20
    while x < C.WIN_W - 20 do
        if math.abs(x - gap_x) > C.BOSS_WALL_GAP then
            bullets:spawnEnemy(x, self.y, 0, C.BOSS_WALL_SPEED)
        end
        x = x + C.BOSS_WALL_SPACING
    end
end

-- Invoca de 2 a 3 minijefes alrededor del jefe.
function Boss:summonMinions()
    local n = math.random(C.BOSS_MINION_MIN, C.BOSS_MINION_MAX)
    for _ = 1, n do
        local angle = math.random() * 2 * math.pi
        local spd   = C.BOSS_MINION_SPEED
        local mx = math.max(MIN_X, math.min(MAX_X, self.x + math.cos(angle) * 50))
        local my = math.max(MIN_Y, math.min(MAX_Y, self.y + math.sin(angle) * 50))
        self.minions[#self.minions + 1] = {
            x = mx, y = my,
            hp = C.BOSS_MINION_HP,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd * 0.7,
            fire_timer = math.random() * C.BOSS_MINION_FIRE_RATE,
        }
    end
end

-- Mueve, hace disparar y descarta minijefes muertos.
function Boss:updateMinions(dt, bullets, player)
    if #self.minions == 0 then return end
    local alive = {}
    for _, m in ipairs(self.minions) do
        if m.hp > 0 then
            m.x = m.x + m.vx * dt
            m.y = m.y + m.vy * dt
            if m.x <= MIN_X then m.x = MIN_X; m.vx =  math.abs(m.vx) end
            if m.x >= MAX_X then m.x = MAX_X; m.vx = -math.abs(m.vx) end
            if m.y <= MIN_Y then m.y = MIN_Y; m.vy =  math.abs(m.vy) end
            if m.y >= MAX_Y then m.y = MAX_Y; m.vy = -math.abs(m.vy) end

            m.fire_timer = m.fire_timer + dt
            if m.fire_timer >= C.BOSS_MINION_FIRE_RATE then
                m.fire_timer = m.fire_timer - C.BOSS_MINION_FIRE_RATE
                local dx, dy = player.x - m.x, player.y - m.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0 then
                    local spd = C.BOSS_MINION_BULLET_SPEED
                    bullets:spawnEnemy(m.x, m.y, dx / len * spd, dy / len * spd)
                end
            end

            alive[#alive + 1] = m
        end
    end
    self.minions = alive
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
        local spd = C.BOSS_CHASE_SPEED * self.speed_mult
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
    local font = love.graphics.getFont()
    local fh   = font:getHeight()

    -- Minijefes (se dibujan detrás del jefe principal)
    for _, m in ipairs(self.minions) do
        love.graphics.setColor(1.0, 0.35, 0.55)
        local g  = "&"
        local fw = font:getWidth(g)
        love.graphics.print(g, m.x - fw * 0.5, m.y - fh * 0.5)
    end

    if self.y >= -40 then
        -- Color según estado (la furia tiene prioridad visual)
        local cr, cg, cb
        if self.enraged then
            cr, cg, cb = 1.0, 0.15, 0.75            -- magenta furioso
        elseif self.chase_timer > 0 then
            cr, cg, cb = 1.0, 0.25, 0.25
        elseif self.spin_timer > 0 then
            cr, cg, cb = 1.0, 0.6, 0.6
        else
            cr, cg, cb = 1, 1, 1
        end

        if SPRITE then
            love.graphics.setColor(cr, cg, cb)
            love.graphics.draw(
                SPRITE, self.x, self.y, self.spin_angle,
                SPRITE_SCALE, SPRITE_SCALE,
                SPRITE:getWidth() * 0.5, SPRITE:getHeight() * 0.5   -- origen centrado
            )
        else
            -- Fallback ASCII (también rota sobre su eje durante el ataque especial)
            local lines = { "[-BOSS-]", "\\|||||/" }
            if self.enraged then
                love.graphics.setColor(1.0, 0.15, 0.75)
            elseif self.chase_timer > 0 then
                love.graphics.setColor(1.0, 0.45, 0.0)   -- naranja brillante al perseguir
            else
                love.graphics.setColor(1.0, 0.15, 0.15)
            end
            love.graphics.push()
            love.graphics.translate(self.x, self.y)
            love.graphics.rotate(self.spin_angle)   -- 0 cuando no hace el especial
            for i, line in ipairs(lines) do
                local fw = font:getWidth(line)
                love.graphics.print(line, -fw * 0.5, -fh + (i - 1) * fh)
            end
            love.graphics.pop()
        end

        -- Destello del teletransporte
        if self.teleport_flash > 0 then
            love.graphics.setColor(0.6, 0.9, 1.0, self.teleport_flash * 2)
            love.graphics.circle("line", self.x, self.y, HITBOX_R + 10)
        end

        -- Barra de vida
        local bar_x, bar_y, bw, bh = self:barRect()
        local pct = math.max(0, self.hp / self.max_hp)
        love.graphics.setColor(0.35, 0.05, 0.05)
        love.graphics.rectangle("fill", bar_x, bar_y, bw, bh)
        love.graphics.setColor(1.0, 0.10, 0.10)
        love.graphics.rectangle("fill", bar_x, bar_y, bw * pct, bh)
    end
end

return Boss

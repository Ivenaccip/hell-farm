local C   = require("src.constants")
local Sfx = require("src.sfx")

local Player = {}
Player.__index = Player

function Player.new()
    local self      = setmetatable({}, Player)
    self.grid_row   = 2
    self.grid_col   = 4
    self.x          = 0
    self.y          = 0
    self.inv_timer  = 0
    self.farm_timer = 0
    self.space_cd   = 0          -- cooldown del poder (calabaza)
    -- Stats que persisten entre niveles y se mejoran en la tienda
    self.coins           = 0
    self.hp              = C.PLAYER_HP
    self.hp_max          = C.PLAYER_HP
    self.speed           = C.PLAYER_SPEED
    self.farm_rate       = 0.40            -- segundos entre ticks de auto-farm
    self.corn_dmg        = C.CORN_DAMAGE
    self.corn_cadencia   = 0               -- segundos que se restan al grow_max del maiz
    self.pumpkin_unlocked = false
    return self
end

-- Llamar entre niveles: conserva stats pero resetea posición e invencibilidad
function Player:resetForLevel()
    self.grid_row  = 2
    self.grid_col  = 4
    self.x         = 0
    self.y         = 0
    self.inv_timer = 0
    self.farm_timer = 0
    self.space_cd  = 0
    self.hp        = self.hp_max           -- restaurar vida al inicio de nivel
end

-- Call once when transitioning farm → battle
function Player:syncPixelFromGrid()
    self.x, self.y = self:gridCenter()
end

function Player:gridCenter()
    local x = C.GRID_X + (self.grid_col - 1) * C.CELL_W + C.CELL_W * 0.5
    local y = C.GRID_Y + (self.grid_row - 1) * C.CELL_H + C.CELL_H * 0.5
    return x, y
end

-- Discrete movement used in farm phase (called from keypressed)
function Player:moveGrid(dr, dc)
    self.grid_row = math.max(1, math.min(C.ROWS, self.grid_row + dr))
    self.grid_col = math.max(1, math.min(C.COLS, self.grid_col + dc))
end

-- Continuous movement + auto-farming in battle phase
-- grid: Grid instance (nil-safe, pass nil to skip auto-farming)
function Player:update(dt, grid)
    if self.inv_timer > 0 then self.inv_timer = self.inv_timer - dt end
    if self.space_cd  > 0 then self.space_cd  = self.space_cd  - dt end

    local dx, dy = 0, 0
    if love.keyboard.isDown("left")  then dx = -1 end
    if love.keyboard.isDown("right") then dx =  1 end
    if love.keyboard.isDown("up")    then dy = -1 end
    if love.keyboard.isDown("down")  then dy =  1 end

    if dx ~= 0 and dy ~= 0 then
        local n = 1 / math.sqrt(2)
        dx, dy = dx * n, dy * n
    end

    local spd = self.speed
    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        spd = spd * C.PLAYER_FOCUS_MULT
    end

    self.x = self.x + dx * spd * dt
    self.y = self.y + dy * spd * dt

    -- Keep player inside grid area
    local pad = C.PLAYER_HITBOX + 2
    self.x = math.max(C.GRID_X + pad, math.min(C.GRID_X + C.COLS * C.CELL_W - pad, self.x))
    self.y = math.max(C.GRID_Y + pad, math.min(C.GRID_Y + C.ROWS * C.CELL_H - pad, self.y))

    -- Auto-farm: every 0.4s avanza un paso la celda bajo el jugador
    if grid then
        self.farm_timer = self.farm_timer + dt
        if self.farm_timer >= self.farm_rate then
            self.farm_timer = 0
            local col = math.floor((self.x - C.GRID_X) / C.CELL_W) + 1
            local row = math.floor((self.y - C.GRID_Y) / C.CELL_H) + 1
            col = math.max(1, math.min(C.COLS, col))
            row = math.max(1, math.min(C.ROWS, row))
            -- La calabaza nunca se cultiva; es solo el poder de Espacio.
            grid:autoFarmStep(row, col, C.SEED_CORN, self)
        end
    end
end

-- Returns true if hit was registered (ignores invincibility window)
function Player:tryHit()
    if self.inv_timer > 0 then return false end
    self.hp = self.hp - 1
    self.inv_timer = 2.0
    Sfx.play("player_hurt")
    return true
end

function Player:draw(phase)
    local x, y
    if phase == C.STATE_BATTLE then
        x, y = self.x, self.y
    else
        x, y = self:gridCenter()
    end

    -- Blink while invincible: skip drawing the player sprite this frame
    local blinking = self.inv_timer > 0 and math.floor(self.inv_timer * 10) % 2 == 0
    if not blinking then
        local font   = love.graphics.getFont()
        local glyph  = "^"
        local fw     = font:getWidth(glyph)
        local fh     = font:getHeight()
        love.graphics.setColor(0.0, 1.0, 1.0)
        love.graphics.print(glyph, x - fw * 0.5, y - fh * 0.5)

        -- Show hitbox dot in focus mode
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.circle("fill", x, y, 3)
        end
    end

    -- HP hearts (filled = vivo, vacío = perdido)
    local heart_on  = "<3"
    local heart_off = "</3"  -- slot vacío si hubo upgrade de HP
    for i = 1, self.hp_max do
        if i <= self.hp then
            love.graphics.setColor(1.0, 0.20, 0.20)
            love.graphics.print(heart_on,  10 + (i - 1) * 32, 10)
        else
            love.graphics.setColor(0.35, 0.15, 0.15)
            love.graphics.print(heart_off, 10 + (i - 1) * 32, 10)
        end
    end

    -- Indicador de espacio (pumpkin) si está desbloqueado
    if phase == C.STATE_BATTLE and self.pumpkin_unlocked then
        if self.space_cd <= 0 then
            love.graphics.setColor(1.0, 0.50, 0.0)
            love.graphics.print("[SPC] READY", C.WIN_W - 120, 10)
        else
            love.graphics.setColor(0.50, 0.30, 0.10)
            love.graphics.print(string.format("[SPC] %.1fs", self.space_cd), C.WIN_W - 120, 10)
        end
    end
end

return Player

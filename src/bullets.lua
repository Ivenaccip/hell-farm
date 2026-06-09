local C = require("src.constants")

local Bullets = {}
Bullets.__index = Bullets

function Bullets.new()
    local self   = setmetatable({}, Bullets)
    self.crop    = {}   -- fired by crops, travel upward
    self.enemy   = {}   -- fired by boss, travel downward
    return self
end

-- dmg_override: si se pasa, reemplaza el daño base (usado para upgrade corn_dmg)
function Bullets:spawnCrop(x, y, seed, dmg_override)
    if seed == C.SEED_CORN then
        self.crop[#self.crop + 1] = {
            x = x, y = y,
            vx = 0,
            vy = -(C.BASE_SPEED * C.CORN_SPEED_MULT),
            damage = dmg_override or C.CORN_DAMAGE,
            glyph  = "|",
            color  = {1.0, 1.0, 0.1},
        }
    elseif seed == C.SEED_PUMPKIN then
        -- 5-bullet fan centered on straight up (-π/2)
        local n      = C.PUMPKIN_BULLETS
        local spread = C.PUMPKIN_SPREAD
        local spd    = C.BASE_SPEED * C.PUMPKIN_SPEED_MULT
        for i = 1, n do
            local t     = (i - 1) / (n - 1)            -- 0..1
            local angle = -math.pi * 0.5 + (t - 0.5) * spread
            self.crop[#self.crop + 1] = {
                x = x, y = y,
                vx = math.cos(angle) * spd,
                vy = math.sin(angle) * spd,
                damage = C.PUMPKIN_DAMAGE,
                glyph  = "*",
                color  = {1.0, 0.50, 0.0},
            }
        end
    end
end

function Bullets:spawnEnemy(x, y, vx, vy)
    self.enemy[#self.enemy + 1] = {
        x = x, y = y,
        vx = vx, vy = vy,
        glyph = "v",
        color = {1.0, 0.18, 0.18},
    }
end

function Bullets:update(dt, boss, player)
    -- Crop bullets → check boss collision
    local alive = {}
    for _, b in ipairs(self.crop) do
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        local offscreen = b.y < -30 or b.x < -30 or b.x > C.WIN_W + 30
        if not offscreen and not boss:checkHit(b.x, b.y, b.damage) then
            alive[#alive + 1] = b
        end
    end
    self.crop = alive

    -- Enemy bullets → check player collision
    alive = {}
    for _, b in ipairs(self.enemy) do
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        local offscreen = b.y > C.WIN_H + 30 or b.y < -30 or b.x < -30 or b.x > C.WIN_W + 30
        if offscreen then
            -- discard
        elseif self:collidesPlayer(b, player) then
            player:tryHit()
            -- bullet consumed on hit
        else
            alive[#alive + 1] = b
        end
    end
    self.enemy = alive
end

function Bullets:collidesPlayer(b, player)
    local dx = b.x - player.x
    local dy = b.y - player.y
    local r  = C.PLAYER_HITBOX + C.BULLET_HITBOX
    return dx * dx + dy * dy <= r * r
end

function Bullets:draw()
    local font = love.graphics.getFont()
    local fh   = font:getHeight()
    for _, b in ipairs(self.crop) do
        love.graphics.setColor(unpack(b.color))
        local fw = font:getWidth(b.glyph)
        love.graphics.print(b.glyph, b.x - fw * 0.5, b.y - fh * 0.5)
    end
    for _, b in ipairs(self.enemy) do
        love.graphics.setColor(unpack(b.color))
        local fw = font:getWidth(b.glyph)
        love.graphics.print(b.glyph, b.x - fw * 0.5, b.y - fh * 0.5)
    end
end

return Bullets

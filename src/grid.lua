local C = require("src.constants")

local Grid = {}
Grid.__index = Grid

local GLYPHS = {
    [C.SEED_CORN]    = { g1 = ",", g2 = "i", mature = "!" },
    [C.SEED_PUMPKIN] = { g1 = "o", g2 = "O", mature = "%" },
}
local COL = {
    [C.SEED_CORN]    = { grow = {0.80, 0.90, 0.20}, mature = {1.00, 1.00, 0.00} },
    [C.SEED_PUMPKIN] = { grow = {0.90, 0.50, 0.10}, mature = {1.00, 0.42, 0.00} },
}

function Grid.new()
    local self = setmetatable({}, Grid)
    self.cells = {}
    for row = 1, C.ROWS do
        self.cells[row] = {}
        for col = 1, C.COLS do
            self.cells[row][col] = {
                state      = C.CELL_EMPTY,
                seed       = nil,
                grow_timer = 0,
                grow_max   = C.GROW_TIME,
            }
        end
    end
    return self
end

function Grid:plow(row, col)
    local cell = self.cells[row][col]
    if cell.state == C.CELL_EMPTY then
        cell.state = C.CELL_PLOWED
    end
end

function Grid:plant(row, col, seed)
    local cell = self.cells[row][col]
    if cell.state == C.CELL_PLOWED then
        cell.state      = C.CELL_PLANTED
        cell.seed       = seed
        cell.grow_timer = 0
        cell.grow_max   = C.GROW_TIME
    end
end

function Grid:water(row, col)
    local cell = self.cells[row][col]
    if cell.state == C.CELL_PLANTED then
        local remaining = cell.grow_max - cell.grow_timer
        cell.grow_max = cell.grow_timer + remaining / C.WATER_SPEEDUP
    end
end

-- Farm phase: advance grow timers, mark mature
function Grid:update(dt)
    for row = 1, C.ROWS do
        for col = 1, C.COLS do
            local cell = self.cells[row][col]
            if cell.state == C.CELL_PLANTED then
                cell.grow_timer = cell.grow_timer + dt
                if cell.grow_timer >= cell.grow_max then
                    cell.state = C.CELL_MATURE
                end
            end
        end
    end
end

-- Battle phase: grow planted cells; when mature, fire once and reset to plowed
-- player: usado para corn_dmg upgrade
function Grid:updateBattle(dt, bullets, player)
    for row = 1, C.ROWS do
        for col = 1, C.COLS do
            local cell = self.cells[row][col]
            if cell.state == C.CELL_PLANTED then
                cell.grow_timer = cell.grow_timer + dt
                if cell.grow_timer >= cell.grow_max then
                    local cx, cy = self:cellCenter(row, col)
                    local dmg = (cell.seed == C.SEED_CORN and player) and player.corn_dmg or nil
                    bullets:spawnCrop(cx, cy, cell.seed, dmg)
                    cell.state      = C.CELL_PLOWED
                    cell.seed       = nil
                    cell.grow_timer = 0
                    cell.grow_max   = C.GROW_TIME
                end
            end
        end
    end
end

-- Fire all mature cells in one burst and reset them (called when battle starts)
function Grid:fireMatureCells(bullets, player)
    for row = 1, C.ROWS do
        for col = 1, C.COLS do
            local cell = self.cells[row][col]
            if cell.state == C.CELL_MATURE then
                local cx, cy = self:cellCenter(row, col)
                local dmg = (cell.seed == C.SEED_CORN and player) and player.corn_dmg or nil
                bullets:spawnCrop(cx, cy, cell.seed, dmg)
                cell.state      = C.CELL_PLOWED
                cell.seed       = nil
                cell.grow_timer = 0
                cell.grow_max   = C.GROW_TIME
            end
        end
    end
end

-- Auto-farm: advance a cell one step forward (called by player movement in battle)
-- player: Player instance (optional, used for corn cadencia upgrade)
function Grid:autoFarmStep(row, col, seed, player)
    local cell = self.cells[row][col]
    if cell.state == C.CELL_EMPTY then
        cell.state = C.CELL_PLOWED
    elseif cell.state == C.CELL_PLOWED then
        cell.state      = C.CELL_PLANTED
        cell.seed       = seed
        cell.grow_timer = 0
        local base = C.GROW_TIME * 0.65
        if seed == C.SEED_CORN and player then
            base = math.max(0.5, base - player.corn_cadencia)
        end
        cell.grow_max = base
    elseif cell.state == C.CELL_PLANTED then
        local remaining = cell.grow_max - cell.grow_timer
        cell.grow_max   = cell.grow_timer + remaining / C.WATER_SPEEDUP
    end
end

function Grid:anyRowComplete()
    for row = 1, C.ROWS do
        local full = true
        for col = 1, C.COLS do
            if self.cells[row][col].state ~= C.CELL_MATURE then
                full = false
                break
            end
        end
        if full then return true end
    end
    return false
end

function Grid:cellTopLeft(row, col)
    return C.GRID_X + (col - 1) * C.CELL_W,
           C.GRID_Y + (row - 1) * C.CELL_H
end

function Grid:cellCenter(row, col)
    local x, y = self:cellTopLeft(row, col)
    return x + C.CELL_W * 0.5, y + C.CELL_H * 0.5
end

-- px, py: player pixel position (optional, used in battle to highlight current cell)
function Grid:draw(state, px, py)
    local font = love.graphics.getFont()
    local fh   = font:getHeight()

    -- Determine which cell the player is standing on (battle only)
    local hl_row, hl_col
    if px and py then
        hl_col = math.floor((px - C.GRID_X) / C.CELL_W) + 1
        hl_row = math.floor((py - C.GRID_Y) / C.CELL_H) + 1
        hl_col = math.max(1, math.min(C.COLS, hl_col))
        hl_row = math.max(1, math.min(C.ROWS, hl_row))
    end

    for row = 1, C.ROWS do
        for col = 1, C.COLS do
            local cell    = self.cells[row][col]
            local x, y   = self:cellTopLeft(row, col)

            -- Cell background (highlight current cell in battle)
            if row == hl_row and col == hl_col then
                love.graphics.setColor(0.15, 0.25, 0.12)
            else
                love.graphics.setColor(0.07, 0.10, 0.05)
            end
            love.graphics.rectangle("fill", x + 1, y + 1, C.CELL_W - 2, C.CELL_H - 2)

            -- Border
            local brow, bg, bb = 0.22, 0.22, 0.18
            love.graphics.setColor(brow, bg, bb)
            love.graphics.rectangle("line", x, y, C.CELL_W, C.CELL_H)

            -- Glyph
            local glyph, color
            if cell.state == C.CELL_EMPTY then
                glyph = "."
                color = {0.22, 0.22, 0.18}
            elseif cell.state == C.CELL_PLOWED then
                glyph = "#"
                color = {0.55, 0.38, 0.18}
            elseif cell.state == C.CELL_PLANTED then
                local pct = cell.grow_timer / cell.grow_max
                local g   = GLYPHS[cell.seed]
                glyph = pct < 0.5 and g.g1 or g.g2
                color = COL[cell.seed].grow
            elseif cell.state == C.CELL_MATURE then
                glyph = GLYPHS[cell.seed].mature
                color = COL[cell.seed].mature
            end

            love.graphics.setColor(unpack(color))
            local fw = font:getWidth(glyph)
            love.graphics.print(glyph, x + (C.CELL_W - fw) * 0.5, y + (C.CELL_H - fh) * 0.5)
        end
    end
end

return Grid

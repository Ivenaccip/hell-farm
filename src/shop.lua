local C = require("src.constants")

local Shop = {}

-- Definición de todas las mejoras disponibles
Shop.UPGRADES = {
    { id = "speed",     label = "Speed",                desc = "+10% speed",              cost = 3  },
    { id = "hp",        label = "Extra Life",           desc = "+1 heart",                cost = 10 },
    { id = "autofarm",  label = "Faster Auto-farm",     desc = "-0.05s crop tick",        cost = 3  },
    { id = "corn_rate", label = "Corn Cadence",         desc = "-0.1s between shots",      cost = 2  },
    { id = "corn_dmg",  label = "Corn Damage",          desc = "+0.1 damage per bullet",  cost = 3  },
    { id = "pumpkin",   label = "Unlock Pumpkin",       desc = "Enables [Space] power",   cost = 5  },
}

-- Devuelve 2 mejoras aleatorias (filtra pumpkin si ya está desbloqueada)
function Shop.roll(player)
    local pool = {}
    for _, u in ipairs(Shop.UPGRADES) do
        if not (u.id == "pumpkin" and player.pumpkin_unlocked) then
            pool[#pool + 1] = u
        end
    end
    -- Fisher-Yates shuffle
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    return pool[1], pool[2] or pool[1]
end

-- Aplica la mejora elegida al player
function Shop.apply(id, player)
    if id == "speed" then
        player.speed = player.speed * 1.10
    elseif id == "hp" then
        player.hp_max = player.hp_max + 1
        player.hp     = math.min(player.hp + 1, player.hp_max)
    elseif id == "autofarm" then
        player.farm_rate = math.max(0.10, player.farm_rate - 0.05)
    elseif id == "corn_rate" then
        player.corn_cadencia = player.corn_cadencia + 0.1   -- reduce grow time
    elseif id == "corn_dmg" then
        player.corn_dmg = player.corn_dmg + 0.1
    elseif id == "pumpkin" then
        player.pumpkin_unlocked = true
    end
end

-- Dibuja la pantalla de tienda
function Shop.draw(player, opt_a, opt_b, small_font, big_font)
    local W, H = C.WIN_W, C.WIN_H

    -- Fondo
    love.graphics.setColor(0.04, 0.04, 0.09, 0.95)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Título
    love.graphics.setFont(big_font)
    love.graphics.setColor(1.0, 0.85, 0.20)
    local title = "SHOP"
    love.graphics.print(title, (W - big_font:getWidth(title)) * 0.5, 48)

    -- Monedas
    love.graphics.setFont(small_font)
    love.graphics.setColor(1.0, 0.85, 0.20)
    local coin_str = "Coins: " .. player.coins
    love.graphics.print(coin_str, (W - small_font:getWidth(coin_str)) * 0.5, 116)

    -- Dos tarjetas
    Shop.drawCard(opt_a, player.coins,  80, 180, 280, 210, "[1]", small_font)
    Shop.drawCard(opt_b, player.coins, 440, 180, 280, 210, "[2]", small_font)

    -- Guardar
    love.graphics.setColor(0.55, 0.55, 0.50)
    local save = "[S]  Save coins and continue"
    love.graphics.print(save, (W - small_font:getWidth(save)) * 0.5, H - 64)
end

function Shop.drawCard(upgrade, coins, x, y, w, h, key, font)
    local afford = coins >= upgrade.cost
    local fh     = font:getHeight()
    local pad    = 16

    -- Fondo tarjeta
    love.graphics.setColor(afford and {0.08, 0.16, 0.10} or {0.12, 0.08, 0.08})
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)

    -- Borde
    love.graphics.setColor(afford and {0.28, 0.65, 0.32} or {0.38, 0.25, 0.25})
    love.graphics.rectangle("line", x, y, w, h, 8, 8)

    local ty = y + pad

    -- Tecla
    love.graphics.setColor(0.55, 0.55, 0.50)
    love.graphics.print(key, x + pad, ty)
    ty = ty + fh + 2

    -- Nombre
    love.graphics.setColor(afford and {1.0, 1.0, 0.85} or {0.50, 0.40, 0.40})
    love.graphics.print(upgrade.label, x + pad, ty)
    ty = ty + fh + 6

    -- Descripción
    love.graphics.setColor(0.65, 0.65, 0.60)
    love.graphics.print(upgrade.desc, x + pad, ty)
    ty = ty + fh + 14

    -- Costo
    love.graphics.setColor(afford and {1.0, 0.85, 0.2} or {0.55, 0.35, 0.25})
    love.graphics.print("Cost: " .. upgrade.cost .. " coins", x + pad, ty)

    -- Sin fondos
    if not afford then
        love.graphics.setColor(1.0, 0.30, 0.30)
        local no = "Can't afford"
        love.graphics.print(no, x + w - font:getWidth(no) - pad, y + h - fh - pad)
    end
end

return Shop

-- Sistema de audio central de Hell Farm.
--
-- TOLERANTE A ARCHIVOS FALTANTES: si un archivo no existe todavía, ese sonido
-- simplemente no suena (no crashea). Suelta los archivos en assets/audio/ con los
-- nombres de abajo y empezarán a sonar solos, sin tocar código.
--
-- Formatos sugeridos: SFX en .wav (jsfxr/bfxr), música en .ogg (BeepBox -> Audacity/ffmpeg).

local Sfx = {}

local DIR = "assets/audio/"

-- Efectos cortos (se cargan como "static" y se clonan para permitir solapamiento).
local SFX_FILES = {
    plow        = "plow.wav",         -- arar (1) en la granja
    plant       = "plant.wav",        -- plantar (2) en la granja
    mature      = "mature.wav",       -- un cultivo madura (solo en la granja)
    tick        = "tick.wav",         -- cada segundo de la cuenta regresiva (nv2+)
    warning     = "warning.wav",      -- alarma del WARNING (baja el jefe)
    corn_shot   = "corn_shot.wav",    -- disparo de maíz (MUY frecuente: volumen bajo)
    pumpkin     = "pumpkin.wav",      -- poder de calabaza (escopeta, Espacio)
    hit_boss    = "hit_boss.wav",     -- un cultivo impacta al jefe / minijefe
    player_hurt = "player_hurt.ogg",  -- el jugador recibe daño
    boss_die    = "boss_die.wav",     -- el jefe muere
    spin        = "spin.wav",         -- ataque radial / giro
    enrage      = "enrage.wav",       -- segunda forma al 50% de vida
    teleport    = "teleport.wav",     -- teletransporte del jefe
    summon      = "summon.wav",       -- invoca minijefes
    minion_die  = "minion_die.wav",   -- muere un minijefe
    wall        = "wall.wav",         -- muro de balas
    buy         = "buy.wav",          -- comprar una mejora
    deny        = "deny.wav",         -- guardar monedas / no alcanza
    taunt       = "taunt.wav",        -- pantalla "¿Creíste que iba a ser tan fácil?"
    gameover    = "gameover.wav",     -- game over
}

-- Música en loop. Se elige el modo de carga según la extensión:
-- .wav -> "static" (se descomprime entero), comprimidos (.ogg/.mp3) -> "stream".
local MUSIC_FILES = {
    farm   = "music_farm.ogg",        -- loop calmado de la granja
    battle = "music_battle.ogg",      -- loop intenso (arranca con el WARNING)
    shop   = "music_shop.ogg",        -- loop / sting de la tienda
}

-- Volumen base por SFX (1.0 por defecto). Bajá los que se repiten mucho.
local SFX_VOL = {
    corn_shot = 0.30,
    tick      = 0.55,
    hit_boss  = 0.40,
    mature    = 0.55,
    deny      = 0.7,
    pumpkin   = 0.70,
}

-- SFX con tope de frecuencia (segundos mínimos entre reproducciones).
local THROTTLE = {
    corn_shot = 0.05,
    hit_boss  = 0.04,
}

local sfx        = {}    -- name -> Source plantilla (se clona al reproducir)
local music      = {}    -- name -> Source en loop
local last_play  = {}    -- name -> love.timer.getTime() de la última reproducción

Sfx.sfx_volume   = 0.85  -- volumen maestro de efectos
Sfx.music_volume = 0.45  -- volumen maestro de música

local current_music      = nil   -- Source de música sonando ahora
local current_music_name = nil   -- nombre lógico (aunque el archivo falte)
local fades              = {}    -- fades activos: { src, from, to, t, dur, stop_at_end }

-- Carga todo lo que exista. Llamar una vez en love.load().
function Sfx.load()
    -- IMPORTANTE (web/love.js): hay que comprobar que el archivo EXISTA con
    -- getInfo antes de llamar a newSource. En love.js, cargar un archivo
    -- inexistente aborta a nivel C y se salta el pcall (crashea el juego).
    -- Como muchos de estos audios todavía no estan, se omiten silenciosamente.
    for name, file in pairs(SFX_FILES) do
        if love.filesystem.getInfo(DIR .. file) then
            local ok, src = pcall(love.audio.newSource, DIR .. file, "static")
            if ok and src then sfx[name] = src end
        end
    end
    for name, file in pairs(MUSIC_FILES) do
        if love.filesystem.getInfo(DIR .. file) then
            local mode = file:match("%.wav$") and "static" or "stream"
            local ok, src = pcall(love.audio.newSource, DIR .. file, mode)
            if ok and src then
                src:setLooping(true)
                music[name] = src
            end
        end
    end
end

-- Reproduce un efecto. pitch_var (opcional): variación aleatoria de tono (±frac).
function Sfx.play(name, pitch_var)
    local template = sfx[name]
    if not template then return end   -- archivo no soltado aún: silencio

    local th = THROTTLE[name]
    if th then
        local now = love.timer.getTime()
        if last_play[name] and now - last_play[name] < th then return end
        last_play[name] = now
    end

    local s = template:clone()        -- clonar permite que se solapen
    s:setVolume((SFX_VOL[name] or 1.0) * Sfx.sfx_volume)
    if pitch_var and pitch_var > 0 then
        s:setPitch(1.0 + (love.math.random() * 2 - 1) * pitch_var)
    end
    s:play()
end

-- Procesa los desvanecimientos en curso. Llamar cada frame desde love.update().
function Sfx.update(dt)
    for i = #fades, 1, -1 do
        local f = fades[i]
        f.t = f.t + dt
        local k = math.min(1, f.t / f.dur)
        if f.src then f.src:setVolume(f.from + (f.to - f.from) * k) end
        if k >= 1 then
            if f.stop_at_end and f.src then f.src:stop() end
            table.remove(fades, i)
        end
    end
end

-- Cambia la música en loop. No reinicia si ya suena la misma.
-- fade_time (opcional, segundos): la música saliente se desvanece poco a poco y
-- la entrante sube desde silencio (crossfade). Sin él, el cambio es instantáneo.
function Sfx.playMusic(name, fade_time)
    if current_music_name == name then return end

    local prev = current_music
    if prev then
        if fade_time and fade_time > 0 then
            fades[#fades + 1] = { src = prev, from = prev:getVolume(), to = 0,
                                  t = 0, dur = fade_time, stop_at_end = true }
        else
            prev:stop()
        end
    end

    current_music_name = name
    local track = music[name]
    if track then
        track:stop()   -- reiniciar desde el principio
        if fade_time and fade_time > 0 then
            track:setVolume(0)
            track:play()
            fades[#fades + 1] = { src = track, from = 0, to = Sfx.music_volume,
                                  t = 0, dur = fade_time, stop_at_end = false }
        else
            track:setVolume(Sfx.music_volume)
            track:play()
        end
        current_music = track
    else
        current_music = nil
    end
end

function Sfx.stopMusic()
    if current_music then current_music:stop() end
    current_music      = nil
    current_music_name = nil
    fades = {}
end

return Sfx

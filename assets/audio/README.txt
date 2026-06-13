AUDIO DE HELL FARM
==================

Suelta aquí los archivos con EXACTAMENTE estos nombres y sonarán solos
(el juego no crashea si falta alguno: ese sonido simplemente no suena).

SFX (formato .wav — recomendado jsfxr.me o bfxr)
------------------------------------------------
plow.wav         arar (tecla 1) en la granja
plant.wav        plantar (tecla 2) en la granja
mature.wav       un cultivo madura (solo en la granja)
tick.wav         cada segundo de la cuenta regresiva (nivel 2+)
warning.wav      alarma del WARNING (baja el jefe)  <- imprescindible
corn_shot.wav    disparo de maiz (MUY frecuente: se reproduce a bajo volumen)
pumpkin.wav      poder de calabaza (escopeta, tecla Espacio)
hit_boss.wav     un cultivo impacta al jefe o a un minijefe
player_hurt.wav  el jugador recibe dano             <- imprescindible
boss_die.wav     el jefe muere                       <- imprescindible
spin.wav         ataque radial / giro
enrage.wav       segunda forma al 50% de vida
teleport.wav     teletransporte del jefe
summon.wav       invoca minijefes
minion_die.wav   muere un minijefe
wall.wav         muro de balas
buy.wav          comprar una mejora en la tienda
deny.wav         intento de compra sin monedas suficientes
taunt.wav        pantalla "Creiste que iba a ser tan facil?"
gameover.wav     game over

MUSICA (en loop — .wav o .ogg; el modo de carga se elige solo por extension)
---------------------------------------------------------------------------
music_farm.ogg     loop calmado de la granja
music_battle.wav   loop intenso (arranca con el WARNING)
music_shop.ogg     loop / sting de la tienda

AJUSTES
-------
Volumen maestro, volumen por SFX, tope de frecuencia y nombres de archivo
se editan en src/sfx.lua (tablas SFX_VOL, THROTTLE, Sfx.sfx_volume, Sfx.music_volume).

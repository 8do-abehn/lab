# Every villager in the village without a job (including nitwits, who can
# never get one on their own) gets the next profession in the rotation.
scoreboard players set #next sawyer_setup 0
execute positioned 0 65 0 as @e[type=villager,distance=..128,nbt={VillagerData:{profession:"minecraft:none"}}] at @s run function sawyer_village:assign
execute positioned 0 65 0 as @e[type=villager,distance=..128,nbt={VillagerData:{profession:"minecraft:nitwit"}}] at @s run function sawyer_village:assign

# The mansion already has vindicators and evokers. Put a pillager next to
# each one so they're indoors from the start.
execute positioned 440 65 0 at @e[type=#minecraft:illager,type=!pillager,distance=..128] run summon pillager ~ ~ ~ {PersistenceRequired:1b}

forceload remove all
scoreboard players set #stage sawyer_setup 2
say Sawyer's village: ready!

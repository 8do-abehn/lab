# Xp:1 locks the profession, so the villager keeps it (and its trades)
# even if it never reaches the workstation.
$data merge entity @s {VillagerData:{profession:"minecraft:$(profession)"},Xp:1}
# A workstation beside it lets it restock. "keep" only fills air, so try
# each side until one fits and stop there.
scoreboard players set #placed sawyer_setup 0
$execute if score #placed sawyer_setup matches 0 store success score #placed sawyer_setup run setblock ~1 ~ ~ minecraft:$(block) keep
$execute if score #placed sawyer_setup matches 0 store success score #placed sawyer_setup run setblock ~-1 ~ ~ minecraft:$(block) keep
$execute if score #placed sawyer_setup matches 0 store success score #placed sawyer_setup run setblock ~ ~ ~1 minecraft:$(block) keep
$execute if score #placed sawyer_setup matches 0 store success score #placed sawyer_setup run setblock ~ ~ ~-1 minecraft:$(block) keep

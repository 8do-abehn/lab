# Chunks load over a few ticks, so a place can fail with "not loaded".
# Each structure is only attempted until it succeeds, then this retries.
execute unless score #village sawyer_setup matches 1 store success score #village sawyer_setup run place structure minecraft:village_plains 0 65 0
# Mansions refuse to generate below y=60, which is why the flat layers put
# the ground at y=64 rather than the usual superflat y=-61. Its origin at
# x=1360 puts it about 1000 blocks east of the village: too far to see from
# spawn (render distance tops out near 500), so it's a trek to find it, and
# far beyond any illager's reach of the villagers.
execute unless score #mansion sawyer_setup matches 1 store success score #mansion sawyer_setup run place structure minecraft:mansion 1360 65 0

execute if score #village sawyer_setup matches 1 if score #mansion sawyer_setup matches 1 run function sawyer_village:placed
execute unless score #stage sawyer_setup matches 1.. run schedule function sawyer_village:place 40t

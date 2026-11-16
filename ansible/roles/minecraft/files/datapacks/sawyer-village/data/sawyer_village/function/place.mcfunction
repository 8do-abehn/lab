# Chunks load over a few ticks, so a place can fail with "not loaded".
# Each structure is only attempted until it succeeds, then this retries.
execute unless score #village sawyer_setup matches 1 store success score #village sawyer_setup run place structure minecraft:village_plains 0 65 0
# Mansions refuse to generate below y=60, which is why the flat layers put
# the ground at y=64 rather than the usual superflat y=-61. Its origin at
# x=240 puts its near wall about 200 blocks east of the village edge: just
# past what the server sends from spawn (12 chunks, 192 blocks), so it comes
# into view a short walk east, and well beyond any illager's reach of the
# villagers.
execute unless score #mansion sawyer_setup matches 1 store success score #mansion sawyer_setup run place structure minecraft:mansion 240 65 0

execute if score #village sawyer_setup matches 1 if score #mansion sawyer_setup matches 1 run function sawyer_village:placed
execute unless score #stage sawyer_setup matches 1.. run schedule function sawyer_village:place 40t

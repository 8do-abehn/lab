# Land exactly at the village instead of somewhere within 10 blocks of it.
gamerule respawn_radius 0
setworldspawn 0 65 0

# /place refuses to build into unloaded chunks, and 26.x has no
# always-loaded spawn chunks. Load the village (about 128 blocks around
# 0,0) and the mansion plot to the east. 256 chunks max per command.
forceload add -128 -128 -1 127
forceload add 0 -128 95 127
forceload add 96 -128 271 127

say Sawyer's village: building the world...
schedule function sawyer_village:place 40t

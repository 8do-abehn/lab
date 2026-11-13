# Runs on every server start. The #stage score lives in the world, so the
# setup happens once per world and a restart mid-setup picks up where it
# stopped instead of placing a second village.
#   0 = nothing yet, 1 = structures placed, 2 = done
scoreboard objectives add sawyer_setup dummy
execute unless score #stage sawyer_setup matches 1.. run function sawyer_village:start
execute if score #stage sawyer_setup matches 1 run schedule function sawyer_village:jobs 200t

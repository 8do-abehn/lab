# Librarian first (enchanted books), then the rest of the 13 professions.
execute if score #next sawyer_setup matches 0 run function sawyer_village:job/give {profession:"librarian",block:"lectern"}
execute if score #next sawyer_setup matches 1 run function sawyer_village:job/give {profession:"armorer",block:"blast_furnace"}
execute if score #next sawyer_setup matches 2 run function sawyer_village:job/give {profession:"toolsmith",block:"smithing_table"}
execute if score #next sawyer_setup matches 3 run function sawyer_village:job/give {profession:"weaponsmith",block:"grindstone"}
execute if score #next sawyer_setup matches 4 run function sawyer_village:job/give {profession:"cleric",block:"brewing_stand"}
execute if score #next sawyer_setup matches 5 run function sawyer_village:job/give {profession:"fletcher",block:"fletching_table"}
execute if score #next sawyer_setup matches 6 run function sawyer_village:job/give {profession:"cartographer",block:"cartography_table"}
execute if score #next sawyer_setup matches 7 run function sawyer_village:job/give {profession:"butcher",block:"smoker"}
execute if score #next sawyer_setup matches 8 run function sawyer_village:job/give {profession:"leatherworker",block:"cauldron"}
execute if score #next sawyer_setup matches 9 run function sawyer_village:job/give {profession:"mason",block:"stonecutter"}
execute if score #next sawyer_setup matches 10 run function sawyer_village:job/give {profession:"shepherd",block:"loom"}
execute if score #next sawyer_setup matches 11 run function sawyer_village:job/give {profession:"fisherman",block:"barrel"}
execute if score #next sawyer_setup matches 12 run function sawyer_village:job/give {profession:"farmer",block:"composter"}
scoreboard players add #next sawyer_setup 1
execute if score #next sawyer_setup matches 13.. run scoreboard players set #next sawyer_setup 0

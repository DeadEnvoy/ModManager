# Mod Categories

Mod Manager allows mod authors to assign categories to their mods for better organization and filtering. This guide lists all available categories and explains how to use them.

## Available Categories

The following 40 categories are available for mod authors to assign:

| Category | Description |
|----------|-------------|
| **Animals** | Mods that add or modify animals, wildlife, pets, or animal-related mechanics |
| **Animations** | Mods that add or modify animations, animation sets, or animation behavior |
| **Armor** | Mods focused on protective gear, armor systems, and defensive equipment |
| **Audio** | Mods that add or modify sounds, music, ambient audio, or audio systems |
| **Balance** | Mods that adjust game balance, difficulty, or gameplay mechanics |
| **Building** | Mods related to construction, building mechanics, or new structures |
| **Crafting** | Mods that add or modify crafting recipes, systems, or mechanics |
| **Clothing** | Mods that add or modify clothing, outfits, or wearable items |
| **Climate** | Mods related to weather, temperature, seasons, or climate systems |
| **Equipment** | Mods that add or modify gear, loadouts, and usable equipment |
| **Farming** | Mods related to agriculture, farming, crops, or gardening |
| **Food** | Mods that add or modify food items, cooking, or nutrition systems |
| **Framework** | Library mods, APIs, or frameworks that other mods depend on |
| **Immersion** | Mods that improve atmosphere, authenticity, and overall immersion |
| **Interface** | Mods that modify or add UI elements, HUD, menus, or interface systems |
| **Items** | Mods that add or modify general items, objects, or inventory systems |
| **Lighting** | Mods that add or modify lighting, visibility, or light effects |
| **Localization** | Translation mods or language packs |
| **Literature** | Mods that add books, magazines, notes, or readable content |
| **Map** | Mods that add new maps, locations, or modify existing areas |
| **Misc** | Miscellaneous mods that don't fit other categories |
| **Models** | Mods that add or modify 3D models, animations, or visual assets |
| **Modpack** | Collections of multiple mods bundled together |
| **Multiplayer** | Mods specifically designed for or enhancing multiplayer gameplay |
| **Overhaul** | Mods that broadly rework multiple systems or major parts of gameplay |
| **Performance** | Mods focused on FPS improvements, optimization, and performance tuning |
| **QoL** | Quality of Life improvements and convenience features |
| **Quests** | Mods that add quest systems, missions, or objectives |
| **Realistic** | Mods that add realism or simulation elements |
| **Roleplay** | Mods focused on roleplay mechanics, interactions, or storytelling |
| **Scenario** | Mods that add new game scenarios or challenge modes |
| **Silly/Fun** | Humorous, joke, or entertainment-focused mods |
| **Skills** | Mods that add or modify character skills and progression |
| **Textures** | Mods that add or modify textures, sprites, or visual appearance |
| **Traits** | Mods that add or modify character traits and perks |
| **Utility** | Utility mods that improve workflows, setup, or support features |
| **Vehicles** | Mods that add or modify vehicles, vehicle mechanics, or transportation |
| **Voices** | Mods that add or modify voices, speech, or vocal audio content |
| **Weapons** | Mods that add or modify weapons, ammunition, or combat systems |
| **Zombies** | Mods that add or modify zombie behavior, types, or mechanics |

## How to Assign a Category

### For Mod Authors

To assign a category to your mod, add the `category=` field to your `mod.info` file:

```
name=My Awesome Mod
id=MyAwesomeMod
description=A great mod that adds new weapons
poster=poster.png
category=Weapons
```

**Important Notes:**
- Add `category=CategoryName` to your `mod.info` file
- Replace `CategoryName` with one of the categories from the table above
- Category names are **case-sensitive** (use exact spelling: `Weapons`, not `weapons`)
- Only assign **one category** per mod
- Once set by the author, players cannot change it (unless the author hasn't set one)

**Example `mod.info` files:**

```
name=Weapon Pack
id=MyWeaponPack
description=Adds 50 new weapons
category=Weapons
```

```
name=Farming Overhaul
id=FarmingOverhaul
description=Improves farming mechanics
category=Farming
```

```
name=UI Improvements
id=UIImprovements
description=Better interface and HUD
category=Interface
```

### Category Name Aliases

The following aliases are automatically converted:

| Alias | Converts To |
|-------|-------------|
| `Vehicle` | `Vehicles` |
| `Utilities` | `Utility` |

## Best Practices

### For Mod Authors

1. **Choose the most specific category** that describes your mod's primary purpose
2. **Set the category in mod.info** before publishing to Steam Workshop
3. **Use Framework** for library mods that other mods depend on
4. **Use Modpack** only for collections of multiple mods
5. **Avoid Misc** unless your mod truly doesn't fit any other category

### Category Selection Guide

**If your mod adds...**
- New weapons → `Weapons`
- New vehicles → `Vehicles`
- UI improvements → `Interface`
- New map areas → `Map`
- Crafting recipes → `Crafting`
- Quality of life features → `QoL`

**If your mod is...**
- A library/API → `Framework`
- A translation → `Localization`
- A collection of mods → `Modpack`
- Focused on realism → `Realistic`
- Humorous/joke mod → `Silly/Fun`

**If your mod modifies...**
- Game balance → `Balance`
- Character traits → `Traits`
- Skills system → `Skills`
- Multiplayer features → `Multiplayer`

## Technical Details

- Invalid category names are ignored
- Case-insensitive lookup is performed with automatic correction
- If a category is not recognized, it defaults to no category

## Troubleshooting

**Category not showing?**
- Verify the category name is spelled correctly (case-sensitive)
- Check that the `category=` line is in your `mod.info` file

**Category not saving?**
- Verify your `mod.info` file is properly formatted
- Check that the category name matches one from the list exactly
- Reload the mod list in-game

**Players can still change the category?**
- This means the category wasn't set in `mod.info`
- Add `category=CategoryName` to your `mod.info` file
- Republish your mod to Steam Workshop
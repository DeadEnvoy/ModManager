# 1.5.7
**FIXES**
- Fixed a bug where mod data could not be saved or updated.
    - The 42.20.0 update restricted getFileWriter to a whitelist of extensions (ini, cfg, txt, log) — .lua files are no longer writable. Existing data is migrated to .ini automatically on first launch.

# 1.5.6
**UI**
- Improved the tooltip that appears when hovering over the incompatible mods block if the text overflows.
- [Mod Update and Alert System](https://steamcommunity.com/sharedfiles/filedetails/?id=3077900375).
    - When no mods have been updated in the last two weeks, a notice is shown instead of an empty panel.

**FIXES**
- Fixed missing "Exit to Main Menu" option introduced in the 42.20.0 update.

**TECHNICAL**
- 42.18 - 42.19 support has been discontinued.

# 1.5.5
**FIXES**
- Fixed missing "Choose mods" button broken by the latest update (42.19.0).

# 1.5.4
**FIXES**
- Fixed an issue with an invalid tooltip key ([#4](https://github.com/DeadEnvoy/ModManager/issues/4)).

# 1.5.3
**FIXES**
- Server settings performance and stability.
    - Optimized batch adding of mods and maps.
    - Fixed a crash in the server settings screen caused by invalid map data.
    - Fixed the comboBox refresh order when adding a map.

# 1.5.2
**UI**
- Added a fallback icon for mods that don't provide one.
- Mods whose authors accept donations now show a support indicator.

**MODDING**
- Mod authors can now add support options to mod.info.
    - Supported services: Ko-fi, Buy Me a Coffee, Patreon, Boosty, DonationAlerts, Tribute.
- Fixed Markdown-to-plain-text conversion for quoted links and issue references.

**FIXES**
- Fixed a crash when opening the mod list ([#1](https://github.com/DeadEnvoy/ModManager/issues/1)).

# 1.5.1
**MODDING**
- The list of assignable categories has been adjusted.
    - Added 11 new categories: "Animations", "Climate", "Equipment", "Immersion", "Lighting", "Overhaul", "Performance", "Roleplay", "Utility", "Voices" and "Zombies".
    - Removed categories: "Hardmode" and "Military".

**FIXES**
- Fixed duplication in Russian localization.

# 1.5.0
**NEW**
- Server settings screen has been redesigned and simplified.
    - Navigating to the server settings screen no longer triggers a Lua reset.
    - "Mods", "Maps", and "Spawnpoints" tabs have been fixed and improved, while "Steam Workshop" has been removed.
    - Full synchronization between server "Mods" and "WorkshopItems" has been added.
    - Maps and spawn points now account for their lots when added/removed.
- Added the ability to categorize modifications.
    - Authors can now assign one of over 30 categories to their modifications.
    - Players can manually assign a category to a modification, but only if the author hasn't done so.

**UI**
- The modifications window has undergone changes.
    - Category filtering has been added.
    - "Add" and "Share" buttons have been returned to the main window.
    - A warning dialog now appears when deleting a preset.
- The mod information panel has been improved.
    - Mod category display has been added.
    - If a mod name exceeds the allowed length, it will be truncated.
    - Hovering over a truncated name will display it in its original form.
    - The compatible mods panel has been simplified, and the incompatible mods panel has been improved.
- Changelog display in the mod panel has been improved.
    - Information about older versions is now displayed in a semi-transparent style.
- Windows, icons, and UI elements now adapt to resolution.

**MODDING**
- A documentation section has been added to the project directory.
- Publishing modifications to Steam Workshop has been changed.
    - Automatic conversion of Markdown changelog format to Steam BBCode has been added.
    - The ability to choose changelog format when publishing a mod has been removed.
- Adding images to the mod settings window has been simplified.

**FIXES**
- [Mod Update and Alert System](https://steamcommunity.com/sharedfiles/filedetails/?id=3077900375).
    - Added pcall wrapper to prevent crash on Linux when mod is missing.
    - Markdown file parsing method has been adapted to the new format.
- Fixed a bug where the changelog scrollbar did not respond to clicks.
- Fixed a bug where changelog text overlapped the scrollbar.
- Fixed a bug with incorrect display of the number of active mods.
- Fixed a bug where the "Hidden" flag was not applied.
- Fixed a bug with non-ASCII character display.

**TECHNICAL**
- The method of storing mod data has been optimized and improved.
- Added incompatibility with [Zed's Better ModList](https://steamcommunity.com/sharedfiles/filedetails/?id=3709229404), [Workshop Update Checker](https://steamcommunity.com/sharedfiles/filedetails/?id=3628835042), [Better Server Settings](https://steamcommunity.com/sharedfiles/filedetails/?id=2756434288), and [Multiplayer UI](https://steamcommunity.com/sharedfiles/filedetails/?id=3721379606).
- Localization in all languages has been updated taking into account the typography features of each.
- 42.12.0 - 42.16.2 support has been discontinued.

# 1.4.1
- Updated mod Workshop ID detection logic.
- All localization files migrated to the new format.
- Added an option to select changelog formatting when publishing mods to the Steam Workshop.
- Added automatic conversion of the old preset format (including backward compatibility).
- Added path display for local modifications (Workshop, Mods).
- Fixed a bug where mod settings might not apply.

# 1.4.0
- Added preset manager.
- Added Workshop ID export for modifications.
- Mod Manager is no longer affected by mass disabling.
- Hidden mods are no longer affected by mass enabling.
- Hidden mods are automatically unhidden when enabled.
- Completely refactored ModOptionsScreen code (reduced from ~1500 to ~800 lines).
- Added auto-fill for Change Notes when publishing a mod (if Changelog is detected).
- Changed Mod Manager data reading and saving method.
- Favorite icon now only appears on hover.
- Removed unnecessary dependencies.

# 1.3.1
- Added "Better Server Settings" as a dependency (42.13+).
- Added a rate limit for requests to Steam and a new method for sending/receiving them.
- ChuckleberryFinnAlertSystem now displays all mods that have been updated in the last two weeks (if they have a Changelog).

# 1.3.0
- Added sorting by update date.
- Simplified mod information panel.
- Added last update date display to mod panel.
- Added status display for up-to-date and outdated mods.
- Fixed vanilla bugs where the game couldn't find Workshop ID and mod dependencies.
- Fixed bug where mod panel might not update during navigation.
- Added accelerated navigation when holding arrow keys.
- Added localization for all mod panel labels.

Note: While update tracking works correctly, Steam doesn't always return the proper state (Outdated/NeedsUpdate) for mods, so you shouldn't rely solely on the "Up to date" status. Check for mod updates manually using the sort by last update date feature.

# 1.2.0
- Merged changes from updated original files.
- Added arrow key navigation between mods and toggle via spacebar.
- Optimized dependency storage architecture & vanilla logic for bulk enabling/disabling mods.
- Added coloring for enabling mods to distinguish from active ones.
- Fixed incorrect button position in pause menu (multiplayer).
- Added display of total mod count.
- Updated localization.

# 1.1.0
- Mod search now always displays hidden mods.
- Added the ability for mod authors to add images in the configuration window.
- Added a warning dialog when disabling library mods and those that other mods depend on.
- The width of the mod tabs area has been limited.

# 1.0.8
- Minor fixes and code refactoring.

# 1.0.7
- Fixed compatibility issue with mods that add their own settings directly to MainOptions.

# 1.0.6
- The mod settings window remembers the last selected mod before sorting is applied.

# 1.0.5
- ModOptionsScreen: Sorting was restored.

# 1.0.4
- ModOptionsScreen: Sorting was temporarily disabled.

# 1.0.3
- Adjusted the minimum width for the mod tabs area.
- Added a name/date sorting option for the mod settings window.
- Fixed a bug with incorrect key assignment and initialization.

# 1.0.2
- Fixed a bug where saved mod settings weren't loading when starting the game.

# 1.0.1
- Added a search field for modification settings.
- Changed the color of the "SORT & ACCEPT" button.
- Adjusted the width of the modification settings window.
- Fixed a bug where element descriptions weren't rendering.
- Fixed incompatibility with Change Sandbox Options.

# 1.0.0
- Initial release.
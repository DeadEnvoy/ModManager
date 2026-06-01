# How to Add Changelog to Your Mod

Mod Manager supports displaying changelogs for mods in the mod selector screen. This guide explains how to create and format changelog files for your mod.

## File Location

Place your changelog file in the **root directory of your mod** (same level as `mod.info`):

```
YourMod/
├── mod.info
├── ChangeLog.md    ← Markdown format (recommended)
└── ChangeLog.txt   ← Plain text format (legacy)
```

**Priority:** If both files exist, `ChangeLog.md` takes precedence.

## Supported Formats

### 1. Modern Markdown Format (Recommended)

**File:** `ChangeLog.md`

Use standard Markdown with `# Version` headers. The **first version** in the file is treated as the **latest**.

#### Basic Structure

```markdown
# 1.2.0

- Fixed bug with inventory
- Added new feature X
- Improved performance

# 1.1.0

- Initial release
```

#### Version Header Formats

All of these are valid:

```markdown
# 1.2.0
# [1.2.0]
# 1.2.0 - Bug fixes
# Version 1.2.0
```

#### Supported Markdown Syntax

**Inline formatting:**
- `**bold**` or `__bold__` → bold text
- `*italic*` or `_italic_` → italic text
- `***bold italic***` → bold + italic
- `~~strikethrough~~` → strikethrough
- `` `code` `` → inline code
- `[link text](url)` → hyperlink

**Block elements:**
- `# Header 1`, `## Header 2`, `### Header 3` → headers
- `> quote` → blockquote
- `---`, `***`, `___` → horizontal rule
- `` ``` `` code blocks → multi-line code
- `- item` or `* item` or `+ item` → unordered list
- `1. item` → ordered list
- Nested lists (indent with 4 spaces or 1 tab)

**HTML comments** (ignored):
```markdown
<!-- This comment will be ignored -->
```

#### Example

```markdown
# 1.3.0

## New Features
- Added **multiplayer support**
- Implemented `saveGame()` function

## Bug Fixes
- Fixed crash when opening inventory
- Resolved issue with *item duplication*

## Known Issues
> Some players may experience lag in large bases

# 1.2.0

- Initial release
```

### 2. Legacy Markdown Format

**File:** `ChangeLog.md`

Uses `### Version ###` headers. The **last version** in the file is treated as the **latest**.

```markdown
### 1.0.0 ###
- Initial release
#

### 1.1.0 ###
- Bug fixes
#
```

**Separator:** Use `#` on a separate line to end a version block.

**Note:** This format is auto-detected and supported for backward compatibility. New mods should use the modern format.

### 3. Plain Text Format

**File:** `ChangeLog.txt`

Uses `[Version]` or `### Version ###` headers. The **last version** in the file is treated as the **latest**.

```txt
[1.1.0]
- Bug fixes
- Performance improvements

[----------]

[1.0.0]
- Initial release
```

**Separators:**
- `[----------]` or `[---]` → ends a version block
- `#` → ends a version block

**Note:** Plain text format does not support Markdown formatting.

## Display Behavior

### In Mod Selector

When a user selects your mod, the changelog is displayed in the **Changelog** tab of the mod info panel:

- **Latest version** is shown in **bright text** (RGB: 0.8, 0.8, 0.8)
- **Older versions** are shown in **dimmed text** (RGB: 0.4, 0.4, 0.4)
- Versions are listed in **chronological order** (newest first for modern Markdown, oldest first for legacy formats)

### In Workshop Submit

When publishing your mod to Steam Workshop, [B42] Mod Manager automatically:

1. Reads the **latest version** from your changelog
2. Converts Markdown to **Steam BBCode** format
3. Populates the **Change Notes** field

**Supported BBCode conversions:**
- `[b]bold[/b]`, `[i]italic[/i]`, `[strike]strikethrough[/strike]`
- `[code]code[/code]`, `[url=link]text[/url]`
- `[h1]`, `[h2]`, `[h3]` → headers
- `[list][*]item[/list]` → unordered list
- `[olist][*]item[/olist]` → ordered list
- `[quote]text[/quote]` → quote
- `[hr][/hr]` → horizontal rule

## Best Practices

1. **Use Modern Markdown format** (`ChangeLog.md`) for new mods
2. **Place newest versions first** in modern Markdown format
3. **Use semantic versioning** (e.g., `1.2.3`)
4. **Group changes by category** (New Features, Bug Fixes, etc.)
5. **Keep entries concise** and user-friendly
6. **Test your changelog** by viewing it in the mod selector before publishing

## Example: Complete Changelog

```markdown
# 2.0.0 - Major Update

## New Features
- **Multiplayer support** for up to 32 players
- Added new crafting recipes
- Implemented auto-save feature

## Changes
- Improved UI responsiveness
- Optimized memory usage by ~30%

## Bug Fixes
- Fixed crash when opening large containers
- Resolved item duplication exploit
- Fixed typo in tooltip text

## Known Issues
> Players may experience FPS drops in heavily modded servers

# 1.5.1

- Hotfix: Fixed critical save corruption bug
- Updated translations

# 1.5.0

- Added French and German translations
- New items: 10 new weapons
- Balance changes to existing items

# 1.0.0

- Initial release
```

## Troubleshooting

**Changelog not showing?**
- Verify file name is exactly `ChangeLog.md` or `ChangeLog.txt` (case-sensitive)
- Check file is in mod root directory (same level as `mod.info`)
- Ensure version headers follow the correct format

**Formatting looks wrong?**
- Test Markdown syntax in a Markdown editor first
- Avoid mixing legacy and modern formats in the same file
- Check for unclosed code blocks (` ``` `)

**Workshop change notes not updating?**
- Ensure the latest version is at the **top** of the file (modern format)
- Verify Markdown syntax is valid
- Check that the version block has content (not empty)
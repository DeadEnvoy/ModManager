# Adding Images to Mod Options

## API Reference

```lua
modOptions:addImage(imagePath, width)
```

### Parameters

- **imagePath** (string, required) — Path to the image texture relative to mod root
- **width** (number, optional) — Width ratio from `0.0` to `1.0` (`1.0` = 100% of available width)

### Behavior

- Images always expand to fill available panel width by default
- If `width` is specified, it is treated as a width ratio (`0.0..1.0`) of available panel width
- Values greater than `1.0` are normalized to `1.0`, values below `0.0` are normalized to `0.0`
- Aspect ratio is always preserved
- Images are automatically centered horizontally

## Usage Examples

### Basic image (expands to full width)

```lua
modOptions:addImage("media/ui/preview.png")
```

### Image with custom width ratio

```lua
modOptions:addImage("media/ui/preview.png", 0.5)
```

The image will occupy 50% of available panel width.

## Complete Integration Example

```lua
require "ModManager/PZAPI"

local modOptions = PZAPI.ModOptions:create("ModID", "ModName")

-- Check if addImage is available (backward compatibility)
if modOptions.addImage then
    modOptions:addImage("media/ui/ModManager/preview.png")
    modOptions:addImage("media/ui/ModManager/logo.png", 0.65)
end

-- Add other options
modOptions:addTickBox("myOption", "Enable Feature", false)
```

## Notes

- Supported formats: PNG, JPG (any format supported by Project Zomboid's `getTexture()`)
- The old `fit` boolean parameter is deprecated but still accepted for backward compatibility (it will be ignored)
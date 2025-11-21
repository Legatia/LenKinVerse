# Rarity Configuration

This file explains how to configure element rarities in `rarity_config.json`.

## File Structure

```json
{
  "rarity_levels": {
    "0": {
      "name": "Common",
      "color": "#9CA3AF",
      "description": "Basic elements found everywhere"
    }
  },
  "elements": {
    "lkC": 0,
    "CO2": 1
  },
  "default_rarity": 0
}
```

## Rarity Levels

Define your rarity tiers (0-3 recommended):

- **0**: Common (Gray #9CA3AF)
- **1**: Uncommon (Green #10B981)
- **2**: Rare (Blue #3B82F6)
- **3**: Legendary (Purple #8B5CF6)

You can add more levels or customize colors using hex codes.

## Element Rarities

Map each element ID to a rarity level (0-3):

```json
"elements": {
  "lkC": 0,        // Common basic element
  "CO2": 1,        // Uncommon compound
  "Coal": 2,       // Rare processed material
  "Carbon_X": 3    // Legendary special material
}
```

## Default Rarity

Elements not listed in the config will use `default_rarity` (typically 0 for Common).

## Usage

1. Add new elements to the `"elements"` section
2. Assign a rarity level (0-3)
3. The game will automatically use these values for:
   - Discovery celebration modal colors
   - Element display in codex
   - NFT metadata rarity

## Tips

- Basic collected elements (lkC, lkO, lkH, etc.) should be rarity 0
- Simple reaction products (CO2, H2O) should be rarity 1
- Processed/refined materials should be rarity 2
- Special discoveries or rare materials should be rarity 3
- You can customize rarity colors by changing hex values in `rarity_levels`

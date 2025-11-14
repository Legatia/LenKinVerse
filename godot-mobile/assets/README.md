# LenKinVerse Assets

This folder contains all visual assets for the game. Assets are referenced through `asset_config.json` for easy management.

## Folder Structure

```
assets/
├── asset_config.json       # Main config - maps IDs to file paths
├── README.md              # This file
├── furniture/             # Furniture sprites and icons
├── ui/                    # UI icons and buttons
├── elements/              # Element icons (by rarity)
├── planets/               # Planet backgrounds and floors
├── reactions/             # Reaction type icons
├── effects/               # Particle effects and animations
└── tutorial/              # Tutorial arrows and indicators
```

## How to Add Assets

### 1. Create your SVG/PNG file
- **Recommended formats**: SVG (vector), PNG (raster)
- **Naming**: Use lowercase with underscores (e.g., `storage_box.svg`)

### 2. Place in appropriate folder
```bash
# Example: Adding a storage box icon
assets/furniture/storage_box.svg

# Example: Adding element icons
assets/elements/carbon_common.svg
assets/elements/carbon_rare.svg
assets/elements/carbon_legendary.svg
```

### 3. Update asset_config.json
```json
{
  "furniture": {
    "storage_box": {
      "icon": "res://assets/furniture/storage_box.svg",
      "sprite": "res://assets/furniture/storage_box_large.svg",
      "fallback_emoji": "📦",
      "size": [80, 80]
    }
  }
}
```

### 4. Reference in game code
```gdscript
# Get asset with automatic fallback to emoji if file doesn't exist
var icon = AssetManager.get_furniture_icon("storage_box")
var element_icon = AssetManager.get_element_icon("lkC", 2)  # rarity 2
```

## Asset Specifications

### Furniture
- **Size**: 80×80 pixels
- **Format**: SVG or PNG
- **Style**: Isometric or top-down view
- **Files needed**:
  - `icon` - Small icon (shown in world)
  - `sprite` - Larger detailed sprite

### UI Icons
- **Size**: 40×40 or 60×60 pixels
- **Format**: SVG preferred (scales better)
- **Style**: Flat, minimal, consistent theme
- **Examples**: Profile button, storage icon, marketplace icon

### Elements
- **Icon size**: 32×32 or 64×64 pixels
- **Card size**: 256×256 pixels (for NFT metadata)
- **Format**: SVG or PNG with transparency
- **Rarity variants**: Each element should have icons for each rarity level
  - `rarity_0` - Common (gray/white border)
  - `rarity_1` - Uncommon (green border)
  - `rarity_2` - Rare (blue border)
  - `rarity_3` - Legendary (purple/gold border)

### Planets
- **Background**: 360×640 pixels (full screen)
- **Floor**: 320×520 pixels (playable area)
- **Icon**: 64×64 pixels
- **Format**: SVG or PNG
- **Style**: Match blockchain theme (Solana purple, Base blue, Sui cyan)

### Reactions
- **Size**: 48×48 pixels
- **Format**: SVG or PNG
- **Style**: Icon representing reaction type
  - Physical: Hammer/compression
  - Chemical: Beaker/flask
  - Nuclear: Atom/radiation symbol

### Effects
- **Size**: Varies (16×16 to 128×128)
- **Format**: SVG or PNG with transparency
- **Style**: Animated-ready particles
- **Examples**: Success sparkles, failure smoke, discovery glow

## Fallback System

If an asset file doesn't exist yet, the game automatically falls back to emojis defined in `asset_config.json`:

```json
{
  "furniture": {
    "storage_box": {
      "fallback_emoji": "📦"  // Used until SVG is added
    }
  }
}
```

This means:
- ✅ **You can develop UI first** without needing final art
- ✅ **Artists can work independently** by just adding files to folders
- ✅ **No code changes needed** when assets are added

## Asset Caching

Assets are automatically cached after first load. To reload after changes:

```gdscript
AssetManager.reload()  # Clears cache and reloads config
```

## Example Workflow

### For Developers (Before Art):
1. Define asset in `asset_config.json` with fallback emoji
2. Use `AssetManager.get_*()` in code
3. Game displays emoji until artist provides file

### For Artists:
1. Create SVG/PNG file matching spec
2. Name file according to config
3. Drop in appropriate folder
4. Test in game - should appear automatically!

### For Both:
1. Update `asset_config.json` to link new assets
2. Commit both config and asset files
3. Everyone gets the new assets

## External Asset Hosting

For NFT metadata images (displayed outside the game):
- Original files: `assets/elements/*_card.png`
- Hosted at: `https://lenkinverse.com/assets/elements/`
- Configured in: `AssetManager.get_element_image_url()`

Update the CDN URL in `asset_manager.gd` when you have hosting set up.

## Tips

### SVG Optimization
```bash
# Use SVGO to optimize SVGs
npx svgo assets/elements/carbon.svg
```

### PNG Export from Figma/Sketch
- Export at 2x or 3x resolution
- Use PNG-8 for icons (smaller file size)
- Use PNG-24 with transparency for sprites

### Color Palette (for consistency)
```
Solana Purple: #9945FF
Base Blue: #0052FF
Sui Cyan: #6FBCF0
Common: #9CA3AF
Uncommon: #10B981
Rare: #3B82F6
Legendary: #8B5CF6
```

## Questions?

Check `autoload/asset_manager.gd` for the implementation details and available methods.

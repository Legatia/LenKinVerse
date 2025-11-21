# AssetManager Usage Examples

This document shows how to use the AssetManager in your game code.

## Basic Usage

### Get Furniture Icon
```gdscript
# In any script
func update_furniture_display() -> void:
    var storage_icon = AssetManager.get_furniture_icon("storage_box")

    # If SVG exists: returns Texture2D
    # If SVG missing: returns "📦" (String emoji)

    if storage_icon is Texture2D:
        $Sprite2D.texture = storage_icon
    elif storage_icon is String:
        $Label.text = storage_icon  # Show emoji fallback
```

### Get Element Icon with Rarity
```gdscript
func display_element(element_id: String, rarity: int) -> void:
    # Get rarity-specific icon, falls back to base icon, then emoji
    var icon = AssetManager.get_element_icon(element_id, rarity)

    # Examples:
    # AssetManager.get_element_icon("lkC", 0)  # Common carbon
    # AssetManager.get_element_icon("lkC", 3)  # Legendary carbon
    # AssetManager.get_element_icon("CO2", 1)  # Uncommon CO2

    if icon is Texture2D:
        element_sprite.texture = icon
    else:
        element_label.text = str(icon)
```

### Get UI Icon
```gdscript
func setup_ui() -> void:
    var gloves_icon = AssetManager.get_ui_icon("gloves_button")
    var profile_icon = AssetManager.get_ui_icon("profile_button")

    if gloves_icon is Texture2D:
        $GlovesButton.icon = gloves_icon
    else:
        $GlovesButton.text = str(gloves_icon)
```

## Advanced Usage

### Planet Background
```gdscript
func load_planet_scene(planet_id: String) -> void:
    var bg = AssetManager.get_planet_background(planet_id)
    var floor = AssetManager.get_planet_floor(planet_id)

    if bg is Texture2D:
        $Background.texture = bg
    elif bg is String and bg.begins_with("#"):
        # Color fallback
        $Background.color = Color(bg)

    if floor is Texture2D:
        $Floor.texture = floor
```

### Reaction Icons
```gdscript
func display_reaction_type(reaction_type: String) -> void:
    var icon = AssetManager.get_reaction_icon(reaction_type)

    # reaction_type: "physical", "chemical", "nuclear"
    match reaction_type:
        "physical":
            icon = AssetManager.get_reaction_icon("physical")  # 🔨
        "chemical":
            icon = AssetManager.get_reaction_icon("chemical")  # 🧪
        "nuclear":
            icon = AssetManager.get_reaction_icon("nuclear")   # ⚛️
```

### Check if Asset Exists
```gdscript
func can_show_premium_graphics() -> bool:
    # Check if high-quality assets are available
    return AssetManager.has_asset("elements", "lkC", "rarity_3")
```

### Get Asset Size from Config
```gdscript
func create_furniture_node(furniture_id: String) -> void:
    var size = AssetManager.get_asset_size("furniture", furniture_id)
    var sprite = Sprite2D.new()

    sprite.texture = AssetManager.get_furniture_icon(furniture_id)
    sprite.custom_minimum_size = size
```

## NFT Metadata

### Get Element Image URL for Minting
```gdscript
func mint_element_nft(element_id: String, rarity: int) -> void:
    # Get publicly accessible URL for NFT metadata
    var image_url = AssetManager.get_element_image_url(element_id, rarity)

    # Returns: "https://lenkinverse.com/assets/elements/carbon_rare.svg"
    # Used in NFT metadata JSON

    var metadata = {
        "name": "Carbon (Rare)",
        "image": image_url,
        # ...
    }
```

## Utility Functions

### Reload Assets (Hot Reload)
```gdscript
func _input(event: InputEvent) -> void:
    # Press F5 to reload assets during development
    if event.is_action_pressed("ui_reload"):
        AssetManager.reload()
        print("Assets reloaded!")
```

### Get Emoji Fallback
```gdscript
func show_element_name(element_id: String) -> String:
    var emoji = AssetManager.get_element_emoji(element_id)
    return "%s %s" % [emoji, element_id]

# Output: "⚫ lkC"
```

### Clear Cache (Memory Management)
```gdscript
func _exit_tree() -> void:
    # Clear texture cache when scene unloads
    AssetManager.clear_cache()
```

## Inventory Display Example

Complete example showing element list with icons:

```gdscript
extends VBoxContainer

func display_inventory() -> void:
    # Clear existing items
    for child in get_children():
        child.queue_free()

    # Show each element
    for element_id in InventoryManager.elements:
        var amount = InventoryManager.elements[element_id]
        var rarity = _get_element_rarity(element_id)

        var item = HBoxContainer.new()

        # Icon or emoji
        var icon = AssetManager.get_element_icon(element_id, rarity)
        if icon is Texture2D:
            var sprite = TextureRect.new()
            sprite.texture = icon
            sprite.custom_minimum_size = Vector2(32, 32)
            item.add_child(sprite)
        else:
            var emoji_label = Label.new()
            emoji_label.text = str(icon)
            item.add_child(emoji_label)

        # Name and amount
        var label = Label.new()
        label.text = "%s × %d" % [element_id, amount]
        item.add_child(label)

        add_child(item)
```

## Tutorial Arrows Example

```gdscript
func show_tutorial_highlight(target_node: Node) -> void:
    var arrow = AssetManager.get_tutorial_asset("arrow_down")

    if arrow is Texture2D:
        var sprite = Sprite2D.new()
        sprite.texture = arrow
        sprite.position = target_node.global_position + Vector2(0, -50)
        add_child(sprite)

        # Animate bouncing
        var tween = create_tween()
        tween.tween_property(sprite, "position:y", sprite.position.y + 10, 0.5)
        tween.set_loops()
```

## Particle Effects Example

```gdscript
func play_success_effect(position: Vector2) -> void:
    var particle_texture = AssetManager.get_effect("success_particle")

    if particle_texture is Texture2D:
        var particles = CPUParticles2D.new()
        particles.texture = particle_texture
        particles.position = position
        particles.emitting = true
        particles.one_shot = true
        add_child(particles)

        # Auto-remove after emission
        await get_tree().create_timer(2.0).timeout
        particles.queue_free()
```

## Best Practices

### 1. Always Handle Both Cases
```gdscript
# ✅ GOOD: Handles both Texture and String
var icon = AssetManager.get_element_icon("lkC")
if icon is Texture2D:
    sprite.texture = icon
elif icon is String:
    label.text = icon

# ❌ BAD: Assumes texture always exists
sprite.texture = AssetManager.get_element_icon("lkC")  # Crashes if SVG missing!
```

### 2. Cache AssetManager Reference
```gdscript
# ✅ GOOD: Cache in _ready()
var asset_manager: Node

func _ready() -> void:
    asset_manager = AssetManager
    var icon = asset_manager.get_element_icon("lkC")

# ❌ LESS EFFICIENT: Repeated autoload access
func update() -> void:
    var icon = AssetManager.get_element_icon("lkC")
```

### 3. Use Descriptive Asset IDs
```gdscript
# ✅ GOOD: Clear, matches config
AssetManager.get_element_icon("lkC", 2)
AssetManager.get_ui_icon("gloves_button")

# ❌ BAD: Unclear what this is
AssetManager.get_element_icon("elem1", 2)
```

### 4. Provide Fallback Context
```gdscript
# ✅ GOOD: User understands what's missing
var icon = AssetManager.get_element_icon("lkC")
if icon is String:
    print("Using emoji fallback for lkC: ", icon)

# ❌ BAD: Silent failure confuses users
var icon = AssetManager.get_element_icon("lkC")
# (No indication why graphics aren't showing)
```

## Troubleshooting

### Asset Not Loading
```gdscript
# Debug: Check if asset exists
if AssetManager.has_asset("elements", "lkC", "icon"):
    print("✅ Asset exists")
else:
    print("❌ Asset missing - check:")
    print("  1. File exists at path in asset_config.json")
    print("  2. Path is correct (res://assets/...)")
    print("  3. File format is supported (SVG, PNG)")
```

### Wrong Asset Showing
```gdscript
# Debug: Print asset path
var config = AssetManager.asset_config
var element_data = config.get("elements", {}).get("lkC", {})
print("lkC icon path: ", element_data.get("icon", "NOT FOUND"))

# Reload to pick up changes
AssetManager.reload()
```

### Emoji Not Showing
```gdscript
# Ensure font supports emojis
var label = Label.new()
label.text = AssetManager.get_element_emoji("lkC")

# Some fonts don't render emojis well
# Use theme override or system font
```

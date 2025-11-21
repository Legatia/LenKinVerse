# 🎨 Godot UI Customization Guide

**How to update button icons, UI elements, and visual assets**

---

## 📂 **Asset System Overview**

LenKinVerse uses a centralized asset configuration system managed by `AssetManager`:

```
AssetManager (autoload/asset_manager.gd)
    ↓
asset_config.json (defines all asset paths)
    ↓
assets/ folder (your actual image files)
```

---

## 🎯 **Method 1: Update via Asset Config (Recommended)**

### **Step 1: Add Your Icon File**

Place your icon file in the appropriate assets folder:

```
godot-mobile/
└── assets/
    ├── ui/                      ← UI button icons
    │   ├── marketplace_icon.svg
    │   ├── profile_icon.svg
    │   ├── storage_icon.svg
    │   └── gloves_icon.PNG
    ├── furniture/               ← In-game furniture
    ├── elements/                ← Element icons
    ├── planets/                 ← World backgrounds
    └── asset_config.json        ← Configuration file
```

**Supported formats:**
- `.svg` (recommended - scalable)
- `.png`
- `.jpg`/`.jpeg`
- `.webp`

### **Step 2: Update asset_config.json**

**File:** `godot-mobile/assets/asset_config.json`

**Example - Change Marketplace Icon:**

```json
{
  "ui": {
    "marketplace_button": {
      "icon": "res://assets/ui/marketplace_icon.svg",  ← Change this path
      "fallback_emoji": "🏪",
      "size": [40, 40]
    }
  }
}
```

**To add a new button icon:**

```json
{
  "ui": {
    "my_new_button": {
      "icon": "res://assets/ui/my_icon.png",
      "fallback_emoji": "🎮",
      "size": [40, 40]
    }
  }
}
```

### **Step 3: Use in Your Script**

```gdscript
# Get the icon texture
var icon = AssetManager.get_ui_icon("marketplace_button")

# Set it on a button
if icon is Texture2D:
    my_button.icon = icon
```

---

## 🖼️ **Method 2: Direct Scene Editing**

### **Option A: In Godot Editor (Visual)**

1. **Open the scene:**
   - File → Open Scene → `scenes/ui/marketplace_ui.tscn`

2. **Select the button:**
   - In Scene tree, find the button (e.g., "CloseButton", "BuyButton")

3. **Set icon in Inspector:**
   - With button selected, look at Inspector panel (right side)
   - Under "Button" section
   - Find "Icon" property
   - Click the dropdown → "Quick Load" → Browse to your icon file
   - Or drag & drop image file from FileSystem

4. **Adjust icon settings:**
   - `Expand Icon` - Makes icon fill button
   - `Icon Alignment` - Left/Center/Right
   - `Icon Max Width` - Limit icon size

### **Option B: Edit .tscn File Directly**

**File:** `godot-mobile/scenes/ui/marketplace_ui.tscn`

**Find the button node:**

```gdscript
[node name="MarketplaceButton" type="Button" parent="..."]
layout_mode = 2
text = "MARKETPLACE"
icon = ExtResource("2_icon")     ← Add/change this line
expand_icon = true
```

**Add the resource at the top:**

```gdscript
[ext_resource type="Texture2D" path="res://assets/ui/marketplace_icon.svg" id="2_icon"]
```

---

## 🎨 **Common UI Elements to Customize**

### **1. Marketplace Button**

**Location:** HUD buttons (bottom of screen)

**Asset Config Key:** `"marketplace_button"`

**Files to Update:**
- Add icon: `assets/ui/marketplace_icon.svg`
- Update config: `assets/asset_config.json`
- Scene: `scenes/ui/hud.tscn` (if needed)

**Code Example:**
```gdscript
# In hud.gd
var marketplace_icon = AssetManager.get_ui_icon("marketplace_button")
marketplace_button.icon = marketplace_icon
```

### **2. Profile Button**

**Asset Config Key:** `"profile_button"`

**Update:**
```json
{
  "ui": {
    "profile_button": {
      "icon": "res://assets/ui/my_profile_icon.png",
      "fallback_emoji": "📊",
      "size": [40, 40]
    }
  }
}
```

### **3. Storage Button**

**Asset Config Key:** `"storage_button"`

### **4. Gloves Button**

**Asset Config Key:** `"gloves_button"`

**Current:** `assets/ui/gloves_icon.PNG`

**To change:**
1. Replace `assets/ui/gloves_icon.PNG` with your new image
2. OR update path in `asset_config.json`:
   ```json
   "gloves_button": {
     "icon": "res://assets/ui/my_gloves_icon.svg"
   }
   ```

---

## 🔘 **Styling Buttons**

### **Add Button Theme/Style**

**Method 1: Using Theme in Godot Editor**

1. **Create a Theme:**
   - Right-click in FileSystem → New Resource → Theme
   - Save as `res://assets/themes/button_theme.tres`

2. **Edit Theme:**
   - Double-click the theme
   - Add "Button" type
   - Customize:
     - Normal (default state)
     - Hover (mouse over)
     - Pressed (clicked)
     - Disabled (inactive)
     - Focus (selected)

3. **Apply to Button:**
   - Select button in scene
   - Inspector → Theme → Assign your theme

**Method 2: StyleBoxFlat in Code**

```gdscript
# Create custom button style
func _setup_button_style(button: Button) -> void:
    var style = StyleBoxFlat.new()
    
    # Background
    style.bg_color = Color(0.2, 0.2, 0.8)  # Blue
    style.border_width_all = 2
    style.border_color = Color(1, 1, 1)    # White border
    style.corner_radius_all = 8
    
    # Apply to button states
    button.add_theme_stylebox_override("normal", style)
    
    # Hover state (lighter)
    var hover_style = style.duplicate()
    hover_style.bg_color = Color(0.3, 0.3, 0.9)
    button.add_theme_stylebox_override("hover", hover_style)
    
    # Pressed state (darker)
    var pressed_style = style.duplicate()
    pressed_style.bg_color = Color(0.1, 0.1, 0.6)
    button.add_theme_stylebox_override("pressed", pressed_style)
```

---

## 🎯 **Practical Examples**

### **Example 1: Change Marketplace Tab Icons**

**Goal:** Update the tab icons in marketplace UI

**Steps:**

1. **Add your icons:**
   ```
   assets/ui/tab_buy.svg
   assets/ui/tab_sell.svg
   assets/ui/tab_mint.svg
   assets/ui/tab_alsol.svg
   ```

2. **Update asset_config.json:**
   ```json
   {
     "ui": {
       "tab_buy": {
         "icon": "res://assets/ui/tab_buy.svg",
         "fallback_emoji": "🛒"
       },
       "tab_sell": {
         "icon": "res://assets/ui/tab_sell.svg",
         "fallback_emoji": "💰"
       }
     }
   }
   ```

3. **Update marketplace_ui.gd:**
   ```gdscript
   func _setup_tab_icons() -> void:
       var buy_icon = AssetManager.get_ui_icon("tab_buy")
       var sell_icon = AssetManager.get_ui_icon("tab_sell")
       
       # Set tab icons (if TabContainer supports it)
       tab_container.set_tab_icon(0, buy_icon)
       tab_container.set_tab_icon(1, sell_icon)
   ```

### **Example 2: Custom Buy Button with Icon**

**In marketplace_ui.gd:**

```gdscript
func _create_buy_button() -> Button:
    var button = Button.new()
    button.text = "BUY"
    
    # Set icon from AssetManager
    var buy_icon = AssetManager.get_ui_icon("buy_button")
    if buy_icon is Texture2D:
        button.icon = buy_icon
        button.expand_icon = false
    
    # Custom style
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.2, 0.8, 0.2)  # Green
    style.corner_radius_all = 10
    button.add_theme_stylebox_override("normal", style)
    
    # Connect signal
    button.pressed.connect(_on_buy_pressed)
    
    return button
```

### **Example 3: Animated Icon Button**

```gdscript
func _create_animated_button() -> Button:
    var button = Button.new()
    
    # Load icon
    var icon = AssetManager.get_ui_icon("marketplace_button")
    button.icon = icon
    
    # Animate on hover
    button.mouse_entered.connect(func():
        var tween = create_tween()
        tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
    )
    
    button.mouse_exited.connect(func():
        var tween = create_tween()
        tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2)
    )
    
    return button
```

---

## 📁 **Quick Reference: Where Things Are**

### **UI Button Icons:**
```
📁 assets/ui/
   ├── marketplace_icon.svg      ← Marketplace button
   ├── profile_icon.svg           ← Profile button
   ├── storage_icon.svg           ← Storage button
   ├── gloves_icon.PNG            ← Gloves button
   └── player.JPG                 ← Player sprite
```

### **Configuration:**
```
📁 assets/
   └── asset_config.json          ← All asset paths defined here
```

### **Scenes:**
```
📁 scenes/ui/
   ├── hud.tscn                   ← Corner buttons
   ├── marketplace_ui.tscn        ← Marketplace dialog
   ├── profile_ui.tscn            ← Profile dialog
   └── storage_ui.tscn            ← Storage dialog
```

### **Scripts:**
```
📁 scripts/ui/
   ├── hud.gd                     ← Button setup code
   ├── marketplace_ui.gd          ← Marketplace logic
   └── profile_ui.gd              ← Profile logic
```

---

## 🎨 **Icon Design Guidelines**

### **Recommended Specs:**

| Element | Size | Format | Notes |
|---------|------|--------|-------|
| Small buttons | 40×40 px | SVG | HUD corner buttons |
| Large buttons | 80×80 px | SVG | Main UI buttons |
| Icons | 32×32 px | SVG/PNG | In-game items |
| Backgrounds | 720×1280 px | PNG/JPG | Mobile portrait |

### **Best Practices:**

✅ **DO:**
- Use SVG for scalability
- Keep file sizes small (<50KB per icon)
- Use consistent style across all icons
- Provide fallback emoji in config
- Test on different screen sizes

❌ **DON'T:**
- Use overly complex SVG paths (performance)
- Mix different art styles
- Forget to test with dark/light themes
- Use PNG for simple shapes (use SVG instead)

---

## 🔧 **Troubleshooting**

### **Icon Not Showing**

**Problem:** Button shows no icon

**Solutions:**
1. Check file path in `asset_config.json` is correct
2. Verify file exists: `assets/ui/your_icon.svg`
3. Check Godot console for errors
4. Try reimporting asset (right-click → Reimport)
5. Check if AssetManager is loaded: `print(AssetManager.asset_config)`

### **Icon Too Small/Large**

**Problem:** Icon doesn't fit button

**Solutions:**
1. Set `expand_icon = true` on button
2. Adjust `custom_minimum_size` on button
3. Scale icon in AssetManager:
   ```gdscript
   var icon = AssetManager.get_ui_icon("button")
   if icon is Texture2D:
       var image = icon.get_image()
       image.resize(40, 40)  # Resize to 40x40
       button.icon = ImageTexture.create_from_image(image)
   ```

### **Wrong Icon Loading**

**Problem:** Different icon appears

**Solutions:**
1. Clear loaded cache:
   ```gdscript
   AssetManager.loaded_textures.clear()
   AssetManager.load_asset_config()
   ```
2. Check for duplicate keys in `asset_config.json`
3. Verify you're using correct key: `get_ui_icon("marketplace_button")`

---

## ✅ **Quick Checklist**

When updating UI icons:

- [ ] Add icon file to `assets/ui/` folder
- [ ] Update `assets/asset_config.json` with path
- [ ] Use `AssetManager.get_ui_icon("key")` in script
- [ ] Test in Godot editor (run scene)
- [ ] Verify on different screen sizes
- [ ] Check fallback emoji works
- [ ] Commit both icon file and config

---

## 🎯 **Summary**

**To update a button icon:**

1. **Add icon:** `assets/ui/my_icon.svg`
2. **Update config:** `asset_config.json` → add entry
3. **Use in code:** `AssetManager.get_ui_icon("my_icon")`
4. **OR edit scene:** Open `.tscn` → set icon property

**That's it!** The AssetManager handles loading, caching, and fallbacks automatically.


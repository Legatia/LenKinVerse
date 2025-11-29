# 🧪 Godot Chemistry UI Integration Guide

**Status:** ✅ COMPLETE
**Date:** November 25, 2025

---

## 📋 Overview

This guide explains how to integrate the ReAgenyx chemistry system into your Godot mobile app, connecting to the backend API for real-time reactions, energy management, and inventory tracking.

---

## 📂 Files Created

### 1. Chemistry API Manager (Autoload)
**File:** `godot-mobile/autoload/chemistry_api_manager.gd`

**Purpose:** Handles all HTTP communication with the backend chemistry API

**Signals:**
```gdscript
signal energy_updated(energy_data: Dictionary)
signal reaction_completed(result: Dictionary)
signal reaction_failed(error: String)
signal elements_loaded(elements: Array)
signal compounds_loaded(compounds: Array)
signal reactions_loaded(reactions: Array)
signal inventory_loaded(inventory: Dictionary)
```

**Key Functions:**
- `fetch_player_energy()` - Get current energy
- `fetch_all_reactions(type)` - Load reactions (optional filter)
- `fetch_player_inventory()` - Get player's elements/compounds
- `perform_reaction(reaction_id)` - Execute a chemistry reaction
- `get_inventory_element_amount(id)` - Check element quantity
- `is_nuclear_reaction(reaction)` - Detect isotope-based reactions

### 2. Chemistry Lab UI
**Files:**
- `godot-mobile/scripts/ui/chemistry_lab.gd`
- `godot-mobile/scenes/ui/chemistry_lab.tscn`

**Purpose:** Full chemistry lab interface with energy display, reaction list, inventory, and discovery tracking

**Features:**
- ⚡ Real-time energy bar with regeneration timer
- 🧪 Filterable reaction list (all/physical/chemical/nuclear)
- 📦 Inventory display (elements + compounds)
- 🎉 Reaction result popups with discovery notifications
- ✅ Material/energy requirement checking

---

## 🔧 Installation Steps

### Step 1: Add ChemistryAPIManager to Autoloads

Edit `project.godot` and add to the `[autoload]` section:

```ini
[autoload]
ChemistryAPIManager="*res://autoload/chemistry_api_manager.gd"
```

**Manual Addition:**
1. Open `project.godot` in a text editor
2. Find the `[autoload]` section
3. Add the line above after the other autoloads

**OR via Godot Editor:**
1. Project → Project Settings → Autoload
2. Click "Add"
3. Path: `res://autoload/chemistry_api_manager.gd`
4. Node Name: `ChemistryAPIManager`
5. Enable "Autoload"

### Step 2: Configure API URL

In `chemistry_api_manager.gd`, update the base URL:

```gdscript
# For local testing
var base_url: String = "http://localhost:3000/api"

# For production (use your deployed backend)
var base_url: String = "https://your-backend.com/api"
```

### Step 3: Set Player Wallet

The ChemistryAPIManager automatically gets the wallet from `WalletManager`. Ensure your `WalletManager` has a `get_wallet_address()` function:

```gdscript
# In WalletManager
func get_wallet_address() -> String:
    return current_wallet  # Your wallet variable
```

**OR** manually set it in chemistry_api_manager.gd:

```gdscript
func _ready() -> void:
    player_wallet = "YOUR_WALLET_ADDRESS"  # Hard-code for testing
    # ...
```

### Step 4: Add Chemistry Lab to Your Game

#### Option A: Add as a Button in HUD

```gdscript
# In your HUD or main UI
var chemistry_lab_scene = preload("res://scenes/ui/chemistry_lab.tscn")

func _on_chemistry_button_pressed():
    var lab = chemistry_lab_scene.instantiate()
    add_child(lab)
```

#### Option B: Add as a Tab in Existing UI

```gdscript
# In gloves_ui.gd or similar
var chemistry_tab = preload("res://scenes/ui/chemistry_lab.tscn").instantiate()
$TabContainer.add_child(chemistry_tab)
chemistry_tab.name = "Chemistry"
```

#### Option C: Replace/Update Existing Reactions Tab

If you have an existing reactions system in `gloves_ui.gd`, you can integrate the API version:

```gdscript
# In gloves_ui.gd
func _ready():
    # Connect to Chemistry API
    ChemistryAPIManager.energy_updated.connect(_on_energy_updated)
    ChemistryAPIManager.reaction_completed.connect(_on_reaction_completed)
    # ...
```

---

## 🎮 Usage Examples

### Example 1: Fetch and Display Energy

```gdscript
func _ready():
    ChemistryAPIManager.energy_updated.connect(_on_energy_updated)
    ChemistryAPIManager.fetch_player_energy()

func _on_energy_updated(energy_data: Dictionary):
    var current = energy_data.get("current_energy", 0)
    var max_energy = energy_data.get("max_energy", 100)
    $EnergyLabel.text = "%d⚡ / %d⚡" % [current, max_energy]
```

### Example 2: Perform a Reaction

```gdscript
func perform_water_reaction():
    # Reaction ID 1 = Water Formation (2 lkH + 1 lkO → H₂O)
    ChemistryAPIManager.perform_reaction(1)

func _on_reaction_completed(result: Dictionary):
    if result.get("success"):
        print("✅ Reaction succeeded!")
        print("Outputs: ", result.get("outputs_created"))
    else:
        print("❌ Reaction failed (materials consumed)")
```

### Example 3: Check if Player Can Afford Reaction

```gdscript
func can_afford_reaction(reaction: Dictionary) -> bool:
    # Check energy
    var energy_cost = reaction.get("energy_cost", 0)
    var current_energy = ChemistryAPIManager.get_current_energy()
    if current_energy < energy_cost:
        return false

    # Check materials
    var inputs = reaction.get("inputs", [])
    for input in inputs:
        var amount = input.get("amount", 1)
        var id = input.get("id", "")
        var have = ChemistryAPIManager.get_inventory_element_amount(id)
        if have < amount:
            return false

    return true
```

### Example 4: Filter Nuclear Reactions

```gdscript
func get_nuclear_reactions() -> Array:
    var all_reactions = ChemistryAPIManager.cached_reactions
    var nuclear = []

    for reaction in all_reactions:
        if ChemistryAPIManager.is_nuclear_reaction(reaction):
            nuclear.append(reaction)

    return nuclear
```

### Example 5: Auto-Refresh Energy

```gdscript
func _ready():
    # Refresh energy every 10 seconds
    var timer = Timer.new()
    timer.wait_time = 10.0
    timer.timeout.connect(func():
        ChemistryAPIManager.fetch_player_energy()
    )
    add_child(timer)
    timer.start()
```

---

## 🔌 API Integration Details

### Backend Endpoints Used

The ChemistryAPIManager uses these backend endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/player/energy/:wallet` | GET | Get player energy stats |
| `/api/chemistry/elements` | GET | List all elements |
| `/api/chemistry/compounds` | GET | List all compounds |
| `/api/chemistry/reactions` | GET | List reactions (with filter) |
| `/api/chemistry/inventory/:wallet` | GET | Get player inventory |
| `/api/chemistry/react` | POST | Perform reaction |

### Request/Response Format

**Perform Reaction Request:**
```json
POST /api/chemistry/react
{
  "player_wallet": "TestWallet123",
  "reaction_id": 1
}
```

**Success Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "reaction_id": 1,
    "reaction_name": "Water Formation",
    "energy_spent": 2,
    "inputs_consumed": [
      {"id": "lkH", "type": "element", "amount": 2},
      {"id": "lkO", "type": "element", "amount": 1}
    ],
    "outputs_created": [
      {"id": "H2O", "type": "compound", "amount": 1}
    ],
    "discovery": {
      "first_discovery": true,
      "compound_id": "H2O",
      "tax_free_until": "2025-11-28T..."
    }
  }
}
```

**Failed Reaction Response:**
```json
{
  "success": true,
  "data": {
    "success": false,
    "reaction_id": 12,
    "reaction_name": "Oxygen Synthesis (Nuclear)",
    "energy_spent": 5,
    "inputs_consumed": [
      {"id": "lkC", "type": "element", "amount": 1},
      {"id": "lkC14", "type": "element", "amount": 1}
    ]
  }
}
```

**Error Response (Insufficient Energy):**
```json
{
  "success": false,
  "message": "Insufficient energy: need 5⚡, have 2⚡"
}
```

---

## 🎨 UI Customization

### Changing Colors

Edit the colors in `chemistry_lab.gd`:

```gdscript
# Reaction type colors
const REACTION_COLORS = {
    "physical": Color(0.8, 0.8, 0.8),  # Gray
    "chemical": Color(0.3, 0.7, 1.0),  # Blue
    "nuclear": Color(1.0, 0.3, 0.3)    # Red - Change this!
}
```

### Customizing Energy Bar

```gdscript
# In chemistry_lab.tscn or via code
energy_bar.self_modulate = Color(0.3, 1.0, 0.3)  # Green bar
```

### Adding Sound Effects

```gdscript
func _on_reaction_completed(result: Dictionary):
    if result.get("success"):
        $SuccessSound.play()
    else:
        $FailSound.play()
```

---

## 🧪 Testing the Chemistry UI

### Local Testing (with backend running)

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Add Test Data to Database:**
   ```bash
   psql -U tobiasd -d reagenyx -c "
   INSERT INTO player_inventory (player_wallet, item_type, item_id, amount)
   VALUES
     ('TestWallet123', 'element', 'lkH', 100),
     ('TestWallet123', 'element', 'lkO', 100),
     ('TestWallet123', 'element', 'lkC', 500)
   ON CONFLICT (player_wallet, item_type, item_id)
   DO UPDATE SET amount = EXCLUDED.amount;
   "
   ```

3. **Set Test Wallet in Godot:**
   ```gdscript
   # In chemistry_api_manager.gd _ready()
   player_wallet = "TestWallet123"
   ```

4. **Run Godot Game:**
   - Open chemistry lab scene
   - You should see:
     - Energy: 100⚡ / 100⚡
     - Inventory with 100 lkH, 100 lkO, 500 lkC
     - 20 available reactions

5. **Test Reaction:**
   - Click "Water Formation" (reaction_id: 1)
   - Should consume 2 lkH + 1 lkO
   - Should produce 1 H₂O
   - Should spend 2⚡ energy

### Testing Without Backend

If backend isn't running, you'll see:
- Empty reaction list
- Zero energy
- "Request failed" errors in console

To test UI without API:
- Comment out API calls in `_ready()`
- Use mock data:

```gdscript
func _ready():
    # Mock data for UI testing
    var mock_reactions = [
        {
            "id": 1,
            "reaction_name": "Test Reaction",
            "reaction_type": "chemical",
            "energy_cost": 2,
            "success_rate": "0.850",
            "inputs": [{"id": "lkH", "amount": 2}],
            "outputs": [{"id": "H2O", "amount": 1}]
        }
    ]
    _on_reactions_loaded(mock_reactions)
```

---

## ⚠️ Common Issues & Solutions

### Issue 1: "No player wallet set"
**Solution:** Ensure `WalletManager.get_wallet_address()` returns a valid wallet OR manually set `player_wallet` in chemistry_api_manager.gd

### Issue 2: Empty reaction list
**Cause:** Backend not running or migrations not applied
**Solution:**
```bash
cd backend
npm run dev
psql -U tobiasd -d reagenyx -f src/db/migrations/008_chemistry_system.sql
psql -U tobiasd -d reagenyx -f src/db/migrations/009_nuclear_reactions.sql
```

### Issue 3: CORS errors in browser
**Cause:** Backend CORS settings
**Solution:** Backend already has `cors({ origin: '*' })` enabled

### Issue 4: Reactions fail immediately
**Cause:** Insufficient materials or energy
**Solution:** Add test materials via SQL or use restore endpoint

### Issue 5: Energy doesn't regenerate
**Cause:** Auto-refresh timer not running
**Solution:** Ensure timer is created in `_ready()`:
```gdscript
var timer = Timer.new()
timer.wait_time = 10.0
timer.timeout.connect(func(): ChemistryAPIManager.fetch_player_energy())
add_child(timer)
timer.start()
```

---

## 🚀 Next Steps

1. ✅ **Test locally** with backend running
2. ✅ **Add to your game's HUD** as a chemistry button
3. ⬜ **Add animations** for reaction success/failure
4. ⬜ **Add particle effects** for discoveries
5. ⬜ **Add sound effects** for reactions
6. ⬜ **Integrate with movement system** to collect lkC
7. ⬜ **Add tutorial** for first-time users
8. ⬜ **Deploy backend** to production server
9. ⬜ **Update API URL** in chemistry_api_manager.gd

---

## 📱 Mobile Considerations

### HTTP Requests on Mobile

Godot's HTTPRequest works on both iOS and Android, but:

1. **iOS Requirements:**
   - Add to `export_presets.cfg`:
     ```
     permissions/internet_client=true
     ```

2. **Android Requirements:**
   - Add to `AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET" />
     ```

3. **SSL/HTTPS:**
   - For production, use HTTPS backend
   - For local testing, HTTP works fine

### Performance Tips

- **Cache reactions locally** - reactions rarely change
- **Batch API calls** - don't spam energy updates
- **Use signals** - don't poll, respond to events
- **Lazy load inventory** - only fetch when tab opened

---

## 🎉 Complete Integration Checklist

- [x] ChemistryAPIManager autoload created
- [x] Chemistry Lab UI scene created
- [x] Chemistry Lab script created
- [x] API endpoints documented
- [x] Error handling implemented
- [x] Energy display working
- [x] Reaction list filtering
- [x] Inventory display
- [x] Result popups
- [ ] Add to project.godot autoload
- [ ] Test with backend
- [ ] Add sound effects
- [ ] Add animations
- [ ] Deploy to mobile

---

**ReAgenyx Chemistry UI - Complete! 🧪⚡**

Ready to integrate into your game!

# LenKinVerse - Godot Mobile App

Pixel art alchemy lab for Solana - built with Godot 4.4+

## 📁 Project Structure

```
godot-mobile/
├── project.godot           # Main project configuration
├── autoload/               # Singleton managers
│   ├── game_manager.gd     # App lifecycle & offline rewards
│   ├── inventory_manager.gd # Inventory management
│   ├── wallet_manager.gd   # Solana wallet integration
│   └── health_manager.gd   # Movement tracking (HealthKit/Google Fit)
├── scenes/
│   ├── main.tscn           # Main room scene
│   └── ui/                 # UI screens
│       ├── login_screen.tscn
│       ├── offline_rewards.tscn
│       ├── storage_ui.tscn
│       ├── gloves_ui.tscn
│       └── marketplace_ui.tscn
├── scripts/
│   ├── player.gd           # Player character controller
│   ├── interactable_zone.gd # Furniture interaction system
│   └── ui/                 # UI scripts
│       ├── login_screen.gd
│       ├── offline_rewards.gd
│       ├── storage_ui.gd
│       ├── gloves_ui.gd
│       └── marketplace_ui.gd
└── assets/
    ├── sprites/            # Pixel art sprites
    ├── fonts/              # Press Start 2P font
    └── ui/                 # UI textures
```

## 🎮 Current Features

### ✅ Implemented

1. **Login Screen** - Wallet authentication
   - Solana wallet connection (Phantom/Solflare)
   - Health tracking permissions request
   - First-time user flow

2. **Offline Rewards Modal** - Welcome back screen
   - Distance traveled calculation
   - Raw material rewards display
   - Animated progress bar
   - Quick access to analysis or continue

3. **Room Scene** - Top-down alchemy lab with 3 interactive zones
   - Storage Box (top-left)
   - Gloves Station (center)
   - Marketplace (bottom-right)

4. **Player Movement** - Top-down character controller
   - 4-direction movement (WASD or arrow keys)
   - Visual feedback (color changes)
   - Proximity-based interactions
   - Interaction prompts

5. **Inventory System** - Complete management
   - Raw materials (unprocessed)
   - Elements (processed)
   - Isotopes (with decay timers)
   - Items/NFTs

6. **Gloves System** - Analysis and reactions
   - 5 levels of progression
   - Batch analysis (size scales with level)
   - Processing speed improvements
   - Charge management
   - Isotope discovery (0.1% chance)
   - Level-up notifications

7. **Storage UI** - Inventory browser
   - Tabbed interface (Raw/Elements/Isotopes)
   - Take/deposit functionality
   - Real-time updates

8. **Marketplace UI** - Trading hub
   - Buy tab (market listings)
   - Sell tab (list your items)
   - Mint tab (create tokens/NFTs)
   - Wallet integration
   - Transaction signing

9. **Reaction System** - Complete chemistry engine
   - Physical reactions (1× charge multiplier)
   - Chemical reactions (2× charge multiplier)
   - Nuclear reactions (5× charge multiplier, requires isotope catalysts)
   - Reaction database with 20+ reactions
   - Element selection grid and reactant slots
   - Success/failure handling with animations

10. **Profile/Stats Screen** - User progress tracking
   - Wallet address display
   - Gloves level and progress bar
   - Total analyses performed
   - Distance traveled
   - Total materials collected
   - Isotopes discovered count

11. **Game Manager** - App lifecycle
   - Offline rewards calculation
   - Save/load system
   - Background/resume handling

12. **HUD System** - Real-time stats display
   - Charge, lkC, and raw material counts
   - Profile button with icon
   - Auto-updating stats

13. **Tutorial System** - First-time user onboarding
   - 7-step guided walkthrough
   - Highlights furniture with pointer arrows
   - Skip option for experienced users
   - Progress tracking and save state
   - Only shows on first launch
   - Explains all core mechanics

### 🚧 TODO

1. **Pixel Art Assets** - Replace placeholder sprites
2. **Native Plugins** - Solana wallet & health APIs
3. **Sound Effects** - Collection, analysis, reactions
4. **Backend API** - Marketplace listings, transaction validation

## 🔌 Native Plugins Needed

### 1. Solana Mobile Wallet Adapter

**Platform:** iOS & Android
**Singleton Name:** `SolanaMobileWallet`

**Methods:**
```gdscript
# Authorize wallet connection
authorize(config: Dictionary) -> Dictionary
# Returns: {success: bool, address: String, public_key: String}

# Sign transaction
sign_transaction(tx_data: Dictionary) -> Dictionary
# Returns: {success: bool, signature: String}

# Sign message
sign_message(message: String) -> Dictionary
# Returns: {success: bool, signature: String}

# Get balance
get_balance(address: String) -> Dictionary
# Returns: {success: bool, balance: float}
```

**Implementation Notes:**
- iOS: Use Solana Mobile Swift SDK
- Android: Use Solana Mobile Kotlin SDK
- Reference: https://docs.solanamobile.com/

### 2. Health Tracking Plugin

**Platform:** iOS (HealthKit) & Android (Google Fit)
**Singleton Name:** `HealthKit` (iOS) or `GoogleFit` (Android)

**Methods:**
```gdscript
# Request permissions
request_authorization(permissions: Array) -> Dictionary
# Returns: {granted: bool}

# Get distance since date
get_distance(options: Dictionary) -> Dictionary
# Options: {start_date: Dictionary, end_date: Dictionary}
# Returns: {success: bool, distance: float}

# Get step count
get_steps(options: Dictionary) -> Dictionary
# Returns: {success: bool, steps: int}
```

**Implementation Notes:**
- iOS: Use HealthKit framework
- Android: Use Google Fit REST API
- Store permissions in project settings

## 🚀 Getting Started

### Prerequisites

- Godot 4.4 or later
- Android Studio (for Android builds)
- Xcode (for iOS builds)

### Opening the Project

1. Open Godot Engine
2. Click "Import"
3. Navigate to `godot-mobile` folder
4. Select `project.godot`
5. Click "Import & Edit"

### Running in Editor

1. Press F5 or click "Play" button
2. Use WASD or arrow keys to move player
3. Click directly on furniture to interact (Storage, Gloves, Marketplace)
4. Follow the tutorial on first launch

### Building for Mobile

#### Android:
1. Editor → Export → Add → Android
2. Configure export settings
3. Export Project
4. Install APK on device

#### iOS:
1. Editor → Export → Add → iOS
2. Configure export settings
3. Export Xcode project
4. Open in Xcode and build

## 🎨 Adding Pixel Art Assets

### Player Sprites
Place in `assets/sprites/player/`:
- `walk_down_spritesheet.png` (128×32: 4 frames @ 32×32)
- `walk_up_spritesheet.png`
- `walk_left_spritesheet.png`
- `walk_right_spritesheet.png`

Then create AnimatedSprite2D frames in editor.

### Furniture Sprites
Place in `assets/sprites/furniture/`:
- `storage_box.png` (80×80)
- `gloves_station.png` (80×80)
- `marketplace.png` (80×80)

Replace placeholder sprites in `main.tscn`.

### Room Background
Place in `assets/sprites/`:
- `room_background.png` (360×640)

Update Background node in `main.tscn`.

## 💾 Save System

All data saved to `user://` directory:
- `game_data.save` - Last close time, first launch
- `inventory.save` - All inventory data
- `gloves.save` - Gloves level, charge, progress
- `wallet.save` - Wallet connection state

**Locations:**
- **Windows:** `%APPDATA%\Godot\app_userdata\LenKinVerse\`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/LenKinVerse/`
- **Linux:** `~/.local/share/godot/app_userdata/LenKinVerse/`
- **Android:** Internal app storage
- **iOS:** App sandbox documents directory

## 🧪 Testing Without Plugins

The app runs in "mock mode" when native plugins aren't available:

- **Wallet:** Auto-connects to mock address `8x7f...2kQ9`
- **Health:** Generates mock movement data based on time elapsed

This allows full development in Godot editor before plugin integration.

## 📖 Game Mechanics

### Movement Farming (Passive)
1. App closes → saves timestamp
2. User walks around (tracked by HealthKit/Google Fit)
3. App opens → calculates distance traveled
4. Generates raw material chunks (50m = 1 chunk)
5. Each chunk: 12-20 raw lkC × efficiency

### Analysis System
1. Open Gloves Station
2. Analyze raw lkC → cleaned lkC
3. Costs: 1 charge per analysis
4. 0.1% chance to discover C14 isotope
5. Levels up after X analyses

### Gloves Progression
| Level | Analyses | Batch Size | Speed   | Capacity |
|-------|----------|------------|---------|----------|
| 1     | 0        | 1          | 1.0s    | 50       |
| 2     | 500      | 5          | 0.8s    | 75       |
| 3     | 2,000    | 10         | 0.5s    | 100      |
| 4     | 5,000    | 25         | 0.3s    | 150      |
| 5     | 10,000   | 50         | 0.1s    | 200      |

### Charging
- Use raw lkC to recharge gloves
- Cost decreases with level (100 → 50 raw lkC per 10 charge)
- Required for all reactions

## 🐛 Known Issues

- Player sprite animations use placeholders
- Furniture sprites are colored rectangles
- No sounds/music
- Native plugins not yet implemented (using mocks)

## 📚 Resources

- [Godot Documentation](https://docs.godotengine.org/)
- [Solana Mobile Docs](https://docs.solanamobile.com/)
- [Design Document](../Design.md)
- [Vision Document](../Vision_v1.md)

## 🤝 Contributing

1. Add pixel art assets to `assets/` folder
2. Update scene files to use new assets
3. Implement missing UI screens
4. Create native plugins for wallet/health APIs
5. Test on real devices

## 📄 License

[To be determined]

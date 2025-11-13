# LenKinVerse Mobile App Design Document

## 🏠 Core Concept: Single Room Alchemy Lab

Instead of a map-based GPS exploration game, the mobile app features a **single pixel art room** where the player manages their alchemy operations. Movement tracking happens passively via iOS HealthKit/Android Google Fit, and rewards are calculated when the app opens.

### Why This Design?

✅ **Simpler Development** - No map rendering, GPS display, or location tracking UI
✅ **Better UX** - Clear purpose for each zone, easy to understand
✅ **Focused Gameplay** - All game features in one cozy space
✅ **Pixel Art Friendly** - Single room is easier to make beautiful
✅ **Performance** - Static background, less rendering overhead
✅ **Battery Friendly** - No active GPS, just health API reads on app open

---

## 🎨 Room Layout (Top-Down View)

```
╔═══════════════════════════════════════════════════════════╗
║  ⚡43  💰1,247 lkC  ⚫798 raw     [≡ MENU]                ║ ← Top HUD
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  📦 STORAGE BOX           ╔═══════════╗                   ║
║  ┌─────────┐             ║  TABLE    ║                   ║
║  │ ⚫⚫⚫⚫ │             ║           ║                   ║
║  │ ⚫⚫⚫⚫ │             ║    📚📚   ║                   ║
║  │ Click! │             ║           ║                   ║
║  └─────────┘             ╚═══════════╝                   ║
║      [E]                                                  ║
║                                                           ║
║                              🧙                           ║ ← Player
║                             /|\                           ║   (can walk
║              ⚗️ GLOVES      / \                           ║    around)
║              ┌─────────┐                                  ║
║              │  🖐️🖐️  │                                 ║
║              │ Click!  │                                  ║
║              └─────────┘                                  ║
║                  [E]                                      ║
║                                                           ║
║                                   🖥️ MARKETPLACE         ║
║          ╔═════╗                 ┌─────────┐             ║
║          ║ 🛋️  ║                 │ 💱 BUY  │             ║
║          ║SHELF║                 │ 💸 SELL │             ║
║          ╚═════╝                 │ Click!  │             ║
║                                  └─────────┘             ║
║                                      [E]                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Legend:
🧙 = Player character (top-down sprite)
[E] = "Press E to interact" prompt (shows when near)
```

### Visual Style (Pixel Art)

**Room Design:**
- Size: 360×640 pixels (mobile portrait)
- Style: Cozy alchemy lab (Stardew Valley interior aesthetic)
- Walls: Stone brick texture
- Floor: Wooden planks
- Lighting: Warm ambient glow

**Furniture:**
```
┌─────────┐
│ 📦📦📦 │  Storage Box (80×80 sprite)
└─────────┘

┌─────────┐
│ ⚗️ 🖐️🖐️│  Gloves Station (80×80 sprite)
└─────────┘

┌─────────┐
│ 🖥️ 💰💰 │  Marketplace Machine (80×80 sprite)
└─────────┘
```

**Player:**
```
   🧙       Walking animation (32×32 sprite)
  /|\       4 directions (up/down/left/right)
  / \       4 frames per direction
```

---

## 🎮 Interactive Zones

### 1. Storage Box (Top-Left Corner)

**When player walks near:**
```
┌─────────────────────────┐
│   [E] CHECK STORAGE     │  ← Prompt appears
└─────────────────────────┘
```

**Press E → Opens Storage UI:**
```
╔═══════════════════════════════════════╗
║  📦 STORAGE BOX                    [X]║
╠═══════════════════════════════════════╣
║                                       ║
║  Raw Materials:                       ║
║  ⚫ raw lkC × 798    [TAKE ALL]       ║
║  🔵 raw lkO × 23    [TAKE ALL]       ║
║                                       ║
║  Elements:                            ║
║  ⚫ lkC × 1,247      [DEPOSIT]        ║
║  🔵 lkO × 45        [DEPOSIT]        ║
║  🔴 CO₂ × 12        [DEPOSIT]        ║
║                                       ║
║  Isotopes:                            ║
║  💎 C14 × 2 ⏱️4h    [TAKE]           ║
║                                       ║
║  Items:                               ║
║  🪨 Coal × 5        [TAKE]           ║
║  💎 Diamond × 1     [TAKE]           ║
║                                       ║
╚═══════════════════════════════════════╝
```

### 2. Gloves Station (Center-Left)

**When near:**
```
┌─────────────────────────┐
│  [E] USE GLOVES Lv.3    │
└─────────────────────────┘
```

**Press E → Opens Gloves UI:**
```
╔═══════════════════════════════════════╗
║  ⚗️ ALCHEMY GLOVES Lv.3           [X]║
╠═══════════════════════════════════════╣
║  Charge: ▓▓▓▓░░░░░░ 43/100 ⚡        ║
║  Progress: 2,470/3,000 → Lv.4         ║
║                                       ║
║  ┌──────────────┬──────────────┐     ║
║  │   ANALYZE    │   REACTIONS  │     ║ ← Tabs
║  └──────────────┴──────────────┘     ║
║                                       ║
║  ANALYZE TAB:                         ║
║  ────────────────────────────────     ║
║  Raw Materials Available:             ║
║  ⚫ raw lkC × 798                     ║
║                                       ║
║  Batch Size (Lv.3): 10 chunks         ║
║  Speed: 0.5s per analysis             ║
║                                       ║
║  [ ANALYZE 1 ]  (Cost: 1 ⚡)          ║
║  [ ANALYZE 10 ] (Cost: 10 ⚡)         ║
║                                       ║
║  [ RECHARGE ] (80 raw lkC → +10 ⚡)   ║
║                                       ║
║  ─────────────────────────────────    ║
║  REACTIONS TAB:                       ║
║  ────────────────────────────────     ║
║  Drag & Drop Elements:                ║
║                                       ║
║  ┌───┐ ┌───┐ ┌───┐ ┌───┐            ║
║  │ C │ │ O │ │   │ │   │            ║
║  └───┘ └───┘ └───┘ └───┘            ║
║           ↓                           ║
║  Type: ⚙️ Physical | 🧪 Chemical     ║
║  Charge: 3 ⚡                         ║
║                                       ║
║  [ REACT ]                            ║
╚═══════════════════════════════════════╝
```

### 3. Marketplace Machine (Bottom-Right)

**When near:**
```
┌─────────────────────────┐
│  [E] OPEN MARKETPLACE   │
└─────────────────────────┘
```

**Press E → Opens Marketplace:**
```
╔═══════════════════════════════════════╗
║  🖥️ SOLANA MARKETPLACE            [X]║
╠═══════════════════════════════════════╣
║  Wallet: 8x7f...2kQ9                  ║
║  Balance: 2.47 SOL                    ║
║                                       ║
║  ┌──────────┬──────────┬──────────┐  ║
║  │   BUY    │   SELL   │  MINT    │  ║ ← Tabs
║  └──────────┴──────────┴──────────┘  ║
║                                       ║
║  BUY TAB:                             ║
║  ─────────────────────────────────    ║
║  📊 Market Listings:                  ║
║                                       ║
║  ⚫ lkC × 1000      0.01 SOL [BUY]    ║
║  🔵 lkO × 500      0.02 SOL [BUY]    ║
║  🔴 CO₂ × 100      0.05 SOL [BUY]    ║
║                                       ║
║  ─────────────────────────────────    ║
║  SELL TAB:                            ║
║  ─────────────────────────────────    ║
║  Your Inventory:                      ║
║                                       ║
║  ⚫ lkC × 1,247                       ║
║  Amount: [100] Price: [0.001] SOL     ║
║  [ LIST FOR SALE ]                    ║
║                                       ║
║  ─────────────────────────────────    ║
║  MINT TAB:                            ║
║  ─────────────────────────────────    ║
║  Create new tokens/NFTs:              ║
║                                       ║
║  🔴 CO₂ × 12 → Mint as Token?        ║
║  [ MINT TOKEN ] (Cost: 0.05 SOL)     ║
║                                       ║
╚═══════════════════════════════════════╝
```

### 4. Menu (Top-Right Dropdown)

**Click [≡] button:**
```
╔═══════════════════════╗
║  ≡ MENU               ║
╠═══════════════════════╣
║  🏠 Room              ║
║  👤 Profile           ║
║  📊 Stats             ║
║  🏆 Achievements      ║
║  ⚙️ Settings          ║
║  💾 Save              ║
║  🚪 Logout            ║
╚═══════════════════════╝
```

**Profile Screen:**
```
╔═══════════════════════════════════════╗
║  👤 ALCHEMIST PROFILE             [X] ║
╠═══════════════════════════════════════╣
║                                       ║
║         🧙‍♂️                           ║
║                                       ║
║  Wallet: 8x7f...2kQ9                  ║
║  Level: Apprentice (Lv.3)             ║
║                                       ║
║  ═══════════════════════════════════  ║
║  MOVEMENT STATS:                      ║
║  ───────────────────────────────────  ║
║  Today:      2.3 km 🚶               ║
║  This Week:  18.7 km                  ║
║  All Time:   247.5 km                 ║
║                                       ║
║  Raw Collected:  12,473 total         ║
║  Efficiency Avg: 87%                  ║
║                                       ║
║  ═══════════════════════════════════  ║
║  ALCHEMY STATS:                       ║
║  ───────────────────────────────────  ║
║  Analyses: 2,470                      ║
║  Reactions: 156                       ║
║  Discoveries: 3 elements              ║
║  Isotopes Found: 7                    ║
║                                       ║
╚═══════════════════════════════════════╝
```

---

## 🔄 Game Systems

### Material Flow

```
GPS Movement (50m)
       ↓
Collect: raw lkC (12-20 × efficiency)
       ↓
Storage: Unprocessed raw materials
       ↓
Analyze in Gloves: raw lkC → lkC (cleaned)
       ↓
Use lkC for:
  • Charging gloves (for reactions)
  • Physical reactions
  • Chemical reactions
  • Nuclear reactions
```

### Gloves Progression (Simplified)

**Level up by analysis count only. Only batch size and speed change.**

| Level | Analyses Required | Batch Size | Processing Speed | Charge Capacity |
|-------|------------------|------------|------------------|-----------------|
| 1     | 0                | 1          | 1.0s/chunk       | 50              |
| 2     | 500              | 5          | 0.8s/chunk       | 75              |
| 3     | 2,000            | 10         | 0.5s/chunk       | 100             |
| 4     | 5,000            | 25         | 0.3s/chunk       | 150             |
| 5     | 10,000           | 50         | 0.1s/chunk       | 200             |

### Charging System

**Charge with raw lkC** (not cleaned lkC)

**Used for all reactions:**
- **Physical**: 1 charge per unit of material
- **Chemical**: 2 charge per unit of material
- **Nuclear**: 5 charge per unit of material

**Recharge cost** (decreases with level):
- Level 1: 100 raw lkC → +10 charge
- Level 2: 90 raw lkC → +10 charge
- Level 3: 80 raw lkC → +10 charge
- Level 4: 70 raw lkC → +10 charge
- Level 5: 50 raw lkC → +10 charge

### Isotope Discovery

- **Always 0.1% chance** (independent of glove level)
- Rolled on every raw material analysis
- Cannot be purchased (anti-whale mechanic)
- Decays over ~24 hours
- Required for nuclear reactions

---

## 🛠️ Technical Implementation

### Tech Stack

```json
{
  "framework": "React Native 0.73+",
  "language": "TypeScript",
  "navigation": "React Navigation 6",
  "state": "Zustand",
  "storage": "MMKV",
  "blockchain": "Solana Mobile Wallet Adapter",
  "health": "iOS HealthKit + Android Google Fit",
  "styling": "StyleSheet + react-native-pixel-perfect",
  "fonts": "Press Start 2P (pixel font)",
  "assets": "Open source pixel art"
}
```

### Two Implementation Options

#### Option A: Walking Character (More Immersive)

- Player sprite walks around with virtual joystick
- Proximity detection for interactions
- More "game-like" feel
- Requires sprite animations (4 directions × 4 frames)

**Features:**
- Virtual joystick in bottom-left
- Player walks in 4 directions
- Proximity prompts ([E] to interact)
- Animation system for walking

**Complexity:** Medium

#### Option B: Simple Tap Zones (Faster MVP)

- Static room with clickable furniture
- No movement animations needed
- Faster to build
- Still looks great with pixel art

**Features:**
- Direct tap on furniture to interact
- Static player sprite (or no player visible)
- Immediate navigation to function screens

**Complexity:** Low

**Recommendation:** Start with **Option B** for MVP, add walking in v2 if desired.

---

## 🎨 Asset Requirements

### Room Background
```
room-background.png (360×640)
- Wooden floor tiles
- Stone walls
- Ambient lighting
- Small decorations (books, bottles, shelves)
```

### Furniture Sprites
```
furniture/
  ├── storage-box.png (80×80)
  ├── gloves-station.png (80×80)
  ├── marketplace.png (80×80)
  ├── table.png (64×48)
  └── shelf.png (48×64)
```

### Player Sprites (Optional for Option A)
```
player/
  ├── walk-down.png (32×32, 4 frames)
  ├── walk-up.png (32×32, 4 frames)
  ├── walk-left.png (32×32, 4 frames)
  └── walk-right.png (32×32, 4 frames)
```

### UI Elements
```
ui/
  ├── button.png (120×32, 2 frames: normal, pressed)
  ├── panel.png (200×150, 9-patch)
  ├── progress-bar.png (100×8)
  └── icons/ (16×16 each)
      ├── lkC.png
      ├── isotope.png
      ├── charge.png
      └── sol.png
```

### Free Asset Sources

1. **LimeZu's Modern Interiors** (itch.io)
   - https://limezu.itch.io/moderninteriors
   - Perfect for lab/room interiors
   - CC0 license

2. **Cupnooble's Sprout Lands**
   - https://cupnooble.itch.io/sprout-lands-asset-pack
   - Great character sprites
   - Free

3. **Pixel Frog's Tiny RPG**
   - https://pixelfrog-assets.itch.io/
   - Characters + interiors
   - Free

4. **Kenney.nl**
   - https://kenney.nl/assets (all CC0!)
   - "Pixel Platformer" pack
   - "Pixel UI Pack"

---

## 📊 Updated App Flow

```
1. APP OPENS
   ↓
2. WALLET LOGIN (first time)
   - Connect Phantom/Solflare
   - Create user profile
   - Initialize health tracking permissions
   ↓
3. CALCULATE OFFLINE REWARDS
   - Read HealthKit/Google Fit data
   - Calculate distance since last close
   - Generate raw material chunks
   ↓
4. SHOW REWARDS MODAL
   "You walked 2.47km! Collected 798 raw lkC"
   [ANALYZE NOW] [CONTINUE]
   ↓
5. ENTER ROOM
   - Player appears in alchemy lab
   - See 4 interactive zones
   ↓
6. INTERACT WITH ZONES

   Storage Box:
   - View inventory
   - Manage materials

   Gloves Station:
   - Analyze raw materials (raw lkC → lkC)
   - Perform reactions (physical/chemical/nuclear)
   - Recharge gloves

   Marketplace:
   - Buy elements/items
   - Sell inventory
   - Mint tokens/NFTs

   Menu:
   - Profile & stats
   - Settings
   - Logout
   ↓
7. CLOSE APP
   - Save last close time
   - Continue tracking movement via health APIs
```

---

## 🎯 MVP Development Roadmap

### Phase 1: Core Foundation (Week 1-2)
- ✓ Project setup & dependencies
- ✓ Pixel font integration
- ✓ Navigation structure
- ✓ Zustand stores (inventory, gloves, user)
- ✓ MMKV storage
- Room screen (simple tap version)
- Basic UI components (PixelButton, PixelText)

### Phase 2: Wallet & Auth (Week 3)
- Login screen with pixel art
- Solana Mobile Wallet Adapter integration
- User creation flow
- Wallet disconnection

### Phase 3: Movement System (Week 4)
- HealthKit/Google Fit integration
- Offline calculation algorithm
- Rewards modal with animation
- Edge case handling
- Backend validation API

### Phase 4: Analysis System (Week 5-6)
- Storage screen UI
- Gloves screen UI
- Raw chunk analysis (raw lkC → lkC)
- Isotope discovery (0.1% chance)
- Level progression
- Recharge system
- Batch analysis

### Phase 5: Reactions (Week 7)
- Reaction UI (drag & drop)
- Physical reactions
- Chemical reactions
- Nuclear reactions (with isotope catalysts)
- Success/failure animations

### Phase 6: Marketplace (Week 8)
- Buy tab (browse listings)
- Sell tab (list items)
- Mint tab (create tokens/NFTs)
- Solana transaction signing
- Backend marketplace API

### Phase 7: Polish & Testing (Week 9-10)
- Pixel art assets integration
- Sound effects (collect, analyze, react)
- Tutorial flow
- Error handling
- Beta testing
- App store submission

---

## 🔑 Key Design Principles

1. **Passive Collection** - No active GPS tracking, read health data on app open
2. **Single Room Hub** - All functionality accessible from one cozy space
3. **Clear Zones** - Each corner has a specific purpose
4. **Raw → Cleaned** - Two-step material processing (collect → analyze)
5. **Charge for Everything** - Gloves charge required for all reactions
6. **Simple Progression** - Only batch size and speed improve with levels
7. **Time > Money** - Isotopes can't be bought, must be farmed

---

## 📦 Data Models

### Inventory Structure
```typescript
{
  rawMaterials: {
    lkC: 798,
    lkO: 23,
    // ... future elements
  },

  elements: {
    lkC: 1247,
    lkO: 45,
    CO2: 12,
    // ... compounds
  },

  isotopes: [
    {
      id: "iso_123",
      type: "C14",
      amount: 1,
      discoveredAt: 1234567890,
      decayTime: 1234654290  // 24h later
    }
  ],

  items: [
    {
      id: "item_456",
      name: "Coal",
      amount: 5,
      nftMint: null  // or Solana mint address
    }
  ]
}
```

### Gloves State
```typescript
{
  level: 3,
  analysisCount: 2470,
  charge: 43,
  chargeCapacity: 100
}
```

### User Profile
```typescript
{
  walletAddress: "8x7f...2kQ9",
  createdAt: 1234567890,
  totalDistance: 247500,  // meters
  totalAnalyses: 2470,
  totalReactions: 156,
  discoveries: ["lkC", "lkO", "CO2"]
}
```

---

## 🚀 Next Steps

1. **Finalize Asset List** - Identify exact sprites needed
2. **Source/Create Pixel Art** - Use free assets or commission
3. **Build React Native Project** - Scaffold with TypeScript
4. **Implement Room Screen** - Start with simple tap version
5. **Integrate Wallet** - Solana Mobile Wallet Adapter
6. **Connect Health APIs** - iOS HealthKit + Android Google Fit
7. **Build Core Loops** - Collection → Analysis → Reactions

---

## 📝 Notes

- **No GPS display** - Movement tracking is completely passive
- **No map exploration** - Single room is the entire mobile experience
- **Laboratory webapp** - Separate feature for batch processing (future)
- **Godot template** - Reference for visual style only, not using Godot
- **React Native** - Chosen for cross-platform, Web3 libraries, and rapid development

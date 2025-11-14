# Solana Planet - Development Todo List

This document tracks the integration status between the Solana Planet game scene and Solana blockchain smart contracts.

---

## 🟢 Currently Working - Solana Integration

### **1. Wallet Connection ✅**
**Location:** `godot-mobile/autoload/wallet_manager.gd`

**Status:** Mock implementation ready, waiting for native plugin

**What's Working:**
- Mock wallet connection (generates test address)
- Wallet signals (connected, disconnected, transaction_completed)
- Save/load wallet state
- Balance retrieval (mocked at 2.47 SOL)
- Transaction signing interface

**What's Needed:**
- Native GDExtension plugin for Solana Mobile Wallet Adapter
- See: `docs/SOLANA_PLUGIN_SPEC.md` and `docs/SOLANA_PLUGIN_IMPLEMENTATION.md`

**Integration Point:**
- Used by `marketplace_ui.gd` for all blockchain operations
- Used by `login_screen.gd` for wallet connection

---

### **2. Smart Contracts ✅**
**Location:** `solana-program/programs/`

**Programs Implemented:**

#### **A. Marketplace Program** ✅ (`marketplace/src/lib.rs`)
- `swap_sol_for_alsol` - Buy alSOL with SOL (1:1 ratio)
- `swap_lkc_for_alsol` - Buy alSOL with LKC (1M:1 ratio, weekly limit 1 alSOL)
- `create_listing` - List element NFT for sale
- `buy_listing` - Purchase listed element
- `cancel_listing` - Cancel own listing
- `update_listing_price` - Update listing price

**Features:**
- alSOL token integration (SPL token backed 1:1 by SOL)
- SwapHistory PDA tracking for weekly limits
- Fractional alSOL purchases (minimum 0.001)
- 3-decimal precision rounding

#### **B. Element NFT Program** ✅ (`element-nft/src/lib.rs`)
- `mint_element` - Mint discovered elements as NFTs
- `update_amount` - Update element quantity
- `burn_element` - Burn element NFT

**Features:**
- Supports isotopes with decay_time field
- Tracks rarity, discovery timestamp, generation method
- Metaplex-compatible metadata

#### **C. Registry Program** ✅ (`registry/src/lib.rs`)
- `register_element` - Add element definition
- `register_reaction` - Add reaction formula
- Element database on-chain
- Reaction validation

---

## 🟡 Partially Implemented - Needs Work

### **3. Marketplace UI** 🟡
**Location:** `godot-mobile/scripts/ui/marketplace_ui.gd`

**What's Working:**
- Displays wallet connection status
- Shows SOL balance (mocked)
- Lists sellable elements from inventory (≥10 required)
- Lists mintable compounds (non-basic elements)
- Connects to WalletManager signals

**What's Missing:**
```gdscript
// Line 66
func _start_selling(element: String, max_amount: int) -> void:
    print("Starting sell flow for: ", element, " (max: ", max_amount, ")")
    # TODO: Show sell dialog with amount/price inputs

// Line 141
func show_message(text: String) -> void:
    print(text)
    # TODO: Show proper toast/modal
```

**Needs Implementation:**
1. **Sell Dialog** - UI for setting price and amount when listing
2. **Buy alSOL UI** - Interface for SOL→alSOL and LKC→alSOL swaps
3. **Browse Listings** - Show marketplace listings from other players
4. **Purchase Flow** - Complete buy transaction UI
5. **Toast/Modal System** - Proper user feedback

**Actual Program Calls Needed:**
- Call `swap_sol_for_alsol` instruction
- Call `swap_lkc_for_alsol` instruction with weekly limit check
- Call `create_listing` when selling
- Call `buy_listing` when purchasing
- Query program accounts for marketplace listings

---

### **4. Element Stats Tracking** 🟡
**Location:** `godot-mobile/autoload/reaction_manager.gd:194-197`

```gdscript
func get_element_lifetime_count(element: String) -> int:
    # TODO: Track lifetime collection stats
    # For now, check current inventory
    return InventoryManager.get_element_amount(element)
```

**Issue:**
- Currently only checks current inventory
- Doesn't track lifetime stats (total ever collected)
- Affects "new discovery" detection

**Needed:**
- Add lifetime tracking to save file
- Track total of each element ever obtained
- Persist across game sessions

---

### **5. Isotope Usage in Reactions** 🟡
**Location:** `godot-mobile/scripts/ui/storage_ui.gd:105-107`

```gdscript
func _use_isotope(isotope: Dictionary) -> void:
    print("Using isotope: ", isotope.get("type"))
    # TODO: Open reaction UI with this isotope selected
```

**Needed:**
- Open gloves UI reactions tab
- Pre-select the isotope as catalyst
- Smooth UX for isotope → reaction flow

---

### **6. Visual Feedback** 🟡
**Location:** Multiple files

**Missing Toast/Modal System:**
- `gloves_ui.gd:202` - Uses temporary label that fades
- `marketplace_ui.gd:141` - Just prints to console
- `storage_ui.gd` - No feedback system

**Needed:**
- Proper toast notification system
- Modal dialogs for confirmations
- Loading spinners for blockchain transactions
- Success/error animations

---

## 🔴 Not Implemented Yet - High Priority

### **7. Actual Solana Program Integration** 🔴
**Priority:** **CRITICAL**

**Current Status:** All blockchain calls are mocked

**What's Needed:**

#### **A. Solana GDExtension Plugin**
**Location:** Needs to be created

**Requirements:**
1. Implement native plugin following `docs/SOLANA_PLUGIN_SPEC.md`
2. Wrap Solana Mobile Wallet Adapter for iOS/Android
3. Expose methods to GDScript:
   - `authorize()` - Connect wallet
   - `sign_transaction()` - Sign and send
   - `sign_message()` - Sign arbitrary message
   - `get_balance()` - Get SOL balance
   - Signals for async results

**Technologies:**
- Swift for iOS (using Solana Mobile SDK)
- Kotlin for Android (using Mobile Wallet Adapter)
- GDExtension C++ bindings

#### **B. Anchor/Web3 Integration Layer**
**Location:** Needs to be created as `godot-mobile/addons/solana_anchor/`

**Purpose:** Bridge between GDScript and Anchor programs

**Needed Functions:**
```gdscript
# Marketplace program calls
func swap_sol_for_alsol(sol_amount: float) -> String
func swap_lkc_for_alsol(lkc_amount: int) -> Dictionary
func create_listing(element_nft_mint: String, price: float) -> String
func buy_listing(listing_pubkey: String) -> String
func cancel_listing(listing_pubkey: String) -> String

# Element NFT program calls
func mint_element_nft(element_data: Dictionary) -> String
func burn_element_nft(mint_address: String) -> String

# Registry program calls
func get_element_definition(element_id: String) -> Dictionary
func validate_reaction(reactants: Array, products: Array) -> bool

# Query functions
func fetch_marketplace_listings() -> Array
func get_user_nfts() -> Array
func get_swap_history() -> Dictionary
```

**Technical Approach:**
1. **Option A:** Use Solana Unity SDK as reference, port to GDScript/C++
2. **Option B:** Create REST API backend that handles Anchor calls, Godot calls REST API
3. **Option C:** Embed web view with Anchor TS SDK, bridge via JavaScript

---

### **8. Player Profile System** 🔴
**Priority:** Medium

**Status:** Not started

**Needs:**
- On-chain player profile program (see `ONCHAIN_REQUIREMENTS.md:120-151`)
- Track stats: analyses, reactions, discoveries, trades
- Achievement NFT system
- Leaderboards
- Reputation score

**Integration:**
- Create `player_profile_ui.gd` scene
- Display stats in profile button (HUD)
- Mint achievement NFTs for milestones

---

### **9. NFT Minting Flow** 🔴
**Priority:** High

**Status:** UI exists, no blockchain integration

**Current:**
- `marketplace_ui.gd:111-137` calls mock `WalletManager.sign_transaction()`

**Needs:**
1. Generate Metaplex-compatible metadata
2. Upload metadata to Arweave/IPFS
3. Call `mint_element` instruction with proper accounts
4. Handle mint success/failure
5. Update inventory to reflect minted items
6. Show NFT in wallet

**Flow:**
```
Player clicks "MINT TOKEN"
→ Create metadata JSON
→ Upload to decentralized storage
→ Build mint_element transaction
→ Sign via wallet
→ Send transaction
→ Wait for confirmation
→ Update UI with NFT address
```

---

### **10. Marketplace Browse/Search** 🔴
**Priority:** High

**Status:** Not implemented

**Needs:**
1. Query program accounts for active listings
2. Display listings in scrollable grid
3. Filter by element type
4. Sort by price (low/high)
5. Search functionality
6. Show seller info
7. Purchase button for each listing

**UI Design:**
- New tab in `marketplace_ui.tscn`: "Browse"
- GridContainer with listing cards
- Each card shows: element icon, amount, price, seller

---

### **11. Transaction History** 🔴
**Priority:** Low

**Status:** Not implemented

**Needs:**
- Query user's transaction history
- Display in profile UI
- Show: date, type, amount, signature
- Link to Solana Explorer

---

### **12. alSOL Swap UI** 🔴
**Priority:** **HIGH** (feature recently implemented in smart contract)

**Status:** Smart contract ready, UI missing

**Location:** Needs to be added to `marketplace_ui.gd`

**Required UI:**

#### **Tab: "Get alSOL"**
```
┌─────────────────────────────────┐
│  Get alSOL (In-Game Currency)  │
├─────────────────────────────────┤
│                                 │
│  Option 1: Buy with SOL         │
│  ┌───────────────────────────┐  │
│  │ Amount: [____] SOL        │  │
│  │ → You get: 1.000 alSOL    │  │
│  │ [BUY NOW]                 │  │
│  └───────────────────────────┘  │
│                                 │
│  Option 2: Buy with LKC         │
│  ┌───────────────────────────┐  │
│  │ Amount: [______] LKC      │  │
│  │ → You get: 0.123 alSOL    │  │
│  │                           │  │
│  │ ⚠️ Weekly Limit: 1 alSOL  │  │
│  │ Used: 0.450 / 1.000       │  │
│  │                           │  │
│  │ [BUY NOW]                 │  │
│  └───────────────────────────┘  │
│                                 │
│  Min: 0.001 alSOL (1,000 LKC)  │
└─────────────────────────────────┘
```

**Implementation Steps:**
1. Add "Get alSOL" tab to marketplace UI
2. Create input fields for SOL and LKC amounts
3. Show real-time conversion calculation
4. Display weekly limit progress bar
5. Call `swap_sol_for_alsol` or `swap_lkc_for_alsol` instructions
6. Handle errors (insufficient funds, weekly limit exceeded, amount too small)
7. Show success message with transaction signature

---

### **13. Offline Rewards → On-Chain Sync** 🔴
**Priority:** Medium

**Status:** Offline rewards work, no blockchain sync

**Concept:**
- Player collects raw materials while offline
- When they return, rewards are calculated
- **Option:** Mint proof-of-movement as NFT
- **Option:** Submit movement data for verification
- Prevents cheating while maintaining gameplay

**Needs:**
- Backend verification service
- Movement proof NFT program
- Signature verification in smart contract

---

## 🔵 Nice to Have - Future Features

### **14. Staking System** 🔵
- Stake element NFTs for bonuses
- Earn passive rewards
- Isotope decay protection while staked
- See `ONCHAIN_REQUIREMENTS.md:155-181`

### **15. DAO Governance** 🔵
- Token-based voting
- Propose reaction formulas
- Community-driven element additions

### **16. Cross-Chain Support** 🔵
- Bridge elements to Base/Sui planets
- Multi-chain inventory
- Unified marketplace across chains

### **17. Seasonal Events** 🔵
- Limited-time isotopes
- Special reaction formulas
- Event NFT badges

---

## 📊 Development Priority Order

### **Phase 1: Core Blockchain Integration** (4-6 weeks)
1. ✅ Smart contracts deployed (Element NFT, Marketplace, Registry)
2. 🔴 Build Solana GDExtension plugin
3. 🔴 Implement alSOL swap UI (SOL and LKC)
4. 🔴 Integrate wallet connection (real, not mock)
5. 🔴 Implement NFT minting flow
6. 🔴 Test on Devnet

### **Phase 2: Marketplace Features** (3-4 weeks)
1. 🔴 Browse marketplace listings
2. 🔴 Create listing UI with price input
3. 🔴 Buy listing flow
4. 🔴 Transaction history
5. 🟡 Proper toast/modal system

### **Phase 3: Player Progression** (2-3 weeks)
1. 🔴 Player profile program
2. 🔴 Achievement system
3. 🟡 Lifetime stats tracking
4. 🔴 Leaderboards

### **Phase 4: Polish & Launch** (2-3 weeks)
1. Security audit
2. Stress testing on Devnet
3. UI/UX improvements
4. Tutorial updates
5. Mainnet deployment

### **Phase 5: Advanced Features** (Future)
1. Staking
2. Governance
3. Seasonal events
4. Cross-chain bridges

---

## 🔧 Technical Debt

### **Current Issues:**
1. **Mock Mode Everywhere** - All blockchain calls are simulated
2. **No Error Handling** - Transactions can fail, need proper error states
3. **No Loading States** - Blockchain calls take time, need spinners
4. **No Rate Limiting** - Can spam transactions
5. **No Transaction Retry** - Network issues not handled

### **Performance Concerns:**
1. **RPC Calls** - Need to batch/cache to avoid rate limits
2. **Account Queries** - Marketplace listing queries could be slow
3. **Metadata Storage** - IPFS/Arweave upload time

---

## 📝 Documentation Needed

1. **Solana Integration Guide** - How to set up wallet, get SOL, etc.
2. **Smart Contract Deployment** - Step-by-step deployment guide
3. **Testing Guide** - How to test on Devnet
4. **API Reference** - All Anchor program instructions documented
5. **User Guide** - How to use marketplace, mint NFTs, trade

---

## 🎯 Next Immediate Steps

Based on priority, here's what to do next:

### **Step 1: Decide on Integration Approach**
Choose one:
- **A.** Build native GDExtension (best performance, most work)
- **B.** Create REST API backend (easier, requires server)
- **C.** Embedded WebView with Anchor TS (fastest to prototype)

### **Step 2: Implement alSOL Swap UI**
- Add "Get alSOL" tab to marketplace
- Wire up to smart contract (once integration ready)
- Test SOL→alSOL swap
- Test LKC→alSOL swap with weekly limits

### **Step 3: Test Wallet Connection**
- Deploy to test device
- Connect real Phantom/Solflare wallet
- Verify signature flow works

### **Step 4: Mint First NFT**
- Create metadata for lkC element
- Upload to Arweave
- Call mint_element instruction
- Verify NFT shows in wallet

### **Step 5: Create First Listing**
- Mint an element NFT
- List it on marketplace
- Query listings from program
- Display in Browse tab

---

## 📈 Success Metrics

### **Phase 1 Complete When:**
- ✅ Real wallet connects (not mock)
- ✅ Player can swap SOL → alSOL
- ✅ Player can swap LKC → alSOL (respects weekly limit)
- ✅ Player can mint element NFT
- ✅ NFT appears in Phantom wallet

### **Phase 2 Complete When:**
- ✅ Player can list NFT for sale
- ✅ Other players see listing
- ✅ Purchase completes successfully
- ✅ alSOL transfers correctly

### **Phase 3 Complete When:**
- ✅ Player stats tracked on-chain
- ✅ Achievements unlock
- ✅ Leaderboard displays top players

---

## 🤝 How to Contribute

1. Pick a task from Phase 1 (highest priority)
2. Check existing code in `godot-mobile/` and `solana-program/`
3. Follow Godot 4 and Anchor best practices
4. Test on Devnet before proposing Mainnet changes
5. Document all new features

---

**Last Updated:** 2025-11-14
**Status:** Solana Planet scene isolated, smart contracts ready, integration pending

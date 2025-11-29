# 🔗 ReAgenyx Solana Smart Contracts - Status Report

**Date:** November 25, 2025
**Working Directory:** `/Users/tobiasd/Desktop/ReAgenyx/godot-mobile`

---

## 📁 Project Structure

You have **TWO** separate Solana projects:

### 1. `solana-contracts/` (MAIN - More Complete)
**Purpose:** Token factory, marketplace, oracle system
**Status:** ✅ **Building Successfully**
**Cluster:** Devnet (configured)

**Programs:**
- ✅ `element_token_factory` (342 lines) - Element SPL token creation
- ✅ `item_marketplace` (392 lines) - NFT marketplace
- ✅ `price_oracle` (297 lines) - LKO/SOL price oracle
- ✅ `treasury_bridge` (432 lines) - In-game ↔ On-chain bridge

### 2. `solana-program/` (OLDER - Placeholder)
**Purpose:** Element NFTs, marketplace, registry
**Status:** ⚠️ **Incomplete**
**Cluster:** Localnet (configured)

**Programs:**
- ✅ `marketplace` (573 lines) - Element NFT marketplace with alSOL
- 🟡 `element-nft` (211 lines) - Element NFT minting
- ❌ `registry` (16 lines) - **PLACEHOLDER ONLY**

---

## ✅ What EXISTS and WORKS

### 1. Element Token Factory (`solana-contracts`)

**File:** `programs/element_token_factory/src/lib.rs` (342 lines)

**Features:**
- ✅ Register new elements as SPL tokens
- ✅ 10 SOL registration fee
- ✅ Co-governor support (same slot registration)
- ✅ Initial supply: 1M tokens
- ✅ Governor/market maker system
- ✅ 30-minute lock period after registration

**Instructions:**
```rust
pub fn register_element() // Register new element
pub fn deposit_to_treasury() // Deposit tokens to treasury
pub fn withdraw_from_treasury() // Withdraw (governors only)
pub fn set_market_making_ratio() // Configure market maker
```

**Key Design:**
- Element tokens are **SPL tokens** (fungible)
- First registrant = Governor (gets 70% supply)
- Co-governor can register in same slot (gets 30%)
- Locked for 30 minutes after registration

**Use Cases:**
- ✅ Create lkC, lkO, lkH, lkCa as SPL tokens
- ✅ Governor-controlled liquidity
- ✅ Market making for price stability

---

### 2. Item Marketplace (`solana-contracts`)

**File:** `programs/item_marketplace/src/lib.rs` (392 lines)

**Features:**
- ✅ Mint in-game items as NFTs (gloves, isotopes)
- ✅ List items for sale
- ✅ Buy items with SOL
- ✅ Update listing price
- ✅ Cancel listing

**Instructions:**
```rust
pub fn mint_item_nft() // Mint item NFT
pub fn list_item() // List for sale
pub fn buy_item() // Purchase item
pub fn update_listing_price() // Change price
pub fn cancel_listing() // Remove from sale
```

**Key Design:**
- Items are **NFTs** (non-fungible)
- Backend calls `mint_item_nft` after player earns item
- Marketplace uses SOL (not alSOL)

**Use Cases:**
- ✅ Mint Alchemy Gloves NFTs
- ✅ Mint isotope NFTs (lkC14, lkO18)
- ✅ Secondary market for items

---

### 3. Price Oracle (`solana-contracts`)

**File:** `programs/price_oracle/src/lib.rs` (297 lines)

**Features:**
- ✅ Store LKO/SOL exchange rate on-chain
- ✅ Authority-controlled updates (backend)
- ✅ Price staleness detection (5-minute timeout)
- ✅ Emergency circuit breaker

**Instructions:**
```rust
pub fn initialize_oracle() // Setup (once)
pub fn update_price() // Update LKO/SOL rate
pub fn set_circuit_breaker() // Emergency stop
pub fn update_authority() // Change owner
```

**Key Design:**
- Backend updates price every ~5 minutes
- Used by marketplace and swaps
- Prevents stale price exploitation

**Use Cases:**
- ✅ Real-time LKC/SOL pricing
- ✅ Fair marketplace valuations
- ✅ Swap rate calculations

---

### 4. Treasury Bridge (`solana-contracts`)

**File:** `programs/treasury_bridge/src/lib.rs` (432 lines)

**Features:**
- ✅ Bridge in-game balance → on-chain SPL tokens
- ✅ Bridge on-chain tokens → in-game balance
- ✅ Burn proof verification (backend signature)
- ✅ Fee system (3% total: 0.5% governor + 2.5% dev)
- ✅ Governor-only zero-fee bridge

**Instructions:**
```rust
pub fn bridge_to_chain() // In-game → On-chain (governor only)
pub fn bridge_from_chain() // On-chain → In-game (with fees)
pub fn withdraw_fees() // Collect accumulated fees
```

**Key Design:**
- **Two-way bridge** between game database and blockchain
- Backend signs burn proofs to prevent double-spending
- Fees on player bridges, free for governors
- Governor = market maker (provides liquidity)

**Use Cases:**
- ✅ Convert in-game lkC to on-chain lkC SPL tokens
- ✅ Trade on-chain, bring back to game
- ✅ Governor can provide DEX liquidity

---

### 5. Marketplace (alSOL) (`solana-program`)

**File:** `programs/marketplace/src/lib.rs` (573 lines)

**Features:**
- ✅ Create listing for element NFTs
- ✅ Buy NFT with alSOL currency
- ✅ Update listing price
- ✅ Cancel listing
- ✅ Escrow system

**Instructions:**
```rust
pub fn create_listing() // List NFT for alSOL
pub fn buy_nft() // Purchase with alSOL
pub fn update_price() // Change price
pub fn cancel_listing() // Remove listing
```

**Key Design:**
- Uses **alSOL** (in-game currency backed 1:1 by SOL)
- Element NFTs (not tokens!)
- Escrow holds NFT until sold

**Status:** ⚠️ **Conflicts with element_token_factory design**
- element_token_factory = SPL tokens (fungible)
- marketplace = NFTs (non-fungible)
- **Need to decide:** Elements as tokens OR NFTs?

---

### 6. Element NFT (`solana-program`)

**File:** `programs/element-nft/src/lib.rs` (211 lines)

**Features:**
- 🟡 Mint element as NFT
- 🟡 Update amount
- 🟡 Burn element
- 🟡 Isotope support with volume/decay

**Instructions:**
```rust
pub fn mint_element() // Create element NFT
pub fn update_amount() // Change quantity
pub fn burn_element() // Destroy NFT
```

**Status:** 🟡 **Partially Complete**
- Basic structure exists
- Missing Metaplex metadata integration
- Missing tests

---

## ❌ What is MISSING

### 1. Discovery NFT System
**Purpose:** Mint NFTs for first discoverers of compounds

**What's Needed:**
- New program: `discovery_registry`
- Store compound discoveries on-chain
- Mint discovery NFT to first creator
- 72-hour tax-free tracking
- Royalty distribution system

**Priority:** 🔴 HIGH (core game mechanic)

---

### 2. Chemistry Reaction Verification
**Purpose:** Optional on-chain reaction verification

**What's Needed:**
- Registry of valid reactions
- On-chain reaction validation
- Success rate enforcement
- Input/output verification

**Priority:** 🟡 MEDIUM (backend can handle this)

---

### 3. alSOL Token Implementation
**Purpose:** In-game currency backed 1:1 by SOL

**What's Needed:**
- SPL token mint for alSOL
- Swap program (SOL ↔ alSOL)
- LKC swap with weekly limits
- Integration with marketplace

**Priority:** 🔴 HIGH (mentioned in README but not implemented)

**Note:** Currently mentioned in marketplace but token doesn't exist!

---

### 4. Registry Program (Placeholder)
**File:** `solana-program/programs/registry/src/lib.rs` (16 lines)

**Status:** ❌ **ONLY A COMMENT**

```rust
// TODO: Implement registry program
// - Store element definitions on-chain
// - Validate elements before minting
// - Track reaction formulas
// - Admin-controlled updates
```

**Priority:** 🟡 MEDIUM (nice to have for transparency)

---

### 5. Burn Proof Program
**Purpose:** Verify backend signatures for bridge operations

**What's Needed:**
- Store burn proof authority public key
- Verify signatures on bridge transactions
- Prevent replay attacks
- Nonce management

**Priority:** 🟢 LOW (backend already handles this)

---

## 🔀 CONFLICTS & DESIGN DECISIONS NEEDED

### Decision 1: Elements as Tokens OR NFTs?

**Option A: SPL Tokens (element_token_factory)**
- ✅ Fungible (1 lkC = 1 lkC)
- ✅ Can split/merge amounts
- ✅ Works with DEX/swaps
- ✅ Better for currency-like elements
- ❌ No unique properties per unit
- ❌ Not truly "collectable"

**Option B: NFTs (element-nft)**
- ✅ Unique collectables
- ✅ Can have metadata (rarity, discovery date)
- ✅ Better for showcase/trophies
- ❌ Can't split amounts easily
- ❌ Harder to trade on DEX
- ❌ More complex for inventory

**Recommendation:**
- **Elements (lkC, lkO, lkH) = SPL Tokens** (fungible)
- **Compounds (H₂O, CO₂, CaCO₃) = NFTs** (unique discoveries)
- **Items (Gloves, Isotopes) = NFTs** (already implemented)

---

### Decision 2: Which Project to Use?

**`solana-contracts/` (Recommended)**
- ✅ More complete (4 programs)
- ✅ Building successfully
- ✅ Better architecture
- ✅ Deployed program IDs on devnet
- ✅ Token-based (fungible elements)

**`solana-program/` (Legacy)**
- ⚠️ Only 1 complete program
- ⚠️ Registry is placeholder
- ⚠️ NFT-based (conflicts with token design)
- ✅ Has alSOL marketplace design

**Recommendation:** **Use `solana-contracts/` as main, merge alSOL marketplace from `solana-program/`**

---

## 📊 Implementation Status Summary

| Feature | Status | Location | Priority |
|---------|--------|----------|----------|
| Element Tokens (SPL) | ✅ Complete | solana-contracts | Done |
| Item Marketplace | ✅ Complete | solana-contracts | Done |
| Price Oracle | ✅ Complete | solana-contracts | Done |
| Treasury Bridge | ✅ Complete | solana-contracts | Done |
| Element NFT Marketplace (alSOL) | 🟡 Needs merge | solana-program | HIGH |
| Discovery NFTs | ❌ Missing | N/A | HIGH |
| alSOL Token | ❌ Missing | N/A | HIGH |
| Chemistry Registry | ❌ Placeholder | solana-program | MEDIUM |
| Burn Proof Verification | 🟡 In bridge | solana-contracts | LOW |

---

## 🚀 RECOMMENDED NEXT STEPS

### Phase 1: Critical (Minimum Viable Product)

1. **Create alSOL Token**
   - Create SPL token mint
   - Authority = backend/treasury
   - 1:1 backing with SOL in treasury

2. **Implement alSOL Swap Program**
   - SOL → alSOL (instant, 1:1)
   - LKC → alSOL (1M:1, weekly limit)
   - alSOL → SOL (instant withdrawal)

3. **Implement Discovery NFT System**
   - New program: `discovery_registry`
   - Mint NFT to first compound creator
   - Store discovery metadata (date, wallet, compound)
   - 72-hour tax tracking

4. **Merge alSOL Marketplace**
   - Port from `solana-program/marketplace`
   - Integrate with actual alSOL token
   - List element tokens for sale
   - Buy with alSOL

### Phase 2: Enhanced Features

5. **Chemistry Registry (On-Chain)**
   - Store element definitions
   - Store reaction formulas
   - Validation functions
   - Public transparency

6. **Compound NFT System**
   - Separate from element tokens
   - Mint compound NFTs (H₂O, CO₂, etc.)
   - Unique discovery metadata
   - Secondary marketplace

7. **Testing & Deployment**
   - Write tests for all programs
   - Deploy to devnet
   - Integration testing with backend
   - Deploy to mainnet

---

## 🛠️ Development Commands

### Build All Programs
```bash
cd solana-contracts
anchor build
```

### Test Programs
```bash
anchor test
```

### Deploy to Devnet
```bash
anchor deploy --provider.cluster devnet
```

### Get Program Addresses
```bash
anchor keys list
```

---

## 📝 Architecture Recommendation

### Final Architecture (Hybrid Approach)

```
┌─────────────────────────────────────────────────────┐
│                  BLOCKCHAIN LAYER                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Elements (Fungible)          Compounds (NFTs)      │
│  ├── lkC SPL Token            ├── H₂O NFT          │
│  ├── lkO SPL Token            ├── CO₂ NFT          │
│  ├── lkH SPL Token            └── CaCO₃ NFT        │
│  └── lkCa SPL Token                                 │
│                                                      │
│  Items (NFTs)                 Currency              │
│  ├── Gloves NFT               ├── alSOL Token      │
│  ├── lkC14 Isotope NFT        └── SOL              │
│  └── lkO18 Isotope NFT                             │
│                                                      │
│  Programs                                            │
│  ├── element_token_factory (tokens)                │
│  ├── item_marketplace (item NFTs)                  │
│  ├── compound_nft_factory (compound NFTs) [NEW]    │
│  ├── discovery_registry (first discoveries) [NEW]  │
│  ├── alsol_swap (SOL/LKC ↔ alSOL) [NEW]          │
│  ├── element_marketplace (trade tokens w/alSOL)   │
│  ├── price_oracle (LKC/SOL rate)                   │
│  └── treasury_bridge (game ↔ chain)                │
└─────────────────────────────────────────────────────┘
```

---

## 💡 Key Design Principles

1. **Elements = Tokens** (fungible, tradeable, splittable)
2. **Compounds = NFTs** (unique, discoverable, collectable)
3. **Items = NFTs** (equipment, isotopes)
4. **alSOL = Currency** (stable in-game token backed by SOL)
5. **Backend Authority** (signs burn proofs, updates oracle)
6. **Governor System** (market makers for liquidity)

---

## ✅ What You Have (Summary)

**Working Programs:** 4/7 (57%)
- ✅ Element Token Factory
- ✅ Item Marketplace
- ✅ Price Oracle
- ✅ Treasury Bridge

**Missing Critical Programs:** 3
- ❌ alSOL Token & Swap
- ❌ Discovery NFT Registry
- ❌ Element Marketplace (alSOL)

**Conflicts to Resolve:** 1
- 🔀 Element tokens vs NFTs (recommend: tokens)

**Build Status:** ✅ All programs compile successfully

---

**Next Session: Implement alSOL token and discovery NFT system!** 🚀

# LenKinVerse On-Chain Architecture & Roadmap

**Last Updated:** 2025-11-17
**Status:** Oracle & Bridge Complete, Refactoring Needed

---

## 🎯 Core Architecture Principle

**In-game elements are pure game data. Blockchain only involved when bridging.**

```
┌─────────────────────────────────────────────────────────────┐
│                    IN-GAME (Game Server)                     │
├─────────────────────────────────────────────────────────────┤
│ • Discovery: 0.1% chance via nuclear reaction               │
│ • Storage: All elements stored as game data (database)      │
│ • Tax: 10% to treasury (game data)                          │
│ • Spawns: Wild spawns based on treasury balance             │
│ • Swaps: Players swap elements ↔ alSOL (game server)        │
│                                                              │
│ NO BLOCKCHAIN CALLS FOR NORMAL GAMEPLAY                     │
└─────────────────────────────────────────────────────────────┘
                              ↕️
                    (Governor Bridge Only)
                              ↕️
┌─────────────────────────────────────────────────────────────┐
│                  ON-CHAIN (Solana Blockchain)                │
├─────────────────────────────────────────────────────────────┤
│ • Registration: Governor pays 10 SOL → SPL mint created     │
│ • Bridge To Chain: Game treasury → Mint SPL tokens          │
│ • Bridge To Game: Burn SPL → Credit game treasury           │
│ • DEX Trading: SPL tokens tradeable on Raydium/Orca         │
│ • Liquidity: Governors provide liquidity for trading        │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Currently Implemented (What We Have)

### **1. Element Token Factory** (440 lines)
```rust
✅ register_element
   - Pays 10 SOL to protocol treasury
   - Creates SPL token mint for element
   - Co-governor same-slot detection
   - 30-minute lock period before tradeable
   - Metaplex metadata

❌ mint_element_tokens (WRONG - TO BE REMOVED)
   - Was designed for "mint per discovery"
   - Not needed in game-data-first architecture

✅ mark_tradeable
   - Marks element tradeable after 30 min

✅ get_element_info
   - View element data
```

**Status:** Needs refactoring to remove mint_element_tokens

---

### **2. Treasury Bridge** (280 lines)
```rust
✅ bridge_to_chain
   - Governor bridges game treasury → on-chain SPL tokens
   - Requires burn proof from backend
   - Mints SPL tokens to governor
   - Backend deletes game data

✅ bridge_to_ingame
   - Governor burns on-chain SPL tokens
   - Emits event for backend
   - Backend credits game treasury
   - Increases wild spawn rate

✅ get_bridge_history
   - Query historical bridge transactions
```

**Status:** ✅ Core logic correct, needs backend authority validation

---

### **3. Price Oracle** (297 lines)
```rust
✅ initialize_oracle
   - Set up LKO/SOL price feed

✅ update_price
   - Backend updates LKO/SOL price every 60s

✅ update_element_price
   - Backend updates element-specific prices
   - For elements with DEX liquidity

✅ get_price
   - Query price with staleness check (5 min)

✅ set_oracle_active
   - Emergency pause

✅ transfer_authority
   - Upgrade to multisig/DAO
```

**Status:** ✅ Production ready

---

### **4. Element Marketplace** (320 lines)
```rust
❌ swap_element_for_alsol (WRONG IMPLEMENTATION)
   - Currently swaps "in-game element" for alSOL
   - Should swap "on-chain SPL element" for alSOL
   - In-game swaps handled by game server

❌ swap_alsol_for_element (WRONG IMPLEMENTATION)
   - Same issue as above
```

**Status:** Needs refactoring to work with on-chain SPL tokens only

---

### **5. Item Marketplace** (390 lines)
```rust
🟡 mint_item_nft
🟡 list_item
🟡 buy_item
🟡 cancel_listing
```

**Status:** Has Anchor compatibility issues, low priority

---

## 🚧 Architecture Fixes Needed

### **Priority 1: Remove Incorrect Minting Logic**

**Issue:** `mint_element_tokens` assumes minting happens per discovery
**Fix:** Remove this instruction entirely

**Current Wrong Flow:**
```
Player discovers element → Backend calls mint_element_tokens → SPL minted
(This costs gas per discovery - terrible for scalability)
```

**Correct Flow:**
```
Player discovers element → Game server adds to inventory (game data)
Governor bridges → Backend calls bridge_to_chain → SPL minted in batch
(Zero gas for discoveries, batch minting when bridging)
```

---

### **Priority 2: Fix Element Marketplace**

**Issue:** Marketplace swaps "in-game data" instead of "on-chain SPL"
**Fix:** Refactor to only handle on-chain SPL ↔ alSOL swaps

**Current Wrong Implementation:**
```rust
// This assumes player has "in-game element data"
pub fn swap_element_for_alsol(
    element_amount: u64, // In-game data (wrong)
) -> Result<()>
```

**Correct Implementation:**
```rust
// Player must have on-chain SPL tokens first
pub fn swap_element_for_alsol(
    element_token_account: Account<'info, TokenAccount>, // On-chain SPL
    amount: u64,
) -> Result<()> {
    // Transfer SPL tokens to pool
    // Calculate alSOL based on oracle
    // Transfer alSOL to player
}
```

**In-game swaps should be handled by game server:**
```typescript
// Backend handles this, not blockchain
app.post('/swap-element-for-alsol', async (req) => {
    const { playerId, elementId, amount } = req.body;

    // Check player has element in game DB
    const playerInventory = await db.getInventory(playerId);

    // Deduct element from inventory
    await db.updateInventory(playerId, elementId, -amount);

    // Credit alSOL to player (game data)
    await db.creditAlsol(playerId, calculateAlsol(amount));
});
```

---

### **Priority 3: Add Backend Authority Validation**

**Issue:** No backend authority check on bridge_to_chain
**Risk:** Anyone can mint SPL tokens without burning game data
**Fix:** Add backend_authority PDA validation

```rust
// Add backend authority to bridge_to_chain
#[account(
    seeds = [b"backend_authority"],
    bump
)]
pub backend_authority: Account<'info, BackendAuthority>,

// Verify burn proof signature
require!(
    verify_signature(&burn_proof, &backend_authority.pubkey),
    ErrorCode::InvalidBurnProof
);
```

---

## 📋 Updated Roadmap

### **Phase 1: Architecture Fixes** (Current Focus)

**Goal:** Fix misaligned on-chain logic to match game-data-first design

- [ ] **Remove `mint_element_tokens` from element_token_factory**
  - This instruction doesn't fit the architecture
  - Minting happens via `bridge_to_chain` only

- [ ] **Add backend authority validation to `bridge_to_chain`**
  - Prevent unauthorized minting
  - Verify burn proof signature

- [ ] **Refactor element_marketplace**
  - Remove "in-game data" swap logic
  - Focus on on-chain SPL ↔ alSOL swaps (like Raydium)
  - In-game swaps handled by game server

- [ ] **Add `initialize_treasury` instruction**
  - Create treasury alSOL token accounts
  - Allow governor to fund initial liquidity

---

### **Phase 2: Core Integration** (Next)

**Goal:** Connect game server ↔ blockchain via backend

- [ ] **Backend Service: Burn Proof Signer**
  - Sign burn proofs for bridge_to_chain
  - Verify game treasury balance before signing
  - Prevent double-minting attacks

- [ ] **Backend Service: Event Listener**
  - Listen for BridgedToIngame events
  - Credit game treasury when SPL burned
  - Update wild spawn rates

- [ ] **Backend Service: Price Oracle Updater**
  - Update LKO/SOL price every 60s
  - Update element prices for popular elements
  - Monitor for anomalies

---

### **Phase 3: DEX Integration** (Later)

**Goal:** Enable on-chain trading for SPL element tokens

- [ ] **Raydium/Orca Pool Creation**
  - Governors create liquidity pools
  - Element SPL ↔ SOL pairs
  - Earn trading fees

- [ ] **Oracle Price Sync**
  - Read DEX TWAP for element prices
  - Update element oracle with DEX prices
  - Hybrid validation (authority + DEX bounds)

---

### **Phase 4: Advanced Features** (Future)

**Goal:** Polish and expand ecosystem

- [ ] **Governance System**
  - Element School Master powers (quests, lore)
  - Tax rate voting (within 5%-15% bounds)
  - Upgrade authority to DAO

- [ ] **Analytics & Stats**
  - On-chain element ranking
  - Governor leaderboard
  - Treasury balance tracking

- [ ] **Cross-Chain Expansion**
  - SUI planet integration
  - Cross-chain element bridge
  - Multi-chain liquidity

---

## 🔑 Key Decisions Made

### **Decision 1: Game Data First**
**Choice:** In-game elements stored as game data, not minted per discovery
**Rationale:** Scalability, zero gas for normal gameplay
**Impact:** Refactor needed for element_marketplace and mint logic

### **Decision 2: Authority-Based Oracle**
**Choice:** Backend-controlled price oracle (not TWAP for now)
**Rationale:** Faster MVP, full control during bootstrap
**Impact:** Can upgrade to TWAP later, clear migration path

### **Decision 3: Governor-Only Bridging**
**Choice:** Only governors can bridge treasury ↔ chain
**Rationale:** Aligns incentives, creates governor value proposition
**Impact:** Regular players trade in-game only

---

## 🎯 Current Sprint Goals

### **This Week:**
1. Remove `mint_element_tokens` from element_token_factory
2. Add backend authority to `bridge_to_chain`
3. Fix element_marketplace to handle on-chain SPL only

### **Next Week:**
1. Deploy to devnet
2. Test full bridge flow (game → chain → game)
3. Build backend burn proof signer

### **By End of Month:**
1. Mobile app integration with backend
2. End-to-end testing on devnet
3. Security audit preparation

---

## 📊 Progress Tracking

### **Smart Contracts:**
- ✅ Element Token Factory (needs refactoring)
- ✅ Price Oracle (production ready)
- ✅ Treasury Bridge (needs auth validation)
- 🔄 Element Marketplace (needs refactoring)
- 🟡 Item Marketplace (low priority, has issues)

### **Backend Services:**
- ⏳ Burn proof signer (not started)
- ⏳ Event listener (not started)
- ✅ Price oracle updater (script ready)

### **Mobile Integration:**
- ✅ All game logic implemented (mock mode)
- ⏳ Blockchain connection (not started)
- ⏳ Backend HTTP calls (not started)

---

## 🚨 Critical Blockers

1. **Backend Authority Missing**
   - Risk: Unauthorized minting possible
   - Impact: Security vulnerability
   - ETA: 2 hours to implement

2. **Architecture Misalignment**
   - Issue: Smart contracts assume wrong flow
   - Impact: Need refactoring before integration
   - ETA: 4-6 hours to fix

3. **alSOL Mint Not Deployed**
   - Issue: Marketplace references undefined alSOL mint
   - Impact: Can't test swaps
   - Decision Needed: Create our own or use existing?

---

## 💡 Your Original Vision vs Current Implementation

### **Your Vision (Correct):**
```
In-game → Pure game data (fast, scalable)
Bridge → Blockchain involved (governor only)
Trading → On-chain SPL tokens (DEX-like)
```

### **Current Implementation (Needs Fix):**
```
❌ mint_element_tokens assumes per-discovery minting
❌ element_marketplace swaps in-game data
✅ bridge_to_chain/ingame matches vision
✅ price_oracle matches vision
```

### **After Refactoring:**
```
✅ All in-game as game data
✅ Blockchain only for bridge
✅ On-chain trading for SPL tokens
✅ Governors manage liquidity
```

---

**Next Steps:** Refactor to match your original (correct) vision!

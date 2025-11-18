# alSOL Architecture Analysis

**Last Updated:** 2025-11-17

---

## 🔍 Current Implementation Status

### **What We Have Implemented:**

#### **1. In-Game alSOL (Godot Mobile)**
**Location:** `godot-mobile/scripts/ui/marketplace_ui.gd`

**Type:** Pure game data (number in database)

**Features:**
```gdscript
# Players can get alSOL two ways:

1. SOL → alSOL (Direct swap, 1:1 ratio)
   - Player connects wallet
   - Swaps SOL for alSOL via WalletManager.swap_sol_for_alsol()
   - Blockchain transaction
   - alSOL balance updated in-game

2. LKC → alSOL (In-game materials, rate-limited)
   - Player burns 1,000 LKC → 0.001 alSOL (1M:1 ratio)
   - Weekly limit: 1 alSOL per week
   - Pure game server transaction (no blockchain)
   - Burns in-game LKC, credits in-game alSOL
```

**Constraints:**
```gdscript
const MIN_ALSOL_LAMPORTS: int = 1_000_000      # 0.001 alSOL minimum
const MAX_WEEKLY_ALSOL_LAMPORTS: int = 1_000_000_000  # 1 alSOL weekly cap
const LKC_PER_ALSOL: int = 1_000_000           # 1M LKC = 1 alSOL
```

**Use Cases (In-Game):**
- ✅ Buy more LKC from marketplace (if needed)
- ✅ Register elements (pay 10 alSOL = 10 SOL equivalent)
- ⏳ Future: Buy power-ups, speed-ups, cosmetics

---

#### **2. On-Chain alSOL (Smart Contracts)**
**Location:** `programs/element_marketplace/src/lib.rs`

**Type:** SPL Token (like USDC, actual on-chain token)

**Features:**
```rust
// On-chain swaps (DEX-like functionality)

1. Element SPL → alSOL
   - Player has Carbon_X SPL tokens on-chain
   - Swaps for alSOL using oracle price
   - Receives alSOL SPL tokens to wallet

2. alSOL → Element SPL
   - Player has alSOL SPL tokens
   - Swaps for Carbon_X using oracle price
   - Receives Carbon_X SPL tokens
```

**Constraints:**
```rust
// Staleness protection (5 minutes)
require!(current_time - oracle.last_updated < 300);

// Treasury balance check
require!(treasury_alsol >= swap_amount);
```

**Use Cases (On-Chain):**
- ✅ Trade element SPL tokens ↔ alSOL on DEX
- ✅ Provide liquidity on Raydium/Orca
- ⏳ Future: Collateral for loans, staking, etc.

---

## ❌ What's Missing: alSOL Mint & Bridge

### **Critical Issue:**
We reference `alsol_mint` in smart contracts but **never created it!**

```rust
// In element_marketplace.rs - REFERENCES alSOL mint
pub alsol_mint: Account<'info, Mint>,  // ❌ Where does this come from?
```

### **Two Options:**

---

## Option 1: Create Our Own alSOL Wrapper

**Concept:** alSOL = Wrapped SOL (like wSOL or alSOL from Marinade)

### **Pros:**
- Full control over supply and economics
- Can add custom features (staking rewards, etc.)
- Revenue from wrapping fees (optional)

### **Cons:**
- Need to build trust (liquidity required)
- Maintenance burden (oracle, security)
- Competing with established wSOL/mSOL

### **Implementation:**
```rust
// New program: alsol_wrapper

pub fn wrap_sol(
    ctx: Context<WrapSol>,
    sol_amount: u64,
) -> Result<()> {
    // Transfer SOL to protocol vault
    transfer_sol(ctx.accounts.player, ctx.accounts.vault, sol_amount)?;

    // Mint alSOL 1:1
    mint_alsol(ctx.accounts.player_alsol_account, sol_amount)?;

    Ok(())
}

pub fn unwrap_alsol(
    ctx: Context<UnwrapAlsol>,
    alsol_amount: u64,
) -> Result<()> {
    // Burn alSOL
    burn_alsol(ctx.accounts.player_alsol_account, alsol_amount)?;

    // Return SOL from vault
    transfer_sol(ctx.accounts.vault, ctx.accounts.player, alsol_amount)?;

    Ok(())
}
```

**alSOL Properties:**
- 1 alSOL = 1 SOL (always)
- SPL token with 9 decimals
- Backed 1:1 by SOL in protocol vault
- Can trade on DEX, use in DeFi

---

## Option 2: Use Existing Liquid Staking Token

**Concept:** Use Marinade mSOL, Lido stSOL, or Jito jitoSOL

### **Pros:**
- Already has liquidity and trust
- No maintenance required
- Yields passive staking rewards (~6-8% APY)
- Saves development time

### **Cons:**
- Less control over economics
- Dependency on external protocol
- Price may fluctuate (1 mSOL ≈ 1.05 SOL due to staking)

### **Integration:**
```rust
// Use Marinade mSOL as alSOL
pub const ALSOL_MINT: Pubkey = pubkey!("mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So");

// No wrapping needed - players buy mSOL directly
pub fn swap_element_for_msol(
    ctx: Context<SwapElementForMsol>,
    element_amount: u64,
) -> Result<()> {
    // Transfer element SPL to treasury
    // Transfer mSOL from treasury to player (using oracle price)
}
```

**Popular Options:**
- **Marinade mSOL:** Most liquid, 1 mSOL ≈ 1.05 SOL
- **Lido stSOL:** Lower fees, similar APY
- **Jito jitoSOL:** MEV rewards included

---

## 🎯 Recommended Architecture

### **Hybrid Model: Two Types of alSOL**

```
┌─────────────────────────────────────────────────────────┐
│              IN-GAME alSOL (Game Data)                  │
├─────────────────────────────────────────────────────────┤
│ • Type: Number in database                              │
│ • Source 1: Swap SOL → alSOL (blockchain tx)            │
│ • Source 2: Burn 1M LKC → 0.001 alSOL (game server)     │
│ • Uses: Register elements, buy in-game items            │
│ • Bridge: Can withdraw to on-chain SPL (future)         │
└─────────────────────────────────────────────────────────┘
                          ↕️
                  (Bridge - Future)
                          ↕️
┌─────────────────────────────────────────────────────────┐
│            ON-CHAIN alSOL (SPL Token)                   │
├─────────────────────────────────────────────────────────┤
│ • Type: SPL token (mSOL or custom wrapper)              │
│ • Source: Wrap SOL → alSOL on-chain                     │
│ • Uses: Trade element SPL, provide DEX liquidity        │
│ • Bridge: Can deposit to in-game (future)               │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Decision Matrix

| Feature | Custom alSOL Wrapper | Use mSOL/stSOL |
|---------|---------------------|----------------|
| **Control** | ✅ Full control | ❌ External dependency |
| **Liquidity** | ❌ Need to build | ✅ Existing pools |
| **Development** | ❌ 2-3 days work | ✅ 2-3 hours integration |
| **Trust** | ❌ New protocol | ✅ Battle-tested |
| **Revenue** | ✅ Can charge fees | ❌ No revenue |
| **Yield** | ❌ No staking yield | ✅ ~6-8% APY |
| **Price Stability** | ✅ Always 1:1 | 🟡 ~1.05:1 (fluctuates) |
| **Security Risk** | ❌ Higher (new code) | ✅ Lower (audited) |

---

## 💡 My Recommendation

### **For MVP: Use Marinade mSOL**

**Why:**
1. **Faster to market:** 2-3 hours vs 2-3 days
2. **Lower risk:** Battle-tested, $500M+ TVL
3. **Better UX:** Players earn staking yield passively
4. **Existing liquidity:** Can swap on Raydium/Orca immediately

**Implementation:**
```rust
// In Anchor.toml
[constants]
ALSOL_MINT = "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So"  # Marinade mSOL

// In element_marketplace.rs
use anchor_spl::token::Mint;

#[account(
    constraint = alsol_mint.key() == ALSOL_MINT @ ErrorCode::InvalidAlsolMint
)]
pub alsol_mint: Account<'info, Mint>,
```

**In-Game Integration:**
```gdscript
# In WalletManager.gd
const MSOL_MINT = "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So"

func swap_sol_for_alsol(sol_amount: float) -> void:
    # Use Jupiter Aggregator to swap SOL → mSOL
    var swap_params = {
        "inputMint": "So11111111111111111111111111111111111111112",  # SOL
        "outputMint": MSOL_MINT,  # mSOL
        "amount": int(sol_amount * 1_000_000_000),
        "slippageBps": 50  # 0.5% slippage
    }

    # Call Jupiter API
    var tx = await backend.call_jupiter_swap(swap_params)
    emit transaction_completed(tx.signature)
```

---

### **Future: Build Custom alSOL (Post-MVP)**

Once we have:
- ✅ Stable user base (1000+ active players)
- ✅ Treasury size ($100K+ SOL)
- ✅ Security audit budget

Then we can:
1. Deploy custom alSOL wrapper
2. Migrate users from mSOL → alSOL
3. Add custom features (boosted yields for governors, etc.)
4. Create our own liquidity pools

---

## 🔄 Bridge Flow (Future Feature)

### **In-Game alSOL → On-Chain mSOL**

```
Player has 10 alSOL in-game
→ Clicks "Withdraw to Wallet"
→ Backend verifies balance
→ Backend transfers 10 mSOL from protocol wallet to player
→ Backend deducts 10 alSOL from in-game balance
→ Player receives 10 mSOL on-chain
```

### **On-Chain mSOL → In-Game alSOL**

```
Player has 10 mSOL on-chain
→ Clicks "Deposit from Wallet"
→ Player transfers 10 mSOL to protocol wallet
→ Backend listens for transfer event
→ Backend credits 10 alSOL to in-game balance
→ Player can use in-game
```

**Note:** Bridge is **optional** for MVP - players can start with in-game only

---

## ✅ Implementation Checklist

### **Immediate (For MVP):**

- [ ] **Choose alSOL Type**
  - Decision: Use Marinade mSOL
  - Reason: Faster, safer, existing liquidity

- [ ] **Update Smart Contracts**
  - Add mSOL mint constant to Anchor.toml
  - Update element_marketplace to use mSOL
  - Remove references to "in-game alSOL swaps"

- [ ] **Mobile Integration**
  - Integrate Jupiter Aggregator for SOL → mSOL swaps
  - Update WalletManager.swap_sol_for_alsol()
  - Show mSOL balance in UI

- [ ] **Backend Service**
  - Track in-game alSOL balance (database)
  - Handle LKC → alSOL conversions (weekly limits)
  - (Optional) Bridge service for later

### **Future (Post-MVP):**

- [ ] **Custom alSOL Wrapper**
  - Deploy alsol_wrapper program
  - Create SOL vault for backing
  - Migrate from mSOL to custom alSOL

- [ ] **Bridge Feature**
  - In-game ↔ on-chain alSOL transfers
  - Event listener for deposits
  - Transaction signing for withdrawals

- [ ] **Advanced Features**
  - Staking rewards for in-game alSOL holders
  - Governor bonuses (boosted yields)
  - DAO treasury management

---

## 📊 Current State Summary

### **What Works:**
✅ In-game alSOL tracking (database)
✅ LKC → alSOL conversion with limits
✅ Smart contract structure for swaps

### **What's Missing:**
❌ Actual alSOL mint deployment
❌ SOL → mSOL integration
❌ Bridge between in-game ↔ on-chain

### **What Needs Fixing:**
🔄 element_marketplace assumes wrong flow
🔄 Need to choose: custom wrapper vs mSOL
🔄 Update documentation to clarify two types

---

## 🎯 Final Recommendation

**Use Marinade mSOL for MVP:**

```
Phase 1 (Now): In-game alSOL only
├─ LKC → alSOL (game server, weekly limit)
├─ SOL → mSOL (Jupiter swap, in-game balance)
└─ No bridge (in-game stays in-game)

Phase 2 (Later): Add on-chain mSOL swaps
├─ Element SPL ↔ mSOL swaps
├─ Oracle-based pricing
└─ Still no bridge (optional feature)

Phase 3 (Future): Bridge + Custom alSOL
├─ In-game ↔ on-chain transfers
├─ Custom alSOL wrapper deployment
└─ Migration from mSOL
```

**This gives us:**
- ✅ Fast MVP launch (use existing mSOL)
- ✅ Proven security (Marinade audited)
- ✅ Passive yield for players (~6-8% APY)
- ✅ Clear upgrade path (custom alSOL later)

---

**Decision needed:** Use mSOL or build custom wrapper?

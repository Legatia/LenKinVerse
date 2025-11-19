# Element Token Discovery & Registration Flow

**Version:** 2.0 (Updated based on Solana_market_maker.md discussion)
**Last Updated:** 2025-11-16

## Overview

This document describes the complete flow for discovering new elements, registering them as on-chain tokens, and managing the governance/market-making system.

---

## 1. Discovery Flow

### Nuclear Reaction Success → New Element Discovery

When a player successfully discovers a new element via nuclear reaction (0.1% chance on failure with isotopes):

```
Player uses isotopes → Nuclear reaction (10% success, 0.1% discovery on failure) → New Element Created
```

### Discovery Modal Decision

The player sees a modal with two choices:

#### **Option A: Register as Token (10 alSOL)**
- Become **Governor** (Money Manager role)
- Earn 10% tax on all future discoveries
- Global announcement to all players
- Element becomes tradeable after **30-minute lock period**
- Element spawns in wild after lock period

#### **Option B: Keep Unregistered (FREE)**
- **10x isotope discovery rate** (1% vs 0.1%)
- **Multiply with gloves** using lkC as catalyst (2x charge cost)
- **Secret advantage** - only you know it exists
- Can register later (but lose governorship to first registrar)
- Perks disappear once element is registered

---

## 2. Registration System

### Race Condition Handling

**Scenario:** Multiple players discover the same element simultaneously.

```
Player A discovers Element_Z → Clicks "Register" → Pays 10 alSOL
Player B discovers Element_Z → Clicks "Register" → Sees "Waiting in queue..."
```

#### Queue States:
1. **"available"**: No one registering, proceed to payment
2. **"in_queue"**: Someone is processing payment, you wait in line
3. **"registered"**: Already registered, show tax info

#### Co-Governor Logic:
- If **Player A** and **Player B** both confirm transactions **in the same blockchain slot**:
  - Both become **co-governors**
  - **Player A** (first by timestamp) = **Money Manager** (handles liquidity/bridge)
  - **Player B** (second) = **Element School Master** (future role for quests/lore)
  - Revenue split: **100% tax to Money Manager** (School Master is titular)
  - Joint liquidity pool created

- If **Player B** confirms after Player A's transaction is finalized:
  - Player A becomes sole governor
  - Player B receives element with tax applied
  - Player B sees notification: "Already registered by [Player A]"

---

## 3. Smart Contract Architecture

### Program 1: Element Registry

Stores global element registration data.

```rust
// Element Registry Account
pub struct ElementRegistry {
    pub elements: HashMap<String, ElementData>,
}

pub struct ElementData {
    pub element_id: String,
    pub governor: Pubkey,           // Money Manager
    pub co_governor: Option<Pubkey>, // Element School Master (if exists)
    pub registered_at: i64,
    pub tradeable_at: i64,          // registered_at + 1800 (30 min)
    pub treasury: Pubkey,           // Treasury PDA
    pub tax_rate: u16,              // 1000 = 10% (basis points)
    pub total_minted: u64,
    pub rarity: u8,
}

// Instructions
pub fn register_element(
    ctx: Context<RegisterElement>,
    element_id: String,
    payment: u64,  // 10 SOL or 10 alSOL
) -> Result<()> {
    // Check if element already exists
    let element_registry = &mut ctx.accounts.element_registry;

    if element_registry.elements.contains_key(&element_id) {
        // Check if same-slot transaction (co-governor case)
        let current_slot = Clock::get()?.slot;
        let registered_slot = get_transaction_slot(element_registry.elements[&element_id].registered_at);

        if current_slot == registered_slot {
            // Add as co-governor
            element_registry.elements.get_mut(&element_id).unwrap().co_governor = Some(ctx.accounts.governor.key());
            msg!("Co-governor assigned: {}", ctx.accounts.governor.key());
        } else {
            // Already registered, refund payment
            return Err(ErrorCode::ElementAlreadyRegistered.into());
        }
    } else {
        // New registration
        let current_time = Clock::get()?.unix_timestamp;

        // Create treasury PDA
        let treasury = create_treasury_pda(&element_id)?;

        element_registry.elements.insert(element_id.clone(), ElementData {
            element_id: element_id.clone(),
            governor: ctx.accounts.governor.key(),
            co_governor: None,
            registered_at: current_time,
            tradeable_at: current_time + 1800, // 30 minutes
            treasury,
            tax_rate: 1000, // 10%
            total_minted: 0,
            rarity: 0,
        });

        msg!("Element registered: {} by {}", element_id, ctx.accounts.governor.key());
    }

    // Transfer payment to protocol treasury
    transfer_payment(&ctx, payment)?;

    // Emit event for backend
    emit!(ElementRegistered {
        element_id,
        governor: ctx.accounts.governor.key(),
        registered_at: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
```

### Program 2: Element Treasury & Bridge

Manages in-game ↔ on-chain bridging with proof-of-burn.

```rust
pub struct ElementTreasury {
    pub element_id: String,
    pub balance: u64,              // In-game element units
    pub alsol_balance: u64,        // alSOL for player swaps
    pub governors: Vec<Pubkey>,    // [Money Manager, School Master]
    pub total_taxed: u64,
}

// Bridge instruction: In-game → On-chain
pub fn bridge_to_chain(
    ctx: Context<BridgeToChain>,
    element_id: String,
    amount: u64,
    burn_proof: BurnProof,  // Signed by backend
) -> Result<()> {
    // Verify burn proof from backend
    verify_burn_proof(&burn_proof)?;

    // Mint element tokens on-chain
    let mint = &ctx.accounts.element_mint;
    mint_to(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            MintTo {
                mint: mint.to_account_info(),
                to: ctx.accounts.governor_token_account.to_account_info(),
                authority: ctx.accounts.mint_authority.to_account_info(),
            },
        ),
        amount,
    )?;

    msg!("Bridged {} {} from in-game to on-chain", amount, element_id);

    Ok(())
}

// Bridge instruction: On-chain → In-game (via treasury)
pub fn bridge_to_ingame(
    ctx: Context<BridgeToIngame>,
    element_id: String,
    amount: u64,
) -> Result<()> {
    // Burn on-chain tokens
    burn(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Burn {
                mint: ctx.accounts.element_mint.to_account_info(),
                from: ctx.accounts.governor_token_account.to_account_info(),
                authority: ctx.accounts.governor.to_account_info(),
            },
        ),
        amount,
    )?;

    // Emit event for backend to credit in-game
    emit!(BridgedToIngame {
        element_id,
        governor: ctx.accounts.governor.key(),
        amount,
    });

    Ok(())
}
```

**Burn Proof Structure:**
```rust
pub struct BurnProof {
    pub element_id: String,
    pub amount: u64,
    pub treasury_balance_before: u64,
    pub treasury_balance_after: u64,
    pub timestamp: i64,
    pub signature: [u8; 64],  // Backend signature
}
```

**Verification:**
- Backend signs burn proof with keypair
- Smart contract verifies signature
- Ensures `treasury_balance_after = treasury_balance_before - amount`
- Prevents double-minting

### Program 3: Marketplace & alSOL Swaps

Handles in-game element → alSOL trades.

```rust
// Swap in-game element for alSOL from treasury
pub fn swap_element_for_alsol(
    ctx: Context<SwapElementForAlsol>,
    element_id: String,
    amount: u64,
) -> Result<()> {
    // Get on-chain price from oracle/DEX
    let price_per_unit = get_element_price(&element_id)?;
    let alsol_to_pay = amount * price_per_unit;

    // Check treasury has enough alSOL
    let treasury = &mut ctx.accounts.treasury;
    require!(treasury.alsol_balance >= alsol_to_pay, ErrorCode::InsufficientTreasuryAlsol);

    // Transfer alSOL to player (in-game, handled by backend)
    treasury.alsol_balance -= alsol_to_pay;
    treasury.balance += amount; // Add element to treasury

    emit!(ElementSwapped {
        player: ctx.accounts.player.key(),
        element_id,
        amount,
        alsol_received: alsol_to_pay,
    });

    Ok(())
}
```

---

## 4. Taxation System

### Tax Collection (10% of yield)

**When:** Before adding to inventory (after processing raw materials or collecting reaction products)

**During Lock Period (30 min after registration):**
```
Player discovers 10 Element_Z
→ Tax: 10% × 10 = 1 unit to treasury
→ Compensation: 2x yield = 10 × 2 = 20 units
→ Player receives: 20 - 1 = 19 units
```

**After Tradeable (lock period over):**
```
Player discovers 10 Element_Z
→ Tax: 10% × 10 = 1 unit to treasury
→ Player receives: 10 - 1 = 9 units
```

**Tax Destination:**
- 100% to **treasury** (not directly to governor)
- Governor manages liquidity via bridge

---

## 5. Unregistered Element Perks

### 10x Isotope Discovery Rate
- **Normal:** 0.1% chance when analyzing materials
- **Unregistered:** 1% chance (10x boost)
- Applied when processing unregistered elements in gloves

### Gloves Multiplication Power
- **Input:** 1 unregistered element + 5 lkC catalyst
- **Output:** 2 unregistered elements
- **Cost:** 2 charge per unit (2x normal)
- **Mechanic:** lkC acts as catalyst, element duplicates

**Example:**
```
Multiply 10 Carbon_X (unregistered)
Cost: 50 lkC + 20 charge
Output: 20 Carbon_X (unregistered)
```

**Once element is registered:**
- Multiplication disabled
- Isotope rate returns to 0.1%
- Unregistered inventory converts to regular

---

## 6. Governor Responsibilities

### Money Manager (Primary Governor)
- **Manages treasury liquidity**
- **Bridges elements:** In-game treasury → On-chain DEX
- **Sells on DEX:** Element tokens → SOL → alSOL
- **Refills treasury:** Sends alSOL back to in-game treasury
- **Revenue:** 100% of tax (co-governor receives nothing currently)

**Liquidity Management Flow:**
```
1. Treasury accumulates 100 Element_Z from tax
2. Governor initiates bridge: Burns 100 Element_Z in-game
3. Smart contract mints 100 Element_Z tokens on-chain
4. Governor sells 100 Element_Z on Raydium for 0.5 SOL
5. Governor swaps 0.5 SOL → 0.5 alSOL
6. Governor sends 0.5 alSOL to treasury (in-game)
7. Treasury now has: 0 Element_Z, 0.5 alSOL
```

**Poor management:**
- Over-supply → Price drops → Market cap shrinks
- Under-supply → High prices but players can't buy

### Element School Master (Co-Governor)
- **Titular role** (no current powers)
- **Future:** Create quests, write lore, curate marketplace
- **Revenue:** None currently (may change in future updates)

---

## 7. 30-Minute Lock Period

**Purpose:** Prevents immediate dumping, gives market time to discover element.

**Timeline:**
```
T+0:00   Registration confirmed
         ↓
         Element NOT tradeable on-chain
         Element NOT in wild
         Tax applies with 2x compensation
         ↓
T+30:00  Lock period ends
         ↓
         Element tradeable on DEX
         Element spawns in wild (same rate as isotopes: 0.1%)
         Tax applies with 1x (no compensation)
```

**Wild Spawn Mechanics:**
- Amount spawned = On-chain liquidity / Total LKC in world
- Example: 10,000 Element_Z on-chain, 1M lkC in world → 0.01% spawn rate per lkC collected
- Governor cannot control spawn rate

---

## 8. Implementation Checklist

### Mobile App (Godot)
- [x] Discovery modal with Register/Keep Unregistered choice
- [x] Unregistered element inventory type
- [x] Gloves multiplication for unregistered elements (2x charge cost)
- [x] 10x isotope rate for unregistered elements
- [x] Registration queue system (race condition handling)
- [x] Tax collection logic (10% with 2x compensation during lock)
- [ ] UI for displaying governor status
- [ ] UI for bridge operations (governor only)
- [ ] Global announcements when element is registered
- [ ] Wild spawn mechanics (post-lock period)

### Smart Contracts (Anchor/Rust)
- [ ] Element Registry program
  - [ ] register_element instruction
  - [ ] Co-governor detection (same-slot logic)
  - [ ] Time-lock validation (30 min)
- [ ] Element Treasury program
  - [ ] bridge_to_chain instruction (with burn proof)
  - [ ] bridge_to_ingame instruction (burn on-chain)
  - [ ] Burn proof verification
- [ ] Marketplace program
  - [ ] swap_element_for_alsol instruction
  - [ ] On-chain price oracle integration
- [ ] Element Token (SPL Token)
  - [ ] Metaplex metadata standard
  - [ ] Rarity-based NFT traits

### Backend Services
- [ ] Registration queue management
- [ ] Burn proof signing service
- [ ] Event listener (ElementRegistered, BridgedToIngame)
- [ ] Global announcement system
- [ ] Wild spawn distribution logic
- [ ] Treasury balance tracking

---

## 9. Security Considerations

### Proof-of-Burn System
- **Purpose:** Prevent double-minting when bridging in-game → on-chain
- **Method:** Backend signs burn proof, smart contract verifies
- **Attack Prevention:**
  - Replay attacks: Include timestamp + nonce
  - Balance manipulation: Verify before/after treasury balance
  - Signature forgery: Use keypair only backend controls

### Registration Race Conditions
- **Same-slot detection:** Use `Clock::get()?.slot` to detect simultaneous transactions
- **Refund logic:** If element already registered and not same-slot, refund payment
- **Co-governor limits:** Maximum 2 governors per element

### Tax Evasion Prevention
- **Tax collection:** Happens BEFORE adding to inventory (not after withdrawal)
- **On-chain verification:** All element creations tracked in smart contract
- **Cannot bypass:** Tax applied at source (nuclear reaction completion)

---

## 10. Economic Simulation

### Example: Element_Z Discovery Timeline

```
Day 1, 00:00: Player A discovers Element_Z
              → Chooses "Keep Unregistered"
              → Farms with 10x isotope rate (1%)
              → Multiplies: 1 → 2 → 4 → 8 → 16 units

Day 3, 12:00: Player B discovers Element_Z
              → Sees Player A's inventory: "Unregistered Element (16)"
              → Races to register
              → Pays 10 alSOL
              → Becomes Governor

Day 3, 12:01: Player A's 16 units convert to registered
              → Perks lost (no more 10x isotope, no multiply)
              → Player B earns 10% tax on all future discoveries

Day 3, 12:30: Lock period ends
              → Element_Z tradeable on Raydium
              → Spawns in wild at 0.1% rate
              → Normal economy begins
```

**Outcome:**
- Player A: 16 units farmed with perks (3.5 days of advantage)
- Player B: Governor status, long-term tax revenue
- Trade-off: Short-term farming vs. long-term governance

---

## 11. Future Enhancements

### Element School Master Powers
- Create element-specific quests
- Write educational lore about chemistry
- Vote on tax rate adjustments (within bounds: 5%-15%)
- Curate marketplace listings for quality

### Dynamic Tax Rates
- Starts at 10%
- Decreases over time:
  - Week 1: 10%
  - Month 1: 5%
  - Permanent: 2%
- Prevents governors from infinite rent extraction

### Cross-Chain Expansion
- Sui Planet: Water-based (lkH) elements
- Base Planet: Silicon-based (lkSi) elements
- Cross-chain bridge for element trading

---

## Conclusion

This system creates a **prisoner's dilemma** where players must choose:

1. **Register immediately:** Secure governorship, earn perpetual tax
2. **Farm unregistered:** 10x isotope advantage, stockpile before registration

The design ensures:
- **Scarcity:** 0.1% isotope × <10% nuclear = 0.01% discovery rate
- **Skill > Money:** Isotopes cannot be purchased, time investment required
- **Active management:** Governors aren't passive rent-collectors
- **Emergent gameplay:** Information warfare, timing, strategy

Players from the outside see a simple choice: "Register or farm?" But beneath lies a complex economic system balancing governance, liquidity, and discovery incentives.

---

**End of Document**

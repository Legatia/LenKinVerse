# 🚀 ReAgenyx Solana Contracts - Devnet Deployment Checklist

**Date:** November 25, 2025
**Cluster:** Devnet
**Wallet Balance:** 12.94 SOL (sufficient for deployment)

---

## 📋 Current Status

### ✅ What's Ready to Deploy (4 Programs)

| Program | Status | Lines | Purpose |
|---------|--------|-------|---------|
| **element_token_factory** | ✅ Ready | 342 | Create SPL tokens for elements |
| **item_marketplace** | ✅ Ready | 392 | NFT marketplace for items |
| **price_oracle** | ✅ Ready | 297 | LKC/SOL price oracle |
| **treasury_bridge** | ✅ Ready | 432 | Bridge in-game ↔ on-chain |

**Total:** 4 programs, ~1,463 lines of Rust code

### ❌ What's NOT Implemented (Removed from Scope)

| Feature | Status | Reason |
|---------|--------|--------|
| alSOL SPL Token | ❌ Not needed | Using database-only architecture |
| alSOL Marketplace | ❌ Not needed | Backend handles marketplace |
| Discovery NFT Registry | 🟡 Optional | Can be added later |

---

## 🔧 Pre-Deployment Tasks

### 1. ✅ Build Status
```bash
cd solana-contracts
anchor build
```
**Status:** ✅ Builds successfully with warnings (non-critical)

### 2. 🟡 Update Program IDs

**Current Mismatch:**
- Anchor.toml has old program IDs
- `anchor keys list` shows new program IDs
- Need to sync them

**Fix:**
```bash
# Update Anchor.toml with current program IDs
anchor keys list
# Then manually update [programs.devnet] section
```

**Current Program IDs (from `anchor keys list`):**
```toml
[programs.devnet]
element_token_factory = "D32BEf4TnLFBtoM1Z2smXY33MxGLT3HJZBGYNfenF7kA"
item_marketplace = "4HvxXhE94xfP3viSZYWyyeuGJGNUH1oHpNF3cLCvWfvt"
price_oracle = "5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz"
treasury_bridge = "8h1aAT9QtnVB1jZWQ3ZuiLdp2KZkyV3xUJQUxSVsQ9Bb"
```

**Old Program IDs (in Anchor.toml):**
```toml
[programs.devnet]
element_token_factory = "DFEdDQp4Ybv1LRtM6EHu8Nxwt1Bvpo6maFJFBkGj5WTQ"  # OLD
item_marketplace = "F7TehQFrx3XkuMsLPcmKLz44UxTWWfyodNLSungdqoRX"   # OLD
price_oracle = "DdRY1fU4938imQBQSEkxLzZyZcD9hBbAJBT3YfWMqPe3"        # OLD
treasury_bridge = "BrdgPYm3GvXFTEHhgN2YXg5WqV9gLBYL7hdYbkBhxA1"       # OLD
```

### 3. ⬜ Write Basic Tests

Need to add tests for:
- Element token registration
- Item NFT minting
- Price oracle updates
- Treasury bridge operations

**Test File Locations:**
- `tests/element_token_factory.ts`
- `tests/item_marketplace.ts`
- `tests/price_oracle.ts`
- `tests/treasury_bridge.ts`

### 4. ⬜ Deployment Script

Create `scripts/deploy.sh`:
```bash
#!/bin/bash
# Deploy all programs to devnet
anchor deploy --provider.cluster devnet

# Verify deployments
anchor verify <program_id> --provider.cluster devnet
```

### 5. ⬜ Post-Deployment Verification

After deployment, verify:
- Programs are deployed to correct addresses
- Program accounts are initialized
- Backend can connect to programs
- Test transactions succeed

---

## 📝 Deployment Steps

### Step 1: Update Program IDs ✅ (Will do now)
```bash
cd solana-contracts
# Copy IDs from `anchor keys list` to Anchor.toml
```

### Step 2: Rebuild with Correct IDs
```bash
anchor build
```

### Step 3: Run Tests (Optional but Recommended)
```bash
anchor test --skip-local-validator
```

### Step 4: Deploy to Devnet
```bash
anchor deploy --provider.cluster devnet
```

**Expected Cost:** ~0.5 SOL (you have 12.94 SOL)

**Deployment Time:** ~2-3 minutes

### Step 5: Verify Deployments
```bash
# Check each program
solana program show D32BEf4TnLFBtoM1Z2smXY33MxGLT3HJZBGYNfenF7kA
solana program show 4HvxXhE94xfP3viSZYWyyeuGJGNUH1oHpNF3cLCvWfvt
solana program show 5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz
solana program show 8h1aAT9QtnVB1jZWQ3ZuiLdp2KZkyV3xUJQUxSVsQ9Bb
```

### Step 6: Initialize Program Accounts

Some programs need initialization:

**Price Oracle:**
```bash
# Initialize oracle account
anchor run initialize-oracle --provider.cluster devnet
```

**Element Token Factory:**
```bash
# Register first element (lkC)
anchor run register-element --provider.cluster devnet -- lkC
```

### Step 7: Update Backend Configuration

Update backend to use deployed program addresses:

**File:** `backend/src/config/solana.ts` (create if doesn't exist)
```typescript
export const SOLANA_CONFIG = {
  cluster: 'devnet',
  programs: {
    element_token_factory: 'D32BEf4TnLFBtoM1Z2smXY33MxGLT3HJZBGYNfenF7kA',
    item_marketplace: '4HvxXhE94xfP3viSZYWyyeuGJGNUH1oHpNF3cLCvWfvt',
    price_oracle: '5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz',
    treasury_bridge: '8h1aAT9QtnVB1jZWQ3ZuiLdp2KZkyV3xUJQUxSVsQ9Bb',
  }
};
```

### Step 8: Test Integration

Test backend → Solana integration:
```bash
cd backend
# Test price oracle update
curl -X POST http://localhost:3000/api/oracle/update-price \
  -d '{"lkc_sol_price": 0.00001}'

# Test element registration
curl -X POST http://localhost:3000/api/elements/register \
  -d '{"element_id": "lkC", "governor": "YOUR_WALLET"}'
```

---

## 🔍 What Each Program Does

### 1. Element Token Factory
**Purpose:** Create SPL tokens for elements (lkC, lkO, lkH, lkCa)

**Key Features:**
- Register new elements as SPL tokens
- 10 SOL registration fee
- Governor/co-governor system (70%/30% split)
- 30-minute lock period after registration
- Market making ratio configuration

**Instructions:**
```rust
pub fn register_element(...)
pub fn deposit_to_treasury(...)
pub fn withdraw_from_treasury(...)
pub fn set_market_making_ratio(...)
```

**Use Case:**
- Player discovers new element in-game
- Backend calls register_element
- Creates SPL token mint on Solana
- Governor gets 70% of initial supply

### 2. Item Marketplace
**Purpose:** Mint and trade in-game items as NFTs

**Key Features:**
- Mint items (gloves, isotopes) as NFTs
- List items for sale with SOL
- Buy items from listings
- Update/cancel listings

**Instructions:**
```rust
pub fn mint_item_nft(...)
pub fn list_item(...)
pub fn buy_item(...)
pub fn update_listing_price(...)
pub fn cancel_listing(...)
```

**Use Case:**
- Player earns Alchemy Gloves in-game
- Backend mints NFT to player wallet
- Player lists NFT for 0.5 SOL
- Another player buys it

### 3. Price Oracle
**Purpose:** Store on-chain LKC/SOL price for fair marketplace rates

**Key Features:**
- Backend-controlled price updates
- 5-minute staleness detection
- Emergency circuit breaker
- Authority management

**Instructions:**
```rust
pub fn initialize_oracle(...)
pub fn update_price(...)
pub fn set_circuit_breaker(...)
pub fn update_authority(...)
```

**Use Case:**
- Backend calculates LKC/SOL rate every 5 minutes
- Updates on-chain oracle
- Marketplace uses price for fair trades
- Prevents stale price exploitation

### 4. Treasury Bridge
**Purpose:** Bridge between in-game database and on-chain SPL tokens

**Key Features:**
- Bridge in-game lkC → on-chain lkC SPL tokens
- Bridge on-chain lkC → in-game lkC
- Backend burn proof verification
- Fee system (3% total: 0.5% governor + 2.5% dev)
- Governors bridge fee-free

**Instructions:**
```rust
pub fn bridge_to_chain(...)     // In-game → On-chain (governor only, no fee)
pub fn bridge_from_chain(...)   // On-chain → In-game (with fees)
pub fn withdraw_fees(...)       // Collect accumulated fees
```

**Use Case:**
- Player has 1000 lkC in-game database
- Wants to provide DEX liquidity
- Bridges to on-chain (pays 3% fee)
- Trades on Raydium/Orca
- Bridges back to game later

---

## ⚠️ Important Notes

### 1. Governor System
- First element registrant = Governor (70% supply)
- Co-governor can register same slot (30% supply)
- Governors control treasury withdrawals
- Governors can bridge fee-free

### 2. Backend Authority
- Backend signs burn proofs for bridge
- Backend updates price oracle
- Backend initiates element registrations
- Keep private keys secure!

### 3. Program Upgrades
- Programs are upgradeable (default Anchor setting)
- Authority = deploying wallet
- Can upgrade via `anchor upgrade`

### 4. Costs
- Deployment: ~0.5 SOL total
- Program rent: ~2-3 SOL per program (one-time)
- Transaction fees: ~0.000005 SOL per tx

---

## ✅ Deployment Checklist

**Before Deployment:**
- [ ] Update program IDs in Anchor.toml
- [ ] Rebuild with `anchor build`
- [ ] Verify wallet balance (need ~3 SOL)
- [ ] Verify Solana CLI points to devnet
- [ ] Backup current program keypairs

**During Deployment:**
- [ ] Run `anchor deploy --provider.cluster devnet`
- [ ] Monitor for errors
- [ ] Save deployment transaction signatures

**After Deployment:**
- [ ] Verify programs with `solana program show`
- [ ] Initialize oracle account
- [ ] Test each program instruction
- [ ] Update backend configuration
- [ ] Test backend integration
- [ ] Document deployed addresses

---

## 🔗 Useful Commands

### Check Deployment Status
```bash
solana program show <PROGRAM_ID>
```

### Get Program Logs
```bash
solana logs <PROGRAM_ID>
```

### Get Account Info
```bash
solana account <ACCOUNT_ADDRESS>
```

### Test Transaction
```bash
anchor run test-element-registration --provider.cluster devnet
```

---

## 📊 Expected Results After Deployment

### Program Accounts
- ✅ 4 programs deployed on devnet
- ✅ Each program has rent-exempt account
- ✅ Program authorities set correctly

### Initialization
- ⬜ Price oracle initialized
- ⬜ At least 1 element registered (lkC)

### Integration
- ⬜ Backend can call all programs
- ⬜ Transactions succeed
- ⬜ Events emitted correctly

---

## 🚀 Ready to Deploy?

**Current Status:**
- ✅ Programs build successfully
- ✅ Wallet has sufficient SOL (12.94 SOL)
- ✅ Cluster configured (devnet)
- 🟡 Program IDs need updating
- ⬜ Tests need writing (optional)

**Next Steps:**
1. Update program IDs in Anchor.toml
2. Rebuild
3. Deploy!

**Estimated Time:** 10-15 minutes

---

**Let's deploy to devnet! 🚀**

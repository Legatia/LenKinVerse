# Price Oracle System

**Program ID:** `DdRY1fU4938imQBQSEkxLzZyZcD9hBbAJBT3YfWMqPe3`

## Overview

The Price Oracle program provides reliable, authority-based price feeds for LKO/SOL and element-specific prices. It's designed for the MVP phase with a simple authority-based model that can later be upgraded to TWAP or Pyth integration.

---

## Features

### 1. LKO/SOL Price Feed
- **Authority-controlled:** Backend keypair updates prices
- **Staleness protection:** Prices older than 5 minutes are rejected
- **Event emission:** All price updates emit events for transparency
- **Emergency pause:** Oracle can be paused in case of issues

### 2. Element-Specific Prices
- **Per-element tracking:** Each registered element can have its own price oracle
- **DEX integration ready:** Supports reading prices from AMM pools
- **Flexible updates:** Backend can update element prices independently

### 3. Security Features
- **Authority validation:** Only authorized keypair can update prices
- **Active status check:** Oracle can be paused/unpaused
- **Transfer authority:** Ownership can be transferred to multisig/DAO

---

## Instructions

### `initialize_oracle`

Initialize the global price oracle (called once on deployment).

**Parameters:**
- `initial_lko_per_sol`: u64 - Initial LKO price per 1 SOL (9 decimals)

**Accounts:**
- `oracle`: PDA `["price_oracle"]` (created)
- `authority`: Signer (backend keypair)
- `system_program`: System Program

**Example:**
```typescript
const tx = await program.methods
  .initializeOracle(new BN(1_000_000_000)) // 1 LKO = 1 SOL
  .accounts({
    oracle: oraclePda,
    authority: backendKeypair.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

---

### `update_price`

Update the LKO/SOL price (called by backend service every 60s or on 1% change).

**Parameters:**
- `new_lko_per_sol`: u64 - New LKO price per 1 SOL (9 decimals)

**Accounts:**
- `oracle`: PDA `["price_oracle"]`
- `authority`: Signer (backend keypair)

**Constraints:**
- Must be signed by oracle authority
- Oracle must be active
- Price must be > 0

**Example:**
```typescript
const tx = await program.methods
  .updatePrice(new BN(1_500_000_000)) // 1.5 LKO = 1 SOL
  .accounts({
    oracle: oraclePda,
    authority: backendKeypair.publicKey,
  })
  .rpc();
```

---

### `update_element_price`

Update element-specific price (for elements with DEX pools).

**Parameters:**
- `element_id`: String - Element identifier (max 32 chars)
- `price_per_sol`: u64 - Element tokens per 1 SOL (9 decimals)

**Accounts:**
- `element_oracle`: PDA `["element_price", element_id]` (created if needed)
- `oracle`: PDA `["price_oracle"]` (for authority check)
- `authority`: Signer (backend keypair)
- `system_program`: System Program

**Example:**
```typescript
const tx = await program.methods
  .updateElementPrice("Carbon_X", new BN(500_000_000)) // 0.5 Carbon_X = 1 SOL
  .accounts({
    elementOracle: elementOraclePda,
    oracle: oraclePda,
    authority: backendKeypair.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();
```

---

### `get_price`

Get current LKO/SOL price with staleness check (view function).

**Returns:** u64 - Current LKO price per SOL

**Accounts:**
- `oracle`: PDA `["price_oracle"]`

**Constraints:**
- Price must be < 5 minutes old
- Oracle must be active

**Example:**
```typescript
const oracleAccount = await program.account.priceOracle.fetch(oraclePda);
const lkoPerSol = oracleAccount.lkoPerSol.toNumber();
console.log(`1 SOL = ${lkoPerSol / 1e9} LKO`);
```

---

### `set_oracle_active`

Pause/unpause the oracle (emergency function).

**Parameters:**
- `is_active`: bool - New active status

**Accounts:**
- `oracle`: PDA `["price_oracle"]`
- `authority`: Signer (backend keypair)

**Example:**
```typescript
// Pause oracle
await program.methods
  .setOracleActive(false)
  .accounts({
    oracle: oraclePda,
    authority: backendKeypair.publicKey,
  })
  .rpc();
```

---

### `transfer_authority`

Transfer oracle authority to new keypair (for upgrading to multisig/DAO).

**Parameters:**
- `new_authority`: Pubkey - New authority public key

**Accounts:**
- `oracle`: PDA `["price_oracle"]`
- `authority`: Signer (current authority)

**Example:**
```typescript
await program.methods
  .transferAuthority(multisigPubkey)
  .accounts({
    oracle: oraclePda,
    authority: currentAuthority.publicKey,
  })
  .rpc();
```

---

## Data Structures

### PriceOracle

```rust
pub struct PriceOracle {
    pub authority: Pubkey,        // Backend keypair (or multisig)
    pub lko_per_sol: u64,          // LKO tokens per 1 SOL (9 decimals)
    pub last_updated: i64,         // Unix timestamp of last update
    pub update_count: u64,         // Total number of updates
    pub is_active: bool,           // Emergency pause flag
}
```

**PDA:** `["price_oracle"]`

### ElementPriceOracle

```rust
pub struct ElementPriceOracle {
    pub element_id: String,        // Element identifier (max 32 chars)
    pub price_per_sol: u64,        // Element tokens per 1 SOL (9 decimals)
    pub last_updated: i64,         // Unix timestamp of last update
    pub update_count: u64,         // Total number of updates
}
```

**PDA:** `["element_price", element_id]`

---

## Events

### OracleInitialized
```rust
pub struct OracleInitialized {
    pub authority: Pubkey,
    pub initial_price: u64,
    pub timestamp: i64,
}
```

### PriceUpdated
```rust
pub struct PriceUpdated {
    pub old_price: u64,
    pub new_price: u64,
    pub timestamp: i64,
    pub update_count: u64,
}
```

### ElementPriceUpdated
```rust
pub struct ElementPriceUpdated {
    pub element_id: String,
    pub price_per_sol: u64,
    pub timestamp: i64,
}
```

### OracleStatusChanged
```rust
pub struct OracleStatusChanged {
    pub is_active: bool,
    pub timestamp: i64,
}
```

### AuthorityTransferred
```rust
pub struct AuthorityTransferred {
    pub old_authority: Pubkey,
    pub new_authority: Pubkey,
    pub timestamp: i64,
}
```

---

## Error Codes

| Code | Message |
|------|---------|
| `Unauthorized` | Only oracle authority can perform this action |
| `InvalidPrice` | Price must be greater than 0 |
| `OracleInactive` | Price updates are paused |
| `PriceStale` | Last update was more than 5 minutes ago |
| `ElementIdTooLong` | Element ID maximum 32 characters |

---

## Backend Integration

### Price Updater Service

The backend service runs continuously and:
1. Monitors LKO price from AMM pool or fixed formula
2. Updates oracle every 60 seconds or when price changes >1%
3. Logs all updates for transparency

**Run the service:**
```bash
cd solana-contracts
ts-node scripts/backend-price-updater.ts
```

**Service output:**
```
🔧 Price Updater Service Initialized
   Authority: 7xKX...abc123
   Oracle PDA: 9YZw...def456
   RPC URL: https://api.devnet.solana.com

🚀 Starting Price Updater Service...

🔄 Checking price...
   Current oracle price: 1000.00 LKO/SOL
   Calculated price: 1015.50 LKO/SOL
💡 Price changed by 1.55% - updating...
✅ Price updated on-chain
   New price: 1015.50 LKO/SOL
   Transaction: 5KQs...xyz789
```

### Price Calculation Options

**Option 1: Fixed Formula (MVP)**
```typescript
const lkoPerSol = 1000 * 1e9; // 1000 LKO = 1 SOL
```

**Option 2: Read from AMM Pool**
```typescript
const poolReserves = await getPoolReserves(raydiumPoolPubkey);
const lkoPerSol = (poolReserves.sol * 1e9) / poolReserves.lko;
```

**Option 3: TWAP from Multiple Pools**
```typescript
const prices = await Promise.all([
  getRadiumPrice(),
  getOrcaPrice(),
]);
const lkoPerSol = prices.reduce((a, b) => a + b) / prices.length;
```

---

## Integration with Other Programs

### Element Token Factory

Element tokens can use the oracle to determine minting costs:

```rust
use crate::price_oracle::PriceOracle;

let oracle = &ctx.accounts.oracle;
let lko_per_sol = oracle.lko_per_sol;

// Calculate registration fee in LKO
let registration_fee_lko = (REGISTRATION_FEE_SOL * lko_per_sol) / 1e9;
```

### Marketplace Swaps

Players can swap in-game elements for alSOL using oracle prices:

```rust
let element_oracle = &ctx.accounts.element_oracle;
let lko_oracle = &ctx.accounts.lko_oracle;

// Get element price in SOL
let element_per_sol = element_oracle.price_per_sol;

// Calculate alSOL to pay
let alsol_amount = (element_amount * element_per_sol) / 1e9;
```

---

## Testing

Run the test suite:

```bash
cd solana-contracts
anchor test -- --grep "price_oracle"
```

**Test coverage:**
- ✅ Initialize oracle
- ✅ Update LKO/SOL price
- ✅ Get current price
- ✅ Update element-specific price
- ✅ Pause/unpause oracle
- ✅ Reject unauthorized updates
- ✅ Staleness protection

---

## Deployment Checklist

### Devnet Deployment

1. **Generate keypair for oracle authority:**
   ```bash
   solana-keygen new -o ~/.config/solana/oracle-authority.json
   ```

2. **Airdrop SOL:**
   ```bash
   solana airdrop 2 $(solana-keygen pubkey ~/.config/solana/oracle-authority.json) --url devnet
   ```

3. **Deploy program:**
   ```bash
   anchor build
   anchor deploy --provider.cluster devnet
   ```

4. **Initialize oracle:**
   ```bash
   anchor run initialize-oracle --provider.cluster devnet
   ```

5. **Start price updater service:**
   ```bash
   AUTHORITY_KEYPAIR=~/.config/solana/oracle-authority.json \
   RPC_URL=https://api.devnet.solana.com \
   ts-node scripts/backend-price-updater.ts
   ```

### Mainnet Deployment

⚠️ **Before mainnet:**

1. **Use multisig for authority:**
   - Create Squads/Realms multisig
   - Transfer oracle authority to multisig
   - Require 2-of-3 or 3-of-5 signatures

2. **Monitor for anomalies:**
   - Set up alerts for large price swings (>10%)
   - Track update frequency (should be ~60s)
   - Monitor authority balance (needs SOL for tx fees)

3. **Backup authority keypair:**
   - Store in hardware security module (HSM)
   - Or use KMS (AWS KMS, Google Cloud KMS)

4. **Consider upgrade path:**
   - Plan migration to TWAP oracle
   - Or integrate with Pyth/Switchboard
   - Keep authority-based as fallback

---

## Upgrade Path

### Phase 1: Authority-Based (Current)
- Backend updates prices manually
- Simple, fast, controlled

### Phase 2: Hybrid (Future)
- Backend updates prices
- Smart contract validates against DEX bounds (±5%)
- Best of both worlds

### Phase 3: Fully Decentralized (Long-term)
- TWAP from multiple DEX pools
- Anyone can call update (permissionless)
- Or integrate Pyth/Switchboard oracle

**Migration:**
```rust
// Add TWAP validation to update_price
pub fn update_price_twap_validated(
    ctx: Context<UpdatePrice>,
    new_price: u64,
) -> Result<()> {
    // Get DEX TWAP
    let twap = get_twap_price(&ctx.accounts.pool)?;

    // Ensure within ±5% of TWAP
    require!(
        new_price >= twap * 95 / 100 && new_price <= twap * 105 / 100,
        ErrorCode::PriceOutOfBounds
    );

    // Update as normal
    update_price_internal(ctx, new_price)
}
```

---

## FAQ

**Q: Why not use Pyth or Switchboard?**
A: For MVP, we only need LKO/SOL price which doesn't exist on external oracles yet. Once LKO has DEX liquidity, we can migrate to TWAP or external oracles.

**Q: Is authority-based oracle secure?**
A: For bootstrap phase, yes. Authority keypair should be secured in HSM/KMS. For production, upgrade to multisig or TWAP validation.

**Q: How often should prices be updated?**
A: Every 60 seconds or when price changes >1%. This balances freshness with transaction costs.

**Q: What if backend goes offline?**
A: Oracle has 5-minute staleness protection. If backend is down >5 minutes, programs using the oracle will reject stale prices. Set up monitoring/alerts.

**Q: Can element prices be different from LKO price?**
A: Yes! Each element can have its own price oracle based on its DEX pool. LKO price is just the base reference.

---

**Built with ❤️ for LenKinVerse**

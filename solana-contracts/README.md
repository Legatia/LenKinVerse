# LenKinVerse Solana Smart Contracts

Solana smart contracts for LenKinVerse - a Web3 mobile game combining chemistry education with blockchain.

## 🎯 Main Features

### 1. Element Token Factory
**Mints fungible SPL tokens when new elements are discovered**

- Players discover new elements through nuclear reactions (0.1% chance)
- First discoverer becomes "Governor" and registers element as SPL token
- **30-minute lock period** before token becomes tradeable on DEX
- Each element has its own mint with Metaplex metadata
- Supports 4 rarity levels: Common (0), Uncommon (1), Rare (2), Legendary (3)

### 2. In-Game Item NFT Marketplace
**P2P trading of in-game items (gloves, isotopes, etc.) as NFTs**

- Backend mints items as NFTs (supply = 1) when earned in-game
- Players list NFTs for sale (SOL price)
- Escrow system protects both buyer and seller
- 5% royalty to original creator
- Cancel listing at any time

---

## 📦 Programs

### `element_token_factory`

**Program ID:** `DFEdDQp4Ybv1LRtM6EHu8Nxwt1Bvpo6maFJFBkGj5WTQ`

#### Instructions:

1. **`register_element`** ⭐ NEW: Payment + Co-Governor
   - Creates new element as fungible SPL token
   - **Requires 10 SOL payment** to protocol treasury
   - **Supports co-governor** (same-slot detection)
   - Sets 30-minute lock period
   - Creates Metaplex metadata
   - **Params:**
     - `element_id`: String (max 32 chars)
     - `rarity`: u8 (0-3)
     - `uri`: String (Arweave/IPFS metadata link)

2. **`mint_element_tokens`** ⭐ NEW: Tax Collection
   - Mints element tokens to player after in-game discovery
   - **10% tax to governor treasury**
   - **2x yield during lock period** (compensation)
   - **1x yield after tradeable**
   - Called by backend after verifying discovery
   - **Params:**
     - `element_id`: String
     - `raw_amount`: u64 (amount before tax/compensation)

3. **`mark_tradeable`**
   - Marks element as tradeable after 30-min lock
   - Anyone can call once lock expires
   - **Params:**
     - `element_id`: String

4. **`get_element_info`** ⭐ NEW: View Function
   - Query element data (treasury balance, governor, etc.)
   - **Params:**
     - `element_id`: String

#### Accounts:

- **`ElementRegistry`**: Global registry storing all elements (PDA: `["element_registry"]`)
- **`ElementMint`**: SPL token mint for each element (PDA: `["element_mint", element_id]`)
- **`TreasuryTokenAccount`**: Governor treasury (PDA: `["element_treasury", element_id]`) ⭐ NEW
- **`ProtocolTreasury`**: Registration fees (PDA: `["protocol_treasury"]`) ⭐ NEW

#### ElementData Structure:
```rust
pub struct ElementData {
    pub element_id: String,
    pub mint: Pubkey,
    pub governor: Pubkey,
    pub co_governor: Option<Pubkey>,     // ⭐ NEW
    pub registered_at: i64,
    pub registration_slot: u64,          // ⭐ NEW (for co-governor detection)
    pub tradeable_at: i64,
    pub is_tradeable: bool,
    pub rarity: u8,
    pub total_minted: u64,
    pub treasury_balance: u64,           // ⭐ NEW (10% tax collected)
    pub total_taxed: u64,                // ⭐ NEW (cumulative)
    pub treasury_token_account: Pubkey,  // ⭐ NEW
}
```

---

### `item_marketplace`

**Program ID:** `F7TehQFrx3XkuMsLPcmKLz44UxTWWfyodNLSungdqoRX`

#### Instructions:

1. **`mint_item_nft`**
   - Mints in-game item as NFT
   - Called by backend when player earns item
   - **Params:**
     - `item_type`: String (e.g., "Gloves")
     - `item_level`: u8
     - `item_attributes`: String (JSON attributes)
     - `uri`: String (metadata link)

2. **`list_item`**
   - Lists NFT for sale on marketplace
   - Transfers NFT to escrow
   - **Params:**
     - `price`: u64 (in lamports)

3. **`buy_item`**
   - Purchases listed NFT
   - Transfers SOL to seller
   - Transfers NFT to buyer

4. **`cancel_listing`**
   - Cancels listing and returns NFT to seller
   - Only seller can cancel

#### Accounts:

- **`Listing`**: Marketplace listing (PDA: `["listing", seller, item_mint]`)
- **`ItemMint`**: NFT mint (PDA: `["item_mint", owner, item_id]`)

---

## 🚀 Getting Started

### Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# Install Yarn
npm install -g yarn
```

### Build

```bash
cd solana-contracts

# Build programs
anchor build

# Run tests
anchor test

# Deploy to devnet
anchor deploy --provider.cluster devnet
```

---

### `treasury_bridge` ⭐ NEW

**Program ID:** `BrdgPYm3GvXFTEHhgN2YXg5WqV9gLBYL7hdYbkBhxA1`

#### Instructions:

1. **`bridge_to_chain`**
   - Bridge treasury tokens to on-chain (for DEX liquidity)
   - Only governor can bridge
   - Requires burn proof signature from backend
   - **Params:**
     - `element_id`: String
     - `amount`: u64
     - `burn_proof_signature`: [u8; 64]

2. **`bridge_to_ingame`**
   - Bridge on-chain tokens back to in-game
   - Burns SPL tokens, backend credits in-game
   - **Params:**
     - `element_id`: String
     - `amount`: u64

3. **`get_bridge_history`**
   - Query historical bridge transactions
   - **Params:**
     - `element_id`: String

#### Accounts:

- **`BridgeRecord`**: Transaction record (PDA: `["bridge_record", element_id, governor, timestamp]`)

#### Bridge Flow:
```
To Chain:  In-game tokens → Backend signs burn proof → SPL tokens to governor
To Ingame: Governor burns SPL → Backend credits in-game treasury
```

---

## 🧪 Testing

### Element Token Factory Test

```bash
anchor test --skip-deploy -- --grep "element-token-factory"
```

**Tests:**
- ✅ Register new element
- ✅ Mint tokens to player
- ✅ Mark element as tradeable
- ✅ Reject duplicate registration

### Item Marketplace Test

```bash
anchor test --skip-deploy -- --grep "item-marketplace"
```

**Tests:**
- ✅ Mint item NFT
- ✅ List item for sale
- ✅ Buy listed item
- ✅ Cancel listing

---

## 📋 Deployment Checklist

### Devnet Deployment

1. **Generate new keypairs** (if needed):
   ```bash
   solana-keygen new -o ~/.config/solana/devnet-deployer.json
   ```

2. **Airdrop SOL**:
   ```bash
   solana airdrop 2 --url devnet
   ```

3. **Update program IDs** in `Anchor.toml` and `lib.rs` (use `anchor keys list`)

4. **Build and deploy**:
   ```bash
   anchor build
   anchor deploy --provider.cluster devnet
   ```

5. **Verify deployment**:
   ```bash
   solana program show <PROGRAM_ID> --url devnet
   ```

### Mainnet Deployment

⚠️ **Before deploying to mainnet:**

1. **Security audit** - Get programs audited by reputable firm
2. **Upgrade authority** - Consider using multisig or DAO
3. **Program upgrade** - Test upgrade process on devnet
4. **Insurance fund** - Set aside SOL for potential bugs
5. **Monitoring** - Set up alerts for unusual activity

---

## 🔗 Integration with Mobile App

### Backend Service Flow

#### Element Registration:
```typescript
// When player discovers new element in-game
1. Mobile app → Backend: "Player discovered Element_Z"
2. Backend verifies discovery
3. Backend → Solana: Call register_element()
4. Backend → Mobile: Confirmation + mint address
5. Mobile app shows registration modal
```

#### Element Minting:
```typescript
// When player creates element via nuclear reaction
1. Mobile app → Backend: "Player created 10 Carbon_X"
2. Backend verifies creation
3. Backend → Solana: Call mint_element_tokens(Carbon_X, 10e6)
4. Backend → Mobile: Confirmation
5. Mobile app updates balance
```

#### NFT Marketplace:
```typescript
// When player earns gloves Lv.5
1. Mobile app → Backend: "Player leveled gloves to 5"
2. Backend → Solana: Call mint_item_nft()
3. Backend → Mobile: NFT mint address
4. Player can list/trade via marketplace UI
```

---

## 📊 Economics

### Element Tokens

- **Decimals**: 6 (like USDC)
- **Supply**: Unlimited (minted on discovery)
- **Registration Fee**: 10 SOL (to protocol treasury) ⭐ NEW
- **Tax Rate**: 10% to governor treasury ⭐ NEW
- **Lock Period**: 30 minutes after registration
- **Lock Compensation**: 2x yield during lock ⭐ NEW
- **Tradeability**: Becomes tradeable on DEX after lock
- **Use Case**: Trade on-chain, bridge back to game

### Governor Economics ⭐ NEW

**Revenue Model:**
- **Registration Cost**: 10 SOL upfront
- **Tax Income**: 10% of all element discoveries (forever)
- **Break-even**: ~100 discoveries (depends on element popularity)
- **Liquidity Management**: Can bridge treasury to/from DEX

**Example:**
```
Element: Carbon_X
Governor: Alice (paid 10 SOL to register)

Players discover 1,000 Carbon_X total:
- During lock (first 30 min): 2x yield - 10% = 1.9x net
  - 500 discoveries × 2 = 1,000 to players
  - 500 discoveries × 0.1 = 50 to Alice's treasury

- After tradeable: 1x yield - 10% = 0.9x net
  - 500 discoveries × 1 = 500 to players
  - 500 discoveries × 0.1 = 50 to Alice's treasury

Alice's total: 100 Carbon_X in treasury
Alice can: Bridge to DEX, provide liquidity, earn trading fees
```

**Co-Governor:** ⭐ NEW
- Assigned if registered in same blockchain slot
- Role: Element School Master (titular)
- Revenue: None (for now, future quests/lore features)

### Item NFTs

- **Supply**: 1 (true NFT)
- **Royalty**: 5% to original creator
- **Marketplace Fee**: 0% (P2P direct)
- **Currency**: SOL
- **Use Case**: Sell/trade rare gloves, isotopes

---

## 🛠️ Development Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Element Token Factory
- [x] Item NFT Marketplace
- [x] Basic tests

### Phase 2: Advanced Features ✅
- [x] Treasury & Bridge program
- [x] Tax collection (10% to governor)
- [x] Payment enforcement (10 SOL registration)
- [x] Co-governor system (same-slot detection)
- [x] Treasury balance tracking

### Phase 3: Production Ready (Current)
- [ ] Security audit
- [ ] Mainnet deployment
- [ ] Backend integration
- [ ] Mobile app integration

---

## 📜 License

MIT

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

---

## 📞 Support

- **Documentation**: [LenKinVerse Docs](../ELEMENT_TOKEN_FLOW.md)
- **Issues**: [GitHub Issues](https://github.com/yourorg/lenkinverse)
- **Discord**: [Join our community](#)

---

**Built with ❤️ using Anchor Framework**

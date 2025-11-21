# LenKinVerse Solana On-Chain Architecture

## Overview

This document outlines the on-chain components needed for LenKinVerse, a blockchain-based alchemy game on Solana.

## Core Concept

**Off-Chain:** Movement tracking, element collection, analysis, reactions (Godot game)
**On-Chain:** Element ownership, marketplace, NFT minting, trading, verification

---

## On-Chain Requirements

### 1. **Element NFT Program** 🧪

Elements and isotopes discovered in-game can be minted as NFTs for trading.

#### Features:
- **Mint Elements as NFTs** - Players can mint discovered elements (lkC, lkO, etc.)
- **Mint Isotopes as Rare NFTs** - Rare isotopes (C14, etc.) with special attributes
- **Metadata Standards** - Follow Metaplex standards for compatibility
- **Attributes:**
  - Element name and symbol
  - Rarity tier
  - Discovery timestamp
  - Decay timer (for isotopes)
  - Generation method (collected, reacted, etc.)

#### Technical Requirements:
```rust
pub struct ElementNFT {
    pub owner: Pubkey,
    pub mint: Pubkey,
    pub element_id: String,        // "lkC", "C14", etc.
    pub element_name: String,      // "Carbon", "Carbon-14"
    pub rarity: u8,                // 0=common, 1=uncommon, 2=rare, 3=legendary
    pub amount: u64,               // Quantity in this NFT
    pub discovered_at: i64,        // Unix timestamp
    pub decay_time: Option<i64>,   // For isotopes
    pub generation_method: String, // "collected", "analyzed", "physical_reaction", etc.
}
```

---

### 2. **Marketplace Program** 🏪

Decentralized marketplace for trading elements and isotopes.

#### Features:
- **List Elements for Sale** - Players set price in SOL or custom token
- **Buy Elements** - Direct purchase from listings
- **Escrow System** - Safe atomic swaps
- **Price Discovery** - Track floor prices and trading volumes
- **Fee Structure** - Platform fee (e.g., 2.5%) on trades

#### Technical Requirements:
```rust
pub struct Listing {
    pub seller: Pubkey,
    pub nft_mint: Pubkey,
    pub price: u64,              // In lamports
    pub currency: Pubkey,        // SOL or SPL token
    pub listed_at: i64,
    pub is_active: bool,
}

pub struct Escrow {
    pub buyer: Pubkey,
    pub seller: Pubkey,
    pub nft_mint: Pubkey,
    pub price: u64,
    pub escrow_account: Pubkey,
}
```

#### Instructions:
- `create_listing` - List NFT for sale
- `cancel_listing` - Remove listing
- `buy_nft` - Purchase listed NFT
- `update_price` - Change listing price

---

### 3. **Element Registry Program** 📖

Central registry of all discoverable elements and their properties.

#### Features:
- **Element Definitions** - On-chain database of all elements
- **Rarity Tables** - Define drop rates and rarity
- **Reaction Formulas** - Store valid reaction combinations
- **Verification** - Validate game-generated elements

#### Technical Requirements:
```rust
pub struct ElementDefinition {
    pub element_id: String,
    pub name: String,
    pub symbol: String,
    pub atomic_number: u8,
    pub rarity: u8,
    pub is_mintable: bool,
    pub mint_cost: u64,        // Cost to mint as NFT
}

pub struct ReactionFormula {
    pub formula_id: String,
    pub reactants: Vec<String>,     // ["lkC", "lkO"]
    pub products: Vec<String>,      // ["CO2"]
    pub reaction_type: String,      // "physical", "chemical", "nuclear"
    pub success_rate: u8,
}
```

---

### 4. **Player Profile Program** 👤

On-chain player profiles and achievements.

#### Features:
- **Player Stats** - Store verifiable game statistics
- **Achievement NFTs** - Mint achievement badges
- **Leaderboards** - Global rankings
- **Reputation System** - Trading reputation

#### Technical Requirements:
```rust
pub struct PlayerProfile {
    pub wallet: Pubkey,
    pub username: String,
    pub total_analyses: u64,
    pub total_reactions: u64,
    pub isotopes_discovered: u8,
    pub elements_minted: u64,
    pub trades_completed: u64,
    pub reputation_score: u16,
    pub created_at: i64,
}

pub struct Achievement {
    pub achievement_id: String,
    pub name: String,
    pub description: String,
    pub rarity: u8,
    pub unlocked_at: i64,
}
```

---

### 5. **Staking Program** 🔐 (Optional)

Stake elements for rewards or special abilities.

#### Features:
- **Stake Elements** - Lock elements for period
- **Earn Rewards** - Get bonus collection rate or special reactions
- **Unstake** - Retrieve staked elements
- **Decay Protection** - Staked isotopes don't decay

#### Technical Requirements:
```rust
pub struct StakingPool {
    pub pool_id: String,
    pub reward_rate: u64,      // Per epoch
    pub lock_period: i64,      // Seconds
    pub total_staked: u64,
}

pub struct StakeAccount {
    pub owner: Pubkey,
    pub nft_mint: Pubkey,
    pub staked_at: i64,
    pub unlock_at: i64,
    pub rewards_earned: u64,
}
```

---

## Program Architecture

### Program Organization
```
solana-program/
├── programs/
│   ├── element-nft/          # NFT minting and management
│   ├── marketplace/          # Trading and listings
│   ├── registry/             # Element definitions
│   ├── player-profile/       # Player stats and achievements
│   └── staking/              # Staking (optional)
├── tests/
├── migrations/
└── Anchor.toml
```

### Technology Stack
- **Framework:** Anchor (recommended) or native Rust
- **Token Standard:** Metaplex Token Metadata
- **Testing:** Solana Test Validator + Anchor tests
- **Deployment:** Mainnet-beta, Devnet for testing

---

## Data Flow

### Minting Flow:
1. Player discovers element in game (off-chain)
2. Player requests mint via mobile app
3. App calls `mint_element` instruction
4. Program verifies element is valid (check registry)
5. Metaplex creates NFT with metadata
6. NFT transferred to player's wallet
7. Game state updated

### Trading Flow:
1. Player lists element on marketplace (on-chain)
2. Buyer browses listings (query on-chain data)
3. Buyer purchases (triggers escrow)
4. Atomic swap executes
5. NFT transferred, payment released
6. Both wallets updated

---

## Security Considerations

### 1. **Anti-Cheat Measures**
- **Server Validation:** Backend verifies game state before allowing mints
- **Rate Limiting:** Maximum mints per day per wallet
- **Element Verification:** Check against registry for valid elements
- **Signature Verification:** Require server signature for sensitive operations

### 2. **Escrow Safety**
- **PDA Escrow Accounts:** Use Program Derived Addresses
- **Atomic Swaps:** All-or-nothing transfers
- **Time Locks:** Automatic refund after expiry
- **Anti-Rugpull:** Seller can't withdraw once escrowed

### 3. **Access Control**
- **Owner-Only Operations:** Profile updates, listing cancellations
- **Admin Functions:** Registry updates (multisig)
- **Upgrade Authority:** Careful key management

---

## Token Economics (Optional)

If implementing a game token ($LKC):

### Token Model:
- **Total Supply:** Fixed (e.g., 1 billion)
- **Distribution:**
  - 40% - Player rewards (vesting)
  - 30% - Treasury
  - 20% - Team (vesting)
  - 10% - Initial liquidity

### Use Cases:
- Mint elements (pay in $LKC)
- Marketplace currency
- Staking rewards
- Governance (future)

---

## Development Roadmap

### Phase 1: Core Infrastructure (4-6 weeks)
- [ ] Element NFT program
- [ ] Basic marketplace (list/buy)
- [ ] Element registry
- [ ] Metaplex integration
- [ ] Local testing

### Phase 2: Enhanced Features (4-6 weeks)
- [ ] Player profiles
- [ ] Achievement system
- [ ] Advanced marketplace (offers, auctions)
- [ ] Escrow improvements
- [ ] Devnet deployment

### Phase 3: Polish & Launch (2-4 weeks)
- [ ] Security audit
- [ ] Stress testing
- [ ] Integration with mobile app
- [ ] Mainnet deployment
- [ ] Monitoring & analytics

### Phase 4: Advanced Features (Future)
- [ ] Staking program
- [ ] DAO governance
- [ ] Cross-chain bridges
- [ ] Seasonal events

---

## Integration with Mobile Game

### SDK Requirements:
- **Solana Mobile Wallet Adapter** - Sign transactions
- **Anchor/Web3.js** - Interact with programs
- **Metaplex SDK** - NFT operations
- **RPC Connection** - Communicate with Solana network

### Mobile App Responsibilities:
1. Wallet connection
2. Transaction creation
3. Signing requests
4. Display NFT inventory
5. Browse marketplace
6. Initiate trades

### On-Chain Program Responsibilities:
1. Validate operations
2. Maintain state
3. Execute transfers
4. Enforce rules
5. Emit events

---

## Cost Estimates

### Development Costs:
- Account rent: ~0.00203928 SOL per account
- Transaction fees: ~0.000005 SOL per transaction
- NFT minting: ~0.01 SOL (includes metadata account)

### Operational Costs:
- RPC provider: Free tier (Alchemy/QuickNode) or self-hosted
- Storage: Accounts need rent-exempt balance
- Upgrades: Small SOL for deployment

---

## Testing Strategy

### Unit Tests:
- Test each instruction individually
- Mock accounts and signers
- Edge cases and error conditions

### Integration Tests:
- Full program flows (mint → list → buy)
- Multiple programs interacting
- State consistency

### Devnet Testing:
- Real wallet integration
- Mobile app testing
- Transaction simulation
- Performance testing

---

## Deployment Checklist

- [ ] Code review completed
- [ ] Security audit (if budget allows)
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Devnet testing successful
- [ ] Upgrade authority secured (multisig)
- [ ] Monitoring setup
- [ ] Rollback plan
- [ ] Community announcement

---

## Resources

- [Anchor Book](https://book.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Metaplex Docs](https://docs.metaplex.com/)
- [Solana Program Library](https://spl.solana.com/)

---

## Next Steps

1. **Choose Framework:** Decide on Anchor vs native Rust
2. **Setup Project:** Initialize Anchor project
3. **Start with Element NFT:** Build core minting functionality
4. **Iterate:** Add marketplace, registry, etc.
5. **Test Extensively:** Devnet before mainnet

---

## Contact

For questions or collaboration:
- GitHub: [repository]
- Discord: [server]
- Email: dev@lenkinverse.com

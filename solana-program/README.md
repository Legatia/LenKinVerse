# LenKinVerse Solana Programs

On-chain smart contracts for LenKinVerse - a blockchain-based alchemy game.

## 📁 Project Structure

```
solana-program/
├── programs/
│   ├── element-nft/     # NFT minting for elements and isotopes
│   ├── marketplace/     # Decentralized trading marketplace
│   └── registry/        # Element definitions and formulas
├── tests/              # Integration tests
├── migrations/         # Deployment scripts
├── Anchor.toml        # Anchor configuration
├── Cargo.toml         # Rust workspace
└── ONCHAIN_REQUIREMENTS.md  # Detailed requirements
```

## 🎯 Programs

### 1. Element NFT Program
Handles minting, updating, and burning of element NFTs.

**Features:**
- Mint elements as NFTs with metadata
- Track rarity, amount, discovery timestamp
- Support for isotopes with decay timers
- Burn/combine functionality

**Program ID:** `ELeMNFTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 2. Marketplace Program
Decentralized marketplace for trading elements using alSOL currency.

**Features:**
- List elements for sale (priced in alSOL)
- Buy elements with alSOL tokens
- Escrow system for safe trades
- Cancel listings
- Price updates
- **Swap SOL for alSOL (1:1 ratio)**
- **Swap LKC for alSOL (1M:1 ratio)**
- alSOL token integration (1:1 backed by SOL)

**Program ID:** `MKTPLCExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
**Currency:** alSOL (Alchemy SOL) - See [ALSOL_TOKEN.md](./ALSOL_TOKEN.md)

### 3. Registry Program
Central registry of element definitions and reaction formulas.

**Features:**
- Store element properties on-chain
- Validate elements before minting
- Track reaction formulas
- Admin-controlled updates

**Program ID:** `REGSTRYxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 🚀 Getting Started

### Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/v1.17.0/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest
```

### Build

```bash
# Build all programs
anchor build

# Build specific program
cd programs/element-nft && cargo build-bpf
```

### Test

```bash
# Run all tests
anchor test

# Run specific test file
anchor test tests/element-nft.ts

# Test on devnet
anchor test --provider.cluster devnet
```

### Deploy

```bash
# Deploy to localnet
anchor deploy

# Deploy to devnet
anchor deploy --provider.cluster devnet

# Deploy to mainnet
anchor deploy --provider.cluster mainnet
```

## 📝 Program Instructions

### Element NFT

```typescript
// Mint element
await program.methods
  .mintElement(
    "lkC",           // element_id
    "Carbon",        // element_name
    "C",            // symbol
    0,              // rarity (common)
    100,            // amount
    "collected",    // generation_method
    null            // decay_time (none)
  )
  .accounts({...})
  .rpc();

// Update amount
await program.methods
  .updateAmount(new BN(200))
  .accounts({...})
  .rpc();

// Burn element
await program.methods
  .burnElement()
  .accounts({...})
  .rpc();
```

### Marketplace

**Note:** All marketplace transactions use alSOL (in-game currency) backed 1:1 by SOL. See [ALSOL_TOKEN.md](./ALSOL_TOKEN.md) for details.

```typescript
// Create alSOL mint address (deploy once)
const ALSOL_MINT = new PublicKey("...");

// List element for sale
await marketplace.methods
  .createListing(
    new BN(5_000_000_000) // 5 alSOL (with 9 decimals)
  )
  .accounts({
    listingAccount: listingPda,
    elementAccount: elementPda,
    elementMint: elementMint,
    sellerTokenAccount: sellerTokenAccount,
    escrowTokenAccount: escrowTokenAccount,
    seller: seller.publicKey,
    systemProgram: SystemProgram.programId,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    rent: SYSVAR_RENT_PUBKEY,
  })
  .rpc();

// Buy NFT with alSOL
await marketplace.methods
  .buyNft()
  .accounts({
    listingAccount: listingPda,
    escrowTokenAccount: escrowTokenAccount,
    buyerTokenAccount: buyerTokenAccount,
    seller: seller.publicKey,
    alsolMint: ALSOL_MINT,
    buyerAlsolAccount: buyerAlsolTokenAccount,
    sellerAlsolAccount: sellerAlsolTokenAccount,
    buyer: buyer.publicKey,
    systemProgram: SystemProgram.programId,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    rent: SYSVAR_RENT_PUBKEY,
  })
  .signers([buyer])
  .rpc();

// Update listing price
await marketplace.methods
  .updatePrice(new BN(10_000_000_000)) // 10 alSOL
  .accounts({
    listingAccount: listingPda,
    seller: seller.publicKey,
  })
  .rpc();

// Cancel listing
await marketplace.methods
  .cancelListing()
  .accounts({
    listingAccount: listingPda,
    escrowTokenAccount: escrowTokenAccount,
    sellerTokenAccount: sellerTokenAccount,
    seller: seller.publicKey,
    tokenProgram: TOKEN_PROGRAM_ID,
  })
  .rpc();
```

### Swap (alSOL Purchase)

**Swap SOL for alSOL (1:1 ratio):**
```typescript
// Player buys 1 alSOL with 1 SOL
await marketplace.methods
  .swapSolForAlsol(new BN(1_000_000_000)) // 1 SOL
  .accounts({
    devVault: DEV_VAULT_ADDRESS,
    alsolMint: ALSOL_MINT_ADDRESS,
    treasuryAlsolAccount: treasuryAlsolAccount,
    buyerAlsolAccount: buyerAlsolAccount,
    treasuryAuthority: treasuryAuthority.publicKey,
    buyer: buyer.publicKey,
    systemProgram: SystemProgram.programId,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    rent: SYSVAR_RENT_PUBKEY,
  })
  .signers([treasuryAuthority])
  .rpc();
```

**Swap LKC for alSOL (1M:1 ratio):**
```typescript
// Player buys 1 alSOL with 1 million LKC
await marketplace.methods
  .swapLkcForAlsol(new BN(1_000_000)) // 1M LKC
  .accounts({
    lkcMint: LKC_MINT_ADDRESS,
    buyerLkcAccount: buyerLkcAccount,
    devLkcVault: devLkcVault,
    devVaultAuthority: DEV_VAULT_ADDRESS,
    alsolMint: ALSOL_MINT_ADDRESS,
    treasuryAlsolAccount: treasuryAlsolAccount,
    buyerAlsolAccount: buyerAlsolAccount,
    treasuryAuthority: treasuryAuthority.publicKey,
    buyer: buyer.publicKey,
    systemProgram: SystemProgram.programId,
    tokenProgram: TOKEN_PROGRAM_ID,
    associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
    rent: SYSVAR_RENT_PUBKEY,
  })
  .signers([treasuryAuthority])
  .rpc();
```

## 🔒 Security

### Audits
- [ ] Internal review
- [ ] External audit (Kudelski, OtterSec, etc.)
- [ ] Bug bounty program

### Best Practices
- All sensitive operations require owner signatures
- PDAs used for escrow accounts
- Validation checks on all inputs
- Rate limiting on minting
- Admin functions protected with multisig

## 🧪 Testing

### Local Testing
```bash
# Start local validator
solana-test-validator

# In another terminal
anchor test --skip-local-validator
```

### Devnet Testing
```bash
# Configure CLI for devnet
solana config set --url devnet

# Airdrop SOL for testing
solana airdrop 2

# Deploy and test
anchor test --provider.cluster devnet
```

## 📚 Documentation

- **[ONCHAIN_REQUIREMENTS.md](./ONCHAIN_REQUIREMENTS.md)** - Detailed requirements and architecture
- **Anchor Book:** https://book.anchor-lang.com/
- **Solana Cookbook:** https://solanacookbook.com/
- **Metaplex Docs:** https://docs.metaplex.com/

## 🛠 Development Roadmap

### Phase 1: Core (Current)
- [x] Project setup
- [x] Element NFT program structure
- [ ] Complete element-nft instructions
- [ ] Unit tests for element-nft
- [ ] Metaplex metadata integration

### Phase 2: Marketplace
- [x] Marketplace program
- [x] Listing instructions (create, cancel, update price)
- [x] Escrow system with alSOL payments
- [x] Swap SOL for alSOL (1:1 ratio)
- [x] Swap LKC for alSOL (1M:1 ratio)
- [x] Integration tests (marketplace + swaps)
- [ ] Deploy alSOL token on devnet
- [ ] Create LKC token for in-game use

### Phase 3: Registry
- [ ] Registry program
- [ ] Element definitions
- [ ] Reaction formulas
- [ ] Validation logic

### Phase 4: Launch
- [ ] Security audit
- [ ] Devnet deployment
- [ ] Mobile app integration
- [ ] Mainnet deployment

## 🔗 Integration

### Mobile App Connection
The Godot mobile app connects to these programs via:
1. **Solana Mobile Wallet Adapter** - Sign transactions
2. **Anchor TypeScript SDK** - Generate instructions
3. **RPC Provider** - Submit transactions

See: `../godot-mobile/` for game implementation
See: `../docs/SOLANA_PLUGIN_SPEC.md` for mobile wallet integration

## 📊 Program Accounts

### Element NFT Program

**ElementAccount** (PDA)
```rust
seeds = [b"element", mint.key().as_ref()]
```

**Size:** ~200 bytes
**Rent:** ~0.002 SOL

### Marketplace Program (TODO)

**ListingAccount** (PDA)
```rust
seeds = [b"listing", seller.key(), mint.key().as_ref()]
```

**EscrowAccount** (PDA)
```rust
seeds = [b"escrow", buyer.key(), seller.key(), mint.key().as_ref()]
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines
- Write tests for all new features
- Follow Anchor best practices
- Document all public functions
- Update CHANGELOG.md

## 📄 License

[To be determined]

## 📞 Contact

- GitHub: [repository]
- Discord: [server]
- Email: dev@lenkinverse.com

## 🙏 Acknowledgments

- Solana Foundation
- Anchor Framework
- Metaplex Foundation
- LenKinVerse Community

# alSOL Token - LenKinVerse In-Game Currency

## Overview

**alSOL** (Alchemy SOL) is the in-game currency for LenKinVerse, backed 1:1 by real SOL from the development team. Players use alSOL to trade element NFTs on the in-game marketplace.

## Token Specification

- **Token Standard:** SPL Token
- **Decimals:** 9 (same as SOL)
- **Symbol:** alSOL
- **Name:** Alchemy SOL
- **Supply:** Controlled by dev team mint authority
- **Backing:** 1 alSOL = 1 SOL (maintained by dev team reserves)

## Token Economics

### Minting & Distribution

The alSOL token is minted by the development team with a controlled mint authority:

1. **Initial Supply:** Minted as needed to match SOL reserves
2. **Mint Authority:** Controlled by dev team multisig wallet
3. **Freeze Authority:** Disabled (players have full control)

### Player Acquisition

Players can acquire alSOL through:

1. **Purchase:** Exchange SOL for alSOL via in-game swap interface
   - Rate: 1 SOL = 1 alSOL (minus small transaction fees)
   - Dev team provides liquidity
2. **Rewards:** Earn alSOL through gameplay (future feature)
3. **Trading:** Sell element NFTs on marketplace for alSOL

### Redemption

Players can convert alSOL back to SOL:

1. **Sell alSOL:** Exchange alSOL for SOL via swap interface
   - Rate: 1 alSOL = 1 SOL (minus small transaction fees)
2. **Guaranteed Backing:** Dev team maintains SOL reserves to back all alSOL

## Implementation

### Using Existing SPL Token

alSOL uses the standard SPL Token program, which is already deployed on Solana:

```
Token Program: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
```

### Deployment Steps

1. **Create alSOL Mint:**
   ```bash
   spl-token create-token --decimals 9
   # Returns: alSOL mint address
   ```

2. **Set Mint Authority:**
   ```bash
   # Transfer to dev team multisig
   spl-token authorize <ALSOL_MINT> mint <DEV_MULTISIG>
   ```

3. **Disable Freeze Authority:**
   ```bash
   spl-token authorize <ALSOL_MINT> freeze --disable
   ```

4. **Create Initial Supply:**
   ```bash
   # Mint initial supply to treasury
   spl-token mint <ALSOL_MINT> <INITIAL_AMOUNT> <TREASURY_ACCOUNT>
   ```

### Marketplace Integration

The marketplace program uses alSOL for all transactions:

```typescript
// List NFT for sale
await marketplace.methods
  .createListing(
    new BN(1_000_000_000) // 1 alSOL (with 9 decimals)
  )
  .accounts({
    alsolMint: ALSOL_MINT_ADDRESS,
    // ... other accounts
  })
  .rpc();

// Buy NFT with alSOL
await marketplace.methods
  .buyNft()
  .accounts({
    alsolMint: ALSOL_MINT_ADDRESS,
    buyerAlsolAccount: buyerAlsolTokenAccount,
    sellerAlsolAccount: sellerAlsolTokenAccount,
    // ... other accounts
  })
  .rpc();
```

## Security Considerations

### Mint Authority Control

- **Multisig Required:** Mint authority held by m-of-n multisig (e.g., 3-of-5)
- **Transparency:** All minting events logged and publicly auditable
- **Reserve Proof:** Regular attestations showing SOL backing

### Player Protection

1. **No Freeze Authority:** Players have full custody of their alSOL
2. **Decentralized Trading:** All trades executed on-chain via smart contract
3. **Atomic Swaps:** NFT-for-alSOL exchanges are atomic (all-or-nothing)

### Backing Guarantees

- **Treasury Reserve:** Dev team maintains >= 1 SOL for every alSOL in circulation
- **Audit Trail:** All mint/burn operations recorded on-chain
- **Emergency Procedures:** Protocol for handling edge cases (detailed in operations manual)

## Development Roadmap

### Phase 1: Core Implementation (Current)
- [x] Marketplace program with alSOL support
- [ ] Deploy alSOL token on devnet
- [ ] Create dev team treasury accounts
- [ ] Test marketplace with alSOL

### Phase 2: Swap Interface
- [ ] Create swap program (SOL ↔ alSOL)
- [ ] Implement constant product AMM or simple swap
- [ ] Add liquidity pool management
- [ ] UI for swapping in mobile app

### Phase 3: Rewards System
- [ ] Gameplay rewards in alSOL
- [ ] Daily login bonuses
- [ ] Achievement rewards
- [ ] Referral program

### Phase 4: Advanced Features
- [ ] alSOL staking for bonus rates
- [ ] Liquidity mining incentives
- [ ] Governance voting with alSOL
- [ ] Cross-chain bridges (future)

## Testing on Devnet

### 1. Create Test alSOL Mint

```bash
# Create mint
solana config set --url devnet
spl-token create-token --decimals 9
# Save mint address as ALSOL_MINT

# Create token accounts for testing
spl-token create-account <ALSOL_MINT>

# Mint test tokens
spl-token mint <ALSOL_MINT> 1000 <YOUR_TOKEN_ACCOUNT>
```

### 2. Test Marketplace

```bash
# Build and deploy
anchor build
anchor deploy --provider.cluster devnet

# Run tests
anchor test --provider.cluster devnet
```

### 3. Verify Transactions

```bash
# Check alSOL balance
spl-token balance <ALSOL_MINT>

# View transaction history
solana transaction-history <WALLET_ADDRESS>
```

## Production Deployment

### Mainnet Checklist

- [ ] Security audit of marketplace program
- [ ] Create mainnet alSOL mint with multisig authority
- [ ] Fund treasury with initial SOL reserves
- [ ] Deploy marketplace program to mainnet
- [ ] Configure mobile app with mainnet addresses
- [ ] Test transactions with small amounts
- [ ] Enable public trading

### Monitoring

- **Reserve Ratio:** Continuously monitor SOL reserves vs alSOL supply
- **Transaction Volume:** Track marketplace activity
- **Price Stability:** Ensure 1:1 peg is maintained
- **User Balances:** Monitor for anomalies or exploits

## FAQ

### Q: Why not use SOL directly?

A: alSOL provides several benefits:
1. **In-game economy separation:** Prevents direct SOL volatility impact
2. **Reward distribution:** Easy to reward players without requiring SOL
3. **Future features:** Enables staking, governance, and other token utilities
4. **UX:** Simpler for players to understand in-game currency

### Q: What if the peg breaks?

A: The dev team commits to maintaining the 1:1 peg by:
- Maintaining adequate SOL reserves
- Providing liquidity for swaps
- Monitoring and adjusting supply as needed

### Q: Can I trade alSOL on external DEXes?

A: Yes! alSOL is a standard SPL token and can be listed on Raydium, Orca, or any Solana DEX. However, liquidity may initially be limited to the in-game swap interface.

### Q: What happens if the game shuts down?

A: Players can always redeem their alSOL for SOL via the redemption contract, which will be maintained even if the game itself is discontinued.

## Contract Addresses

### Devnet (Testing)
- **alSOL Mint:** `TBD - Create on devnet`
- **Marketplace Program:** `MKTPLCExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Treasury Account:** `TBD`

### Mainnet (Production)
- **alSOL Mint:** `TBD - Deploy after audit`
- **Marketplace Program:** `TBD - Deploy after audit`
- **Treasury Account:** `TBD - Multisig wallet`

## Support

For questions or issues regarding alSOL:
- GitHub Issues: [repository]
- Discord: [server]
- Email: dev@lenkinverse.com

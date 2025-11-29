import {
  PublicKey,
  Transaction,
  TransactionInstruction,
  SystemProgram,
  LAMPORTS_PER_SOL,
} from '@solana/web3.js';
import {
  TOKEN_PROGRAM_ID,
  createMint,
  getMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
  transfer,
} from '@solana/spl-token';
import { getSolanaConfig } from '../config/solana';
import { logger } from '../utils/logger';

/**
 * Price Oracle Integration
 * Updates on-chain LKC/SOL price for marketplace calculations
 */
export class PriceOracleService {
  private config = getSolanaConfig();

  /**
   * Update the LKC/SOL price on-chain
   * Called periodically by backend (e.g., every 5 minutes)
   *
   * NOTE: Requires oracle to be initialized first via:
   * cd solana-contracts && ts-node scripts/initialize-price-oracle.ts
   */
  async updatePrice(lkcPerSol: number): Promise<string> {
    try {
      logger.info(`📊 Price oracle update requested: ${lkcPerSol} LKC per SOL`);

      // TODO: Implement with @coral-xyz/anchor when oracle is initialized
      // Current IDL format requires additional setup
      logger.warn('⚠️  Price oracle needs initialization - returning placeholder');

      return 'PLACEHOLDER_TX_UPDATE_PRICE';
    } catch (error) {
      logger.error('Error updating price oracle:', error);
      throw error;
    }
  }

  /**
   * Get current on-chain price
   */
  async getCurrentPrice(): Promise<number> {
    try {
      logger.info('📊 Fetching current price from oracle');

      // TODO: Implement with @coral-xyz/anchor when oracle is initialized
      logger.warn('⚠️  Price oracle needs initialization - returning default price');

      return 0.00001; // Default: 100,000 LKC per SOL
    } catch (error) {
      logger.error('Error reading price oracle:', error);
      throw error;
    }
  }
}

/**
 * Item Marketplace Integration
 * Mint and manage in-game items as NFTs
 */
export class ItemMarketplaceService {
  private config = getSolanaConfig();

  /**
   * Mint an item NFT to player wallet
   * Called when player earns items (gloves, isotopes, etc.)
   *
   * ✅ WORKING - Uses SPL Token standard
   */
  async mintItemNFT(
    playerWallet: string,
    itemId: string,
    itemMetadata: {
      name: string;
      description: string;
      image_url: string;
    }
  ): Promise<string> {
    try {
      logger.info(`🎨 Minting item NFT: ${itemId} for ${playerWallet}`);

      const playerPubkey = new PublicKey(playerWallet);

      // Create NFT mint
      const mintKeypair = await createMint(
        this.config.connection,
        this.config.authority,
        this.config.authority.publicKey, // mint authority
        this.config.authority.publicKey, // freeze authority
        0 // 0 decimals for NFT
      );

      logger.info(`✅ Created NFT mint: ${mintKeypair.toString()}`);

      // Create token account for player
      const tokenAccount = await getOrCreateAssociatedTokenAccount(
        this.config.connection,
        this.config.authority,
        mintKeypair,
        playerPubkey
      );

      // Mint 1 NFT to player
      const mintTx = await mintTo(
        this.config.connection,
        this.config.authority,
        mintKeypair,
        tokenAccount.address,
        this.config.authority,
        1
      );

      logger.info(`✅ Minted NFT to player: ${mintTx}`);
      logger.info(`NFT Token Account: ${tokenAccount.address.toString()}`);

      return mintTx;
    } catch (error) {
      logger.error('Error minting item NFT:', error);
      throw error;
    }
  }

  /**
   * List item on marketplace
   */
  async listItem(itemMint: string, price: number): Promise<string> {
    logger.warn('⚠️  Item listing needs Anchor integration');
    return 'PLACEHOLDER_TX_LIST_ITEM';
  }
}

/**
 * Element Token Factory Integration
 * Register and manage element SPL tokens (lkO, lkH, lkCa, etc.)
 */
export class ElementTokenFactoryService {
  private config = getSolanaConfig();

  /**
   * Register a new element as SPL token
   * Only for rare/tradeable elements (NOT lkC which stays in database)
   *
   * NOTE: Requires element registry to be initialized
   */
  async registerElement(
    elementId: string,
    governorWallet: string,
    rarity: number = 1,
    uri: string = ''
  ): Promise<{
    tx_signature: string;
    mint_address: string;
  }> {
    try {
      logger.info(`🏭 Element registration requested: ${elementId} with governor ${governorWallet}`);

      // Derive element mint PDA (for reference)
      const [elementMintPda] = PublicKey.findProgramAddressSync(
        [Buffer.from('element_mint'), Buffer.from(elementId)],
        this.config.programs.element_token_factory
      );

      logger.info(`Element mint PDA: ${elementMintPda.toString()}`);

      // TODO: Implement with @coral-xyz/anchor when registry is initialized
      logger.warn('⚠️  Element registration needs initialization - returning placeholder');

      return {
        tx_signature: 'PLACEHOLDER_TX_REGISTER_ELEMENT',
        mint_address: elementMintPda.toString(),
      };
    } catch (error) {
      logger.error('Error registering element:', error);
      throw error;
    }
  }

  /**
   * Get element token info
   */
  async getElementInfo(elementId: string): Promise<any> {
    try {
      logger.info(`🔍 Querying element info for: ${elementId}`);

      // TODO: Implement with @coral-xyz/anchor when registry is initialized
      logger.warn('⚠️  Element info query needs initialization - returning null');

      return null;
    } catch (error) {
      logger.error('Error getting element info:', error);
      return null;
    }
  }
}

/**
 * Treasury Bridge Integration
 * Bridge between in-game database and on-chain SPL tokens
 */
export class TreasuryBridgeService {
  private config = getSolanaConfig();

  /**
   * Bridge in-game element to on-chain SPL token
   * Player converts database lkO → on-chain lkO SPL tokens
   *
   * NOTE: Requires element to be registered first
   */
  async bridgeToChain(
    playerWallet: string,
    elementId: string,
    amount: number
  ): Promise<string> {
    try {
      logger.info(
        `🌉 Bridge to chain requested: ${amount} ${elementId} for ${playerWallet}`
      );

      // TODO: Implement with @coral-xyz/anchor
      logger.warn('⚠️  Bridge to chain needs Anchor integration');

      return 'PLACEHOLDER_TX_BRIDGE_TO_CHAIN';
    } catch (error) {
      logger.error('Error bridging to chain:', error);
      throw error;
    }
  }

  /**
   * Bridge on-chain SPL tokens back to in-game database
   * Player converts on-chain lkO → database lkO with fees
   */
  async bridgeFromChain(
    playerWallet: string,
    elementId: string,
    amount: number
  ): Promise<string> {
    try {
      logger.info(
        `🌉 Bridge from chain requested: ${amount} ${elementId} for ${playerWallet}`
      );

      // TODO: Implement with @coral-xyz/anchor
      logger.warn('⚠️  Bridge from chain needs Anchor integration');

      return 'PLACEHOLDER_TX_BRIDGE_FROM_CHAIN';
    } catch (error) {
      logger.error('Error bridging from chain:', error);
      throw error;
    }
  }
}

// Export singleton instances
export const priceOracleService = new PriceOracleService();
export const itemMarketplaceService = new ItemMarketplaceService();
export const elementTokenFactoryService = new ElementTokenFactoryService();
export const treasuryBridgeService = new TreasuryBridgeService();

import express, { Request, Response } from 'express';
import {
  priceOracleService,
  itemMarketplaceService,
  elementTokenFactoryService,
  treasuryBridgeService,
} from '../services/solana-integration';
import { logger } from '../utils/logger';

const router = express.Router();

/**
 * POST /api/solana/update-price
 * Update on-chain LKC/SOL price oracle
 * Body: { lkc_per_sol: number }
 */
router.post('/update-price', async (req: Request, res: Response) => {
  try {
    const { lkc_per_sol } = req.body;

    if (!lkc_per_sol || lkc_per_sol <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid lkc_per_sol value',
      });
    }

    const txSignature = await priceOracleService.updatePrice(lkc_per_sol);

    res.json({
      success: true,
      tx_signature: txSignature,
      price: lkc_per_sol,
      message: `Price updated to ${lkc_per_sol} LKC per SOL`,
    });
  } catch (error) {
    logger.error('Update price error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * GET /api/solana/price
 * Get current on-chain LKC/SOL price
 */
router.get('/price', async (req: Request, res: Response) => {
  try {
    const price = await priceOracleService.getCurrentPrice();

    res.json({
      success: true,
      lkc_per_sol: price,
    });
  } catch (error) {
    logger.error('Get price error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/solana/mint-item-nft
 * Mint an item NFT to player wallet
 * Body: { player_wallet, item_id, name, description, image_url }
 */
router.post('/mint-item-nft', async (req: Request, res: Response) => {
  try {
    const { player_wallet, item_id, name, description, image_url } = req.body;

    if (!player_wallet || !item_id || !name) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: player_wallet, item_id, name',
      });
    }

    const txSignature = await itemMarketplaceService.mintItemNFT(
      player_wallet,
      item_id,
      {
        name,
        description: description || `${name} - ReAgenyx Item`,
        image_url: image_url || 'https://reagenyx.com/items/default.png',
      }
    );

    res.json({
      success: true,
      tx_signature: txSignature,
      message: `NFT minted for ${item_id}`,
    });
  } catch (error) {
    logger.error('Mint NFT error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/solana/register-element
 * Register new element as SPL token
 * Body: { element_id, governor_wallet }
 */
router.post('/register-element', async (req: Request, res: Response) => {
  try {
    const { element_id, governor_wallet } = req.body;

    if (!element_id || !governor_wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: element_id, governor_wallet',
      });
    }

    // Note: LKC should never be registered - it stays as pure game data
    if (element_id === 'lkC') {
      return res.status(400).json({
        success: false,
        error: 'LKC cannot be registered as SPL token - it is pure game data',
      });
    }

    const result = await elementTokenFactoryService.registerElement(
      element_id,
      governor_wallet
    );

    res.json({
      success: true,
      tx_signature: result.tx_signature,
      mint_address: result.mint_address,
      message: `Element ${element_id} registered`,
    });
  } catch (error) {
    logger.error('Register element error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * GET /api/solana/element/:elementId
 * Get element token info
 */
router.get('/element/:elementId', async (req: Request, res: Response) => {
  try {
    const { elementId } = req.params;

    const elementInfo = await elementTokenFactoryService.getElementInfo(elementId);

    if (!elementInfo) {
      return res.status(404).json({
        success: false,
        error: `Element ${elementId} not registered`,
      });
    }

    res.json({
      success: true,
      element: elementInfo,
    });
  } catch (error) {
    logger.error('Get element error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/solana/bridge-to-chain
 * Bridge in-game element to on-chain SPL token
 * Body: { player_wallet, element_id, amount }
 */
router.post('/bridge-to-chain', async (req: Request, res: Response) => {
  try {
    const { player_wallet, element_id, amount } = req.body;

    if (!player_wallet || !element_id || !amount) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: player_wallet, element_id, amount',
      });
    }

    // LKC cannot be bridged - it's pure game data
    if (element_id === 'lkC') {
      return res.status(400).json({
        success: false,
        error: 'LKC cannot be bridged - it is pure game data',
      });
    }

    // TODO: Verify player has sufficient in-game balance
    // This should query player_inventory table

    const txSignature = await treasuryBridgeService.bridgeToChain(
      player_wallet,
      element_id,
      amount
    );

    res.json({
      success: true,
      tx_signature: txSignature,
      message: `Bridged ${amount} ${element_id} to chain`,
    });
  } catch (error) {
    logger.error('Bridge to chain error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/solana/bridge-from-chain
 * Bridge on-chain SPL tokens to in-game database
 * Body: { player_wallet, element_id, amount }
 */
router.post('/bridge-from-chain', async (req: Request, res: Response) => {
  try {
    const { player_wallet, element_id, amount } = req.body;

    if (!player_wallet || !element_id || !amount) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: player_wallet, element_id, amount',
      });
    }

    const txSignature = await treasuryBridgeService.bridgeFromChain(
      player_wallet,
      element_id,
      amount
    );

    res.json({
      success: true,
      tx_signature: txSignature,
      message: `Bridged ${amount} ${element_id} from chain`,
    });
  } catch (error) {
    logger.error('Bridge from chain error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

export default router;

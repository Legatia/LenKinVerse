import express, { Request, Response } from 'express';
import {
  createMarketplaceListing,
  getMarketplaceListings,
  buyMarketplaceListing,
  cancelMarketplaceListing,
  getPlayerListings,
  getPlayerTransactionHistory,
} from '../db/marketplace-queries';
import { logger } from '../utils/logger';

const router = express.Router();

/**
 * GET /api/marketplace/listings
 * Get all active marketplace listings
 * Query params: ?type=element|compound&limit=100&offset=0
 */
router.get('/listings', async (req: Request, res: Response) => {
  try {
    const { type, limit, offset } = req.query;

    const itemType =
      type === 'element' || type === 'compound' ? (type as 'element' | 'compound') : undefined;
    const limitNum = limit ? parseInt(limit as string) : 100;
    const offsetNum = offset ? parseInt(offset as string) : 0;

    const listings = await getMarketplaceListings(itemType, limitNum, offsetNum);

    res.json({
      success: true,
      count: listings.length,
      listings,
    });
  } catch (error) {
    logger.error('Get marketplace listings error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/marketplace/list
 * Create a new marketplace listing
 * Body: { seller_wallet, item_type, item_id, amount, price_per_unit }
 */
router.post('/list', async (req: Request, res: Response) => {
  try {
    const { seller_wallet, item_type, item_id, amount, price_per_unit } = req.body;

    if (!seller_wallet || !item_type || !item_id || !amount || !price_per_unit) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: seller_wallet, item_type, item_id, amount, price_per_unit',
      });
    }

    if (item_type !== 'element' && item_type !== 'compound') {
      return res.status(400).json({
        success: false,
        error: 'item_type must be "element" or "compound"',
      });
    }

    if (amount <= 0 || price_per_unit <= 0) {
      return res.status(400).json({
        success: false,
        error: 'amount and price_per_unit must be positive numbers',
      });
    }

    const listing = await createMarketplaceListing(
      seller_wallet,
      item_type,
      item_id,
      amount,
      price_per_unit
    );

    res.json({
      success: true,
      listing,
      message: `Successfully listed ${amount} ${item_id} for ${price_per_unit} alSOL each`,
    });
  } catch (error) {
    logger.error('Create listing error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/marketplace/buy/:listingId
 * Buy an item from a listing
 * Body: { buyer_wallet }
 */
router.post('/buy/:listingId', async (req: Request, res: Response) => {
  try {
    const { listingId } = req.params;
    const { buyer_wallet } = req.body;

    if (!buyer_wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: buyer_wallet',
      });
    }

    const listingIdNum = parseInt(listingId);
    if (isNaN(listingIdNum)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid listing ID',
      });
    }

    const transaction = await buyMarketplaceListing(buyer_wallet, listingIdNum);

    res.json({
      success: true,
      transaction,
      message: `Successfully purchased ${transaction.amount} ${transaction.item_id} for ${transaction.price_paid} alSOL`,
    });
  } catch (error) {
    logger.error('Buy listing error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * DELETE /api/marketplace/listing/:listingId
 * Cancel a marketplace listing
 * Body: { seller_wallet }
 */
router.delete('/listing/:listingId', async (req: Request, res: Response) => {
  try {
    const { listingId } = req.params;
    const { seller_wallet } = req.body;

    if (!seller_wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: seller_wallet',
      });
    }

    const listingIdNum = parseInt(listingId);
    if (isNaN(listingIdNum)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid listing ID',
      });
    }

    await cancelMarketplaceListing(seller_wallet, listingIdNum);

    res.json({
      success: true,
      message: `Successfully cancelled listing ${listingId}`,
    });
  } catch (error) {
    logger.error('Cancel listing error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * GET /api/marketplace/my-listings/:wallet
 * Get player's active listings
 */
router.get('/my-listings/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;

    const listings = await getPlayerListings(wallet);

    res.json({
      success: true,
      count: listings.length,
      listings,
    });
  } catch (error) {
    logger.error('Get player listings error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * GET /api/marketplace/history/:wallet
 * Get player's transaction history
 * Query params: ?limit=50
 */
router.get('/history/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;
    const { limit } = req.query;

    const limitNum = limit ? parseInt(limit as string) : 50;

    const transactions = await getPlayerTransactionHistory(wallet, limitNum);

    res.json({
      success: true,
      count: transactions.length,
      transactions,
    });
  } catch (error) {
    logger.error('Get transaction history error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

export default router;

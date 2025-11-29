/**
 * Chemistry API Routes
 *
 * Endpoints for chemistry system:
 * - GET /api/chemistry/elements - List all elements
 * - GET /api/chemistry/compounds - List all compounds
 * - GET /api/chemistry/reactions - List all reactions
 * - GET /api/chemistry/inventory/:wallet - Get player inventory
 * - POST /api/chemistry/react - Perform a reaction
 * - GET /api/chemistry/unlocks/:wallet - Get player unlocks
 * - GET /api/chemistry/history/:wallet - Get reaction history
 */

import express, { Request, Response } from 'express';
import {
  getAllElements,
  getElementById,
  getAllCompounds,
  getCompoundById,
  getAllReactions,
  getReactionById,
  getPlayerFullInventory,
  performReaction,
  getPlayerUnlocks,
  getReactionHistory,
  getDiscoveryInfo,
} from '../db/chemistry-queries';
import { logger } from '../utils/logger';

const router = express.Router();

// ============================================================================
// GET /api/chemistry/elements
// List all elements
// ============================================================================
router.get('/elements', async (req: Request, res: Response) => {
  try {
    const elements = await getAllElements();

    res.json({
      success: true,
      count: elements.length,
      data: elements,
    });
  } catch (error) {
    logger.error('Get elements error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch elements',
    });
  }
});

// ============================================================================
// GET /api/chemistry/elements/:id
// Get single element by ID
// ============================================================================
router.get('/elements/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const element = await getElementById(id);

    if (!element) {
      return res.status(404).json({
        success: false,
        message: `Element ${id} not found`,
      });
    }

    res.json({
      success: true,
      data: element,
    });
  } catch (error) {
    logger.error('Get element error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch element',
    });
  }
});

// ============================================================================
// GET /api/chemistry/compounds
// List all compounds
// ============================================================================
router.get('/compounds', async (req: Request, res: Response) => {
  try {
    const compounds = await getAllCompounds();

    res.json({
      success: true,
      count: compounds.length,
      data: compounds,
    });
  } catch (error) {
    logger.error('Get compounds error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch compounds',
    });
  }
});

// ============================================================================
// GET /api/chemistry/compounds/:id
// Get single compound with discovery info
// ============================================================================
router.get('/compounds/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const compound = await getCompoundById(id);

    if (!compound) {
      return res.status(404).json({
        success: false,
        message: `Compound ${id} not found`,
      });
    }

    // Get discovery info
    const discovery = await getDiscoveryInfo(id);

    res.json({
      success: true,
      data: {
        ...compound,
        discovery,
      },
    });
  } catch (error) {
    logger.error('Get compound error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch compound',
    });
  }
});

// ============================================================================
// GET /api/chemistry/reactions
// List all reactions (optional filter by type: chemical, nuclear, physical)
// ============================================================================
router.get('/reactions', async (req: Request, res: Response) => {
  try {
    const { type } = req.query;
    const reactionType = type ? String(type) : undefined;

    const reactions = await getAllReactions(reactionType);

    res.json({
      success: true,
      count: reactions.length,
      filter: reactionType ? { type: reactionType } : null,
      data: reactions,
    });
  } catch (error) {
    logger.error('Get reactions error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch reactions',
    });
  }
});

// ============================================================================
// GET /api/chemistry/reactions/:id
// Get single reaction by ID
// ============================================================================
router.get('/reactions/:id', async (req: Request, res: Response) => {
  try {
    const reactionId = parseInt(req.params.id);

    if (isNaN(reactionId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid reaction ID',
      });
    }

    const reaction = await getReactionById(reactionId);

    if (!reaction) {
      return res.status(404).json({
        success: false,
        message: `Reaction ${reactionId} not found`,
      });
    }

    res.json({
      success: true,
      data: reaction,
    });
  } catch (error) {
    logger.error('Get reaction error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch reaction',
    });
  }
});

// ============================================================================
// GET /api/chemistry/inventory/:wallet
// Get player's full inventory (elements + compounds)
// ============================================================================
router.get('/inventory/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;

    if (!wallet) {
      return res.status(400).json({
        success: false,
        message: 'Wallet address is required',
      });
    }

    const inventory = await getPlayerFullInventory(wallet);

    // Organize by type
    const organized = {
      elements: inventory.filter((item) => item.item_type === 'element'),
      compounds: inventory.filter((item) => item.item_type === 'compound'),
    };

    res.json({
      success: true,
      wallet,
      total_items: inventory.length,
      data: organized,
    });
  } catch (error) {
    logger.error('Get inventory error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch inventory',
    });
  }
});

// ============================================================================
// POST /api/chemistry/react
// Perform a chemical/nuclear reaction
// ============================================================================
router.post('/react', async (req: Request, res: Response) => {
  try {
    const { player_wallet, reaction_id } = req.body;

    // Validation
    if (!player_wallet) {
      return res.status(400).json({
        success: false,
        message: 'player_wallet is required',
      });
    }

    if (!reaction_id || typeof reaction_id !== 'number') {
      return res.status(400).json({
        success: false,
        message: 'reaction_id must be a number',
      });
    }

    // Perform reaction
    const result = await performReaction(player_wallet, reaction_id);

    // Log success/failure
    if (result.success) {
      logger.info(
        `✅ ${player_wallet} successfully performed ${result.reaction_name}`
      );

      if (result.discovery) {
        logger.info(
          `🎉 FIRST DISCOVERY: ${player_wallet} discovered ${result.discovery.compound_id}`
        );
      }
    } else {
      logger.info(`❌ ${player_wallet} failed ${result.reaction_name}`);
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    logger.error('Reaction error:', error);
    res.status(400).json({
      success: false,
      message: error instanceof Error ? error.message : 'Reaction failed',
    });
  }
});

// ============================================================================
// GET /api/chemistry/unlocks/:wallet
// Get player's unlocked elements, compounds, and reactions
// ============================================================================
router.get('/unlocks/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;
    const { type } = req.query; // Optional filter: element, compound, reaction

    if (!wallet) {
      return res.status(400).json({
        success: false,
        message: 'Wallet address is required',
      });
    }

    const unlockType = type ? String(type) : undefined;
    const unlocks = await getPlayerUnlocks(wallet, unlockType);

    // Organize by type
    const organized = {
      elements: unlocks.filter((u) => u.unlock_type === 'element'),
      compounds: unlocks.filter((u) => u.unlock_type === 'compound'),
      reactions: unlocks.filter((u) => u.unlock_type === 'reaction'),
    };

    res.json({
      success: true,
      wallet,
      total_unlocks: unlocks.length,
      filter: unlockType ? { type: unlockType } : null,
      data: organized,
    });
  } catch (error) {
    logger.error('Get unlocks error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch unlocks',
    });
  }
});

// ============================================================================
// GET /api/chemistry/history/:wallet
// Get player's reaction history
// ============================================================================
router.get('/history/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;
    const { limit } = req.query;

    if (!wallet) {
      return res.status(400).json({
        success: false,
        message: 'Wallet address is required',
      });
    }

    const historyLimit = limit ? parseInt(String(limit)) : 50;
    const history = await getReactionHistory(wallet, historyLimit);

    // Calculate success rate
    const successCount = history.filter((h) => h.success).length;
    const totalAttempts = history.length;
    const successRate =
      totalAttempts > 0 ? (successCount / totalAttempts) * 100 : 0;

    res.json({
      success: true,
      wallet,
      total_attempts: totalAttempts,
      successful_reactions: successCount,
      success_rate: successRate.toFixed(1) + '%',
      data: history,
    });
  } catch (error) {
    logger.error('Get history error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to fetch history',
    });
  }
});

export default router;

/**
 * Player API Routes
 *
 * Endpoints for player-related data:
 * - GET /api/player/energy/:wallet - Get player energy with stats
 * - POST /api/player/energy/restore - Restore energy (admin/testing)
 * - GET /api/player/stats/:wallet - Get player statistics
 * - GET /api/player/leaderboard/energy - Energy leaderboard
 */

import express, { Request, Response } from 'express';
import {
  getPlayerEnergy,
  getPlayerEnergyStats,
  setPlayerEnergy,
  getEnergyLeaderboard,
} from '../db/energy-queries';
import { logger } from '../utils/logger';

const router = express.Router();

// ============================================================================
// GET /api/player/energy/:wallet
// Get player's current energy with detailed stats
// ============================================================================
router.get('/energy/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;

    if (!wallet) {
      return res.status(400).json({
        success: false,
        message: 'Wallet address is required',
      });
    }

    // Get detailed energy stats
    const stats = await getPlayerEnergyStats(wallet);

    // Calculate time until full (human readable)
    const hours = Math.floor(stats.minutes_until_full / 60);
    const minutes = stats.minutes_until_full % 60;
    const timeUntilFull =
      stats.current_energy >= stats.max_energy
        ? 'Full'
        : hours > 0
        ? `${hours}h ${minutes}m`
        : `${minutes}m`;

    res.json({
      success: true,
      wallet: wallet,
      data: {
        current_energy: stats.current_energy,
        max_energy: stats.max_energy,
        energy_percentage: stats.energy_percentage,
        time_until_full: timeUntilFull,
        minutes_until_full: stats.minutes_until_full,
        regeneration_rate: stats.regeneration_rate,
        total_energy_spent: stats.total_energy_spent,
      },
    });
  } catch (error) {
    logger.error('Get player energy error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to get energy',
    });
  }
});

// ============================================================================
// POST /api/player/energy/restore
// Manually restore player energy (admin/testing only)
// ============================================================================
router.post('/energy/restore', async (req: Request, res: Response) => {
  try {
    const { player_wallet, energy_amount } = req.body;

    // Validation
    if (!player_wallet) {
      return res.status(400).json({
        success: false,
        message: 'player_wallet is required',
      });
    }

    if (energy_amount === undefined || typeof energy_amount !== 'number') {
      return res.status(400).json({
        success: false,
        message: 'energy_amount must be a number',
      });
    }

    if (energy_amount < 0 || energy_amount > 100) {
      return res.status(400).json({
        success: false,
        message: 'energy_amount must be between 0 and 100',
      });
    }

    // Set energy
    const result = await setPlayerEnergy(player_wallet, energy_amount);

    logger.info(
      `⚡ Manually restored energy for ${player_wallet} to ${energy_amount}`
    );

    res.json({
      success: true,
      message: `Energy restored to ${energy_amount}⚡`,
      data: {
        player_wallet: result.player_wallet,
        current_energy: result.current_energy,
        max_energy: result.max_energy,
      },
    });
  } catch (error) {
    logger.error('Restore energy error:', error);
    res.status(500).json({
      success: false,
      message:
        error instanceof Error ? error.message : 'Failed to restore energy',
    });
  }
});

// ============================================================================
// GET /api/player/stats/:wallet
// Get comprehensive player statistics
// ============================================================================
router.get('/stats/:wallet', async (req: Request, res: Response) => {
  try {
    const { wallet } = req.params;

    if (!wallet) {
      return res.status(400).json({
        success: false,
        message: 'Wallet address is required',
      });
    }

    // Get energy stats
    const energyStats = await getPlayerEnergyStats(wallet);

    // TODO: Add more stats when available
    // - Total reactions performed
    // - Total discoveries
    // - Inventory value
    // - Rank

    res.json({
      success: true,
      wallet: wallet,
      data: {
        energy: {
          current: energyStats.current_energy,
          max: energyStats.max_energy,
          percentage: energyStats.energy_percentage,
          total_spent: energyStats.total_energy_spent,
        },
        // TODO: Add more stats sections
        reactions: {
          total_performed: 0, // TODO: Get from reaction_history
          success_rate: 0,
        },
        discoveries: {
          total: 0, // TODO: Get from discoveries table
        },
      },
    });
  } catch (error) {
    logger.error('Get player stats error:', error);
    res.status(500).json({
      success: false,
      message: error instanceof Error ? error.message : 'Failed to get stats',
    });
  }
});

// ============================================================================
// GET /api/player/leaderboard/energy
// Get energy spending leaderboard
// ============================================================================
router.get('/leaderboard/energy', async (req: Request, res: Response) => {
  try {
    const { limit } = req.query;
    const leaderboardLimit = limit ? parseInt(String(limit)) : 10;

    if (leaderboardLimit < 1 || leaderboardLimit > 100) {
      return res.status(400).json({
        success: false,
        message: 'Limit must be between 1 and 100',
      });
    }

    const leaderboard = await getEnergyLeaderboard(leaderboardLimit);

    res.json({
      success: true,
      count: leaderboard.length,
      data: leaderboard.map((entry, index) => ({
        rank: index + 1,
        player_wallet: entry.player_wallet,
        total_energy_spent: entry.total_energy_spent,
        current_energy: entry.current_energy,
      })),
    });
  } catch (error) {
    logger.error('Get energy leaderboard error:', error);
    res.status(500).json({
      success: false,
      message:
        error instanceof Error ? error.message : 'Failed to get leaderboard',
    });
  }
});

export default router;

/**
 * Energy System Database Queries
 *
 * Manages player energy for chemistry reactions:
 * - Time-based regeneration (1⚡ per 3 minutes)
 * - Max capacity: 100⚡
 * - Energy consumption tracking
 */

import { pool } from './queries';
import { logger } from '../utils/logger';

// ============================================================================
// Types
// ============================================================================

export interface PlayerEnergy {
  player_wallet: string;
  current_energy: number;
  max_energy: number;
  last_regeneration_time: Date;
  total_energy_spent: number;
  regenerated_energy?: number; // Energy added since last check
}

export interface EnergyConsumptionResult {
  success: boolean;
  current_energy: number;
  energy_consumed: number;
  message: string;
}

export interface EnergyStats {
  player_wallet: string;
  current_energy: number;
  max_energy: number;
  energy_percentage: number;
  minutes_until_full: number;
  total_energy_spent: number;
  regeneration_rate: string; // "1⚡ per 3 min"
}

// ============================================================================
// Get Player Energy (with auto-regeneration)
// ============================================================================

/**
 * Get player's current energy, automatically applying time-based regeneration
 * Creates a new player energy record if one doesn't exist (starts with 100⚡)
 */
export async function getPlayerEnergy(
  playerWallet: string
): Promise<PlayerEnergy> {
  try {
    const result = await pool.query(
      `SELECT * FROM get_or_create_player_energy($1)`,
      [playerWallet]
    );

    if (result.rows.length === 0) {
      throw new Error('Failed to get or create player energy');
    }

    const row = result.rows[0];

    return {
      player_wallet: row.player_wallet,
      current_energy: parseInt(row.current_energy),
      max_energy: parseInt(row.max_energy),
      last_regeneration_time: row.last_regeneration_time,
      total_energy_spent: parseInt(row.total_energy_spent),
      regenerated_energy: parseInt(row.regenerated_energy || 0),
    };
  } catch (error) {
    logger.error('Error getting player energy:', error);
    throw error;
  }
}

// ============================================================================
// Get Player Energy Stats (detailed info)
// ============================================================================

/**
 * Get detailed energy statistics for display in UI
 */
export async function getPlayerEnergyStats(
  playerWallet: string
): Promise<EnergyStats> {
  try {
    const energy = await getPlayerEnergy(playerWallet);

    // Calculate minutes until full energy
    const energyNeeded = energy.max_energy - energy.current_energy;
    const minutesUntilFull = energyNeeded * 3; // 3 minutes per energy point

    // Calculate percentage
    const percentage = Math.round(
      (energy.current_energy / energy.max_energy) * 100
    );

    return {
      player_wallet: energy.player_wallet,
      current_energy: energy.current_energy,
      max_energy: energy.max_energy,
      energy_percentage: percentage,
      minutes_until_full: minutesUntilFull,
      total_energy_spent: energy.total_energy_spent,
      regeneration_rate: '1⚡ per 3 min',
    };
  } catch (error) {
    logger.error('Error getting player energy stats:', error);
    throw error;
  }
}

// ============================================================================
// Consume Energy (for reactions)
// ============================================================================

/**
 * Attempt to consume energy for a reaction
 * Returns success=false if insufficient energy
 */
export async function consumePlayerEnergy(
  playerWallet: string,
  energyCost: number
): Promise<EnergyConsumptionResult> {
  try {
    const result = await pool.query(
      `SELECT * FROM consume_energy($1, $2)`,
      [playerWallet, energyCost]
    );

    if (result.rows.length === 0) {
      throw new Error('Failed to consume energy');
    }

    const row = result.rows[0];

    return {
      success: row.success,
      current_energy: parseInt(row.current_energy),
      energy_consumed: parseInt(row.energy_consumed),
      message: row.message,
    };
  } catch (error) {
    logger.error('Error consuming player energy:', error);
    throw error;
  }
}

// ============================================================================
// Manual Energy Restoration (for admin/testing)
// ============================================================================

/**
 * Manually set a player's energy (for admin/testing purposes)
 */
export async function setPlayerEnergy(
  playerWallet: string,
  newEnergy: number
): Promise<PlayerEnergy> {
  try {
    // Ensure player record exists first
    await getPlayerEnergy(playerWallet);

    // Update energy
    const result = await pool.query(
      `UPDATE player_energy
       SET current_energy = $2,
           last_regeneration_time = NOW(),
           updated_at = NOW()
       WHERE player_wallet = $1
       RETURNING
           player_wallet,
           current_energy,
           max_energy,
           last_regeneration_time,
           total_energy_spent`,
      [playerWallet, newEnergy]
    );

    if (result.rows.length === 0) {
      throw new Error('Failed to update player energy');
    }

    const row = result.rows[0];

    return {
      player_wallet: row.player_wallet,
      current_energy: parseInt(row.current_energy),
      max_energy: parseInt(row.max_energy),
      last_regeneration_time: row.last_regeneration_time,
      total_energy_spent: parseInt(row.total_energy_spent),
    };
  } catch (error) {
    logger.error('Error setting player energy:', error);
    throw error;
  }
}

// ============================================================================
// Upgrade Max Energy (future feature)
// ============================================================================

/**
 * Increase player's max energy capacity (future feature for upgrades)
 */
export async function upgradeMaxEnergy(
  playerWallet: string,
  newMaxEnergy: number
): Promise<PlayerEnergy> {
  try {
    // Ensure player record exists first
    await getPlayerEnergy(playerWallet);

    // Update max energy
    const result = await pool.query(
      `UPDATE player_energy
       SET max_energy = $2,
           updated_at = NOW()
       WHERE player_wallet = $1
       RETURNING
           player_wallet,
           current_energy,
           max_energy,
           last_regeneration_time,
           total_energy_spent`,
      [playerWallet, newMaxEnergy]
    );

    if (result.rows.length === 0) {
      throw new Error('Failed to upgrade max energy');
    }

    const row = result.rows[0];

    return {
      player_wallet: row.player_wallet,
      current_energy: parseInt(row.current_energy),
      max_energy: parseInt(row.max_energy),
      last_regeneration_time: row.last_regeneration_time,
      total_energy_spent: parseInt(row.total_energy_spent),
    };
  } catch (error) {
    logger.error('Error upgrading max energy:', error);
    throw error;
  }
}

// ============================================================================
// Get Energy Leaderboard (top energy spenders)
// ============================================================================

/**
 * Get top players by total energy spent (for leaderboards)
 */
export async function getEnergyLeaderboard(
  limit: number = 10
): Promise<
  Array<{
    player_wallet: string;
    total_energy_spent: number;
    current_energy: number;
  }>
> {
  try {
    const result = await pool.query(
      `SELECT
           player_wallet,
           total_energy_spent,
           current_energy
       FROM player_energy
       ORDER BY total_energy_spent DESC
       LIMIT $1`,
      [limit]
    );

    return result.rows.map((row) => ({
      player_wallet: row.player_wallet,
      total_energy_spent: parseInt(row.total_energy_spent),
      current_energy: parseInt(row.current_energy),
    }));
  } catch (error) {
    logger.error('Error getting energy leaderboard:', error);
    throw error;
  }
}

/**
 * Database Queries
 *
 * All database operations for player inventories, wild spawns, etc.
 */

import { Pool } from 'pg';
import { logger } from '../utils/logger';

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'lenkinverse',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
});

/**
 * Get player's inventory amount for a specific element
 */
export async function getPlayerInventory(
  playerWallet: string,
  elementId: string
): Promise<number> {
  const result = await pool.query(
    `SELECT amount FROM player_inventory
     WHERE player_wallet = $1 AND element_id = $2`,
    [playerWallet, elementId]
  );

  if (result.rows.length === 0) {
    return 0;
  }

  return parseInt(result.rows[0].amount, 10);
}

/**
 * Burn (delete) player inventory for bridging
 * CRITICAL: This must happen BEFORE signing burn proof
 */
export async function burnPlayerInventory(
  playerWallet: string,
  elementId: string,
  amount: number
): Promise<void> {
  const result = await pool.query(
    `UPDATE player_inventory
     SET amount = amount - $1
     WHERE player_wallet = $2 AND element_id = $3
     RETURNING amount`,
    [amount, playerWallet, elementId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Player ${playerWallet} has no ${elementId} inventory`);
  }

  const newAmount = parseInt(result.rows[0].amount, 10);

  if (newAmount < 0) {
    // Rollback - this shouldn't happen if we checked first
    await pool.query(
      `UPDATE player_inventory
       SET amount = amount + $1
       WHERE player_wallet = $2 AND element_id = $3`,
      [amount, playerWallet, elementId]
    );

    throw new Error('Insufficient balance after burn - transaction rolled back');
  }

  logger.info(`🔥 Burned ${amount} ${elementId} from ${playerWallet}, new balance: ${newAmount}`);
}

/**
 * Update wild spawns when governor bridges to in-game
 */
export async function updateWildSpawns(elementId: string, amount: number): Promise<void> {
  await pool.query(
    `UPDATE element_data
     SET wild_spawns = wild_spawns + $1
     WHERE element_id = $2`,
    [amount, elementId]
  );

  logger.info(`✅ Added ${amount} to ${elementId} wild spawns`);
}

/**
 * Log bridge event for audit trail
 */
export async function logBridgeEvent(event: {
  element_id: string;
  direction: 'to_chain' | 'to_ingame';
  amount: number;
  player_or_governor: string;
  transaction_signature: string;
}): Promise<void> {
  await pool.query(
    `INSERT INTO bridge_history
     (element_id, direction, amount, player_or_governor, transaction_signature, timestamp)
     VALUES ($1, $2, $3, $4, $5, NOW())`,
    [
      event.element_id,
      event.direction,
      event.amount,
      event.player_or_governor,
      event.transaction_signature,
    ]
  );

  logger.info(`📝 Bridge event logged: ${event.transaction_signature}`);
}

/**
 * Get player's alSOL balance
 */
export async function getPlayerAlSOLBalance(playerId: string): Promise<number> {
  const result = await pool.query(
    `SELECT alsol_balance FROM player_balances WHERE player_id = $1`,
    [playerId]
  );

  if (result.rows.length === 0) {
    return 0;
  }

  return parseInt(result.rows[0].alsol_balance, 10) / 1_000_000_000; // Convert lamports to SOL
}

/**
 * Credit player with alSOL (for SOL or LKC purchases)
 */
export async function creditPlayerAlSOL(
  playerId: string,
  amountLamports: number
): Promise<number> {
  const result = await pool.query(
    `INSERT INTO player_balances (player_id, alsol_balance)
     VALUES ($1, $2)
     ON CONFLICT (player_id)
     DO UPDATE SET alsol_balance = player_balances.alsol_balance + $2
     RETURNING alsol_balance`,
    [playerId, amountLamports]
  );

  const newBalance = parseInt(result.rows[0].alsol_balance, 10);

  logger.info(`💰 Credited ${amountLamports / 1_000_000_000} alSOL to ${playerId}`);

  return newBalance / 1_000_000_000; // Return in SOL units
}

/**
 * Debit player's alSOL (for element registration, etc.)
 */
export async function debitPlayerAlSOL(
  playerId: string,
  amountLamports: number
): Promise<number> {
  const result = await pool.query(
    `UPDATE player_balances
     SET alsol_balance = alsol_balance - $1
     WHERE player_id = $2
     RETURNING alsol_balance`,
    [amountLamports, playerId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Player ${playerId} not found`);
  }

  const newBalance = parseInt(result.rows[0].alsol_balance, 10);

  if (newBalance < 0) {
    // Rollback
    await pool.query(
      `UPDATE player_balances
       SET alsol_balance = alsol_balance + $1
       WHERE player_id = $2`,
      [amountLamports, playerId]
    );

    throw new Error('Insufficient alSOL balance');
  }

  logger.info(`💸 Debited ${amountLamports / 1_000_000_000} alSOL from ${playerId}`);

  return newBalance / 1_000_000_000;
}

/**
 * Get element data (wild spawns, capacity, etc.)
 */
export async function getElementData(elementId: string) {
  const result = await pool.query(
    `SELECT * FROM element_data WHERE element_id = $1`,
    [elementId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
}

/**
 * Initialize database connection and test
 */
export async function initializeDatabase(): Promise<void> {
  try {
    const result = await pool.query('SELECT NOW()');
    logger.info(`✅ Database connected successfully: ${result.rows[0].now}`);
  } catch (error) {
    logger.error('❌ Database connection failed:', error);
    throw error;
  }
}

/**
 * Close database connection (for graceful shutdown)
 */
export async function closeDatabaseConnection(): Promise<void> {
  await pool.end();
  logger.info('Database connection closed');
}

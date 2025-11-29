/**
 * Chemistry System Database Queries
 *
 * Handles all chemistry-related database operations:
 * - Elements, compounds, reactions
 * - Player inventory management
 * - Reaction processing with probabilistic outcomes
 * - Discovery tracking
 */

import { pool } from './queries';
import { logger } from '../utils/logger';

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

export interface Element {
  id: string;
  name: string;
  symbol: string;
  rarity: string;
  unlock_method: string;
  base_energy_cost: number;
  atomic_number: number;
  description: string;
}

export interface Compound {
  id: string;
  name: string;
  chemical_formula: string;
  category: string;
  base_value: number;
  rarity: string;
  description: string;
  real_world_uses: string;
}

export interface Reaction {
  id: number;
  reaction_name: string;
  reaction_type: string;
  energy_cost: number;
  success_rate: number;
  inputs: Array<{ type: string; id: string; amount: number }>;
  outputs: Array<{ type: string; id: string; amount: number }>;
  unlocked_by_default: boolean;
  discovery_bonus: boolean;
}

export interface InventoryItem {
  player_wallet: string;
  item_type: string;
  item_id: string;
  amount: number;
  total_created: number;
}

export interface ReactionResult {
  success: boolean;
  reaction_id: number;
  reaction_name: string;
  energy_spent: number;
  inputs_consumed: Array<{ type: string; id: string; amount: number }>;
  outputs_created?: Array<{ type: string; id: string; amount: number }>;
  discovery?: {
    first_discovery: boolean;
    compound_id: string;
    tax_free_until: Date;
  };
}

// ============================================================================
// ELEMENT QUERIES
// ============================================================================

/**
 * Get all elements
 */
export async function getAllElements(): Promise<Element[]> {
  const result = await pool.query(
    'SELECT * FROM elements ORDER BY rarity, name'
  );
  return result.rows;
}

/**
 * Get element by ID
 */
export async function getElementById(elementId: string): Promise<Element | null> {
  const result = await pool.query(
    'SELECT * FROM elements WHERE id = $1',
    [elementId]
  );
  return result.rows[0] || null;
}

// ============================================================================
// COMPOUND QUERIES
// ============================================================================

/**
 * Get all compounds
 */
export async function getAllCompounds(): Promise<Compound[]> {
  const result = await pool.query(
    'SELECT * FROM compounds ORDER BY category, rarity, name'
  );
  return result.rows;
}

/**
 * Get compound by ID
 */
export async function getCompoundById(compoundId: string): Promise<Compound | null> {
  const result = await pool.query(
    'SELECT * FROM compounds WHERE id = $1',
    [compoundId]
  );
  return result.rows[0] || null;
}

// ============================================================================
// REACTION QUERIES
// ============================================================================

/**
 * Get all reactions (or filter by type)
 */
export async function getAllReactions(reactionType?: string): Promise<Reaction[]> {
  let query = 'SELECT * FROM reactions';
  const params: string[] = [];

  if (reactionType) {
    query += ' WHERE reaction_type = $1';
    params.push(reactionType);
  }

  query += ' ORDER BY reaction_type, energy_cost';

  const result = await pool.query(query, params);
  return result.rows;
}

/**
 * Get reaction by ID
 */
export async function getReactionById(reactionId: number): Promise<Reaction | null> {
  const result = await pool.query(
    'SELECT * FROM reactions WHERE id = $1',
    [reactionId]
  );
  return result.rows[0] || null;
}

/**
 * Get reactions with matching inputs (for discovery)
 */
export async function getReactionsByInputs(
  inputs: Array<{ type: string; id: string; amount: number }>
): Promise<Reaction[]> {
  // Find reactions where the inputs match
  const result = await pool.query(
    `SELECT * FROM reactions
     WHERE inputs = $1::jsonb
     ORDER BY success_rate DESC`,
    [JSON.stringify(inputs)]
  );
  return result.rows;
}

// ============================================================================
// INVENTORY QUERIES
// ============================================================================

/**
 * Get player's full inventory
 */
export async function getPlayerFullInventory(
  playerWallet: string
): Promise<InventoryItem[]> {
  const result = await pool.query(
    `SELECT * FROM player_inventory
     WHERE player_wallet = $1 AND amount > 0
     ORDER BY item_type, item_id`,
    [playerWallet]
  );
  return result.rows;
}

/**
 * Get specific inventory item amount
 */
export async function getInventoryAmount(
  playerWallet: string,
  itemType: string,
  itemId: string
): Promise<number> {
  const result = await pool.query(
    `SELECT amount FROM player_inventory
     WHERE player_wallet = $1 AND item_type = $2 AND item_id = $3`,
    [playerWallet, itemType, itemId]
  );

  if (result.rows.length === 0) {
    return 0;
  }

  return parseFloat(result.rows[0].amount);
}

/**
 * Add items to player inventory
 */
export async function addToInventory(
  playerWallet: string,
  itemType: string,
  itemId: string,
  amount: number
): Promise<void> {
  await pool.query(
    `INSERT INTO player_inventory (player_wallet, item_type, item_id, amount, total_created)
     VALUES ($1, $2, $3, $4, $4)
     ON CONFLICT (player_wallet, item_type, item_id)
     DO UPDATE SET
       amount = player_inventory.amount + $4,
       total_created = player_inventory.total_created + $4,
       last_updated = CURRENT_TIMESTAMP`,
    [playerWallet, itemType, itemId, amount]
  );

  logger.info(`➕ Added ${amount} ${itemId} (${itemType}) to ${playerWallet}`);
}

/**
 * Remove items from player inventory
 */
export async function removeFromInventory(
  playerWallet: string,
  itemType: string,
  itemId: string,
  amount: number
): Promise<boolean> {
  const result = await pool.query(
    `UPDATE player_inventory
     SET amount = amount - $4, last_updated = CURRENT_TIMESTAMP
     WHERE player_wallet = $1 AND item_type = $2 AND item_id = $3 AND amount >= $4
     RETURNING amount`,
    [playerWallet, itemType, itemId, amount]
  );

  if (result.rows.length === 0) {
    logger.warn(`⚠️ Insufficient ${itemId} for ${playerWallet}`);
    return false;
  }

  logger.info(`➖ Removed ${amount} ${itemId} (${itemType}) from ${playerWallet}`);
  return true;
}

// ============================================================================
// PLAYER UNLOCKS
// ============================================================================

/**
 * Check if player has unlocked an element/compound/reaction
 */
export async function hasPlayerUnlocked(
  playerWallet: string,
  unlockType: string,
  unlockId: string
): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM player_unlocks
     WHERE player_wallet = $1 AND unlock_type = $2 AND unlock_id = $3`,
    [playerWallet, unlockType, unlockId]
  );
  return result.rows.length > 0;
}

/**
 * Unlock element/compound/reaction for player
 */
export async function unlockForPlayer(
  playerWallet: string,
  unlockType: string,
  unlockId: string,
  unlockMethod?: string
): Promise<void> {
  await pool.query(
    `INSERT INTO player_unlocks (player_wallet, unlock_type, unlock_id, unlock_method)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (player_wallet, unlock_type, unlock_id) DO NOTHING`,
    [playerWallet, unlockType, unlockId, unlockMethod || 'unknown']
  );

  logger.info(`🔓 ${playerWallet} unlocked ${unlockType}: ${unlockId}`);
}

/**
 * Get all player unlocks
 */
export async function getPlayerUnlocks(
  playerWallet: string,
  unlockType?: string
): Promise<any[]> {
  let query = 'SELECT * FROM player_unlocks WHERE player_wallet = $1';
  const params: any[] = [playerWallet];

  if (unlockType) {
    query += ' AND unlock_type = $2';
    params.push(unlockType);
  }

  query += ' ORDER BY unlocked_at DESC';

  const result = await pool.query(query, params);
  return result.rows;
}

// ============================================================================
// DISCOVERY SYSTEM
// ============================================================================

/**
 * Check if compound has been discovered globally
 */
export async function hasBeenDiscovered(compoundId: string): Promise<boolean> {
  const result = await pool.query(
    'SELECT 1 FROM discoveries WHERE compound_id = $1',
    [compoundId]
  );
  return result.rows.length > 0;
}

/**
 * Record first discovery of a compound
 */
export async function recordDiscovery(
  reactionId: number,
  compoundId: string,
  discovererWallet: string,
  blockchainTx?: string
): Promise<void> {
  const taxFreeUntil = new Date();
  taxFreeUntil.setHours(taxFreeUntil.getHours() + 72); // 72 hours from now

  await pool.query(
    `INSERT INTO discoveries (reaction_id, compound_id, discoverer_wallet, blockchain_tx, tax_free_until)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (compound_id) DO NOTHING`,
    [reactionId, compoundId, discovererWallet, blockchainTx, taxFreeUntil]
  );

  logger.info(`🎉 FIRST DISCOVERY! ${discovererWallet} discovered ${compoundId}`);
}

/**
 * Get discovery info for a compound
 */
export async function getDiscoveryInfo(compoundId: string): Promise<any | null> {
  const result = await pool.query(
    'SELECT * FROM discoveries WHERE compound_id = $1',
    [compoundId]
  );
  return result.rows[0] || null;
}

// ============================================================================
// REACTION PROCESSING
// ============================================================================

/**
 * Perform a reaction
 * Handles probabilistic outcomes, inventory management, energy consumption, and discovery bonuses
 */
export async function performReaction(
  playerWallet: string,
  reactionId: number
): Promise<ReactionResult> {
  // Get reaction details
  const reaction = await getReactionById(reactionId);
  if (!reaction) {
    throw new Error(`Reaction ${reactionId} not found`);
  }

  // Check and consume energy FIRST (before checking materials)
  const { consumePlayerEnergy } = await import('./energy-queries');
  const energyResult = await consumePlayerEnergy(playerWallet, reaction.energy_cost);

  if (!energyResult.success) {
    throw new Error(energyResult.message);
  }

  // Check if player has enough ingredients
  for (const input of reaction.inputs) {
    const amount = await getInventoryAmount(playerWallet, input.type, input.id);
    if (amount < input.amount) {
      throw new Error(`Insufficient ${input.id}: need ${input.amount}, have ${amount}`);
    }
  }

  // Roll for success
  const roll = Math.random();
  const success = roll < reaction.success_rate;

  // Consume inputs
  for (const input of reaction.inputs) {
    await removeFromInventory(playerWallet, input.type, input.id, input.amount);
  }

  // Log reaction attempt
  await pool.query(
    `INSERT INTO reaction_history
     (player_wallet, reaction_id, success, energy_spent, inputs_consumed, outputs_created)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [
      playerWallet,
      reactionId,
      success,
      reaction.energy_cost,
      JSON.stringify(reaction.inputs),
      success ? JSON.stringify(reaction.outputs) : null,
    ]
  );

  const result: ReactionResult = {
    success,
    reaction_id: reactionId,
    reaction_name: reaction.reaction_name,
    energy_spent: reaction.energy_cost,
    inputs_consumed: reaction.inputs,
  };

  // If successful, add outputs
  if (success) {
    result.outputs_created = reaction.outputs;

    for (const output of reaction.outputs) {
      await addToInventory(playerWallet, output.type, output.id, output.amount);

      // Unlock the item for player
      await unlockForPlayer(playerWallet, output.type, output.id, 'reaction');

      // Check for first discovery (only for compounds)
      if (output.type === 'compound' && reaction.discovery_bonus) {
        const discovered = await hasBeenDiscovered(output.id);
        if (!discovered) {
          await recordDiscovery(reactionId, output.id, playerWallet);
          const taxFreeUntil = new Date();
          taxFreeUntil.setHours(taxFreeUntil.getHours() + 72);

          result.discovery = {
            first_discovery: true,
            compound_id: output.id,
            tax_free_until: taxFreeUntil,
          };
        }
      }
    }
  }

  return result;
}

/**
 * Get reaction history for a player
 */
export async function getReactionHistory(
  playerWallet: string,
  limit: number = 50
): Promise<any[]> {
  const result = await pool.query(
    `SELECT rh.*, r.reaction_name, r.reaction_type
     FROM reaction_history rh
     JOIN reactions r ON rh.reaction_id = r.id
     WHERE rh.player_wallet = $1
     ORDER BY rh.created_at DESC
     LIMIT $2`,
    [playerWallet, limit]
  );
  return result.rows;
}

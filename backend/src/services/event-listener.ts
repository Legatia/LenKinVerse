/**
 * Event Listener Service
 *
 * Listens for BridgedToIngame events from treasury_bridge program
 * Credits wild_spawns when governor burns SPL tokens
 */

import { Connection, PublicKey, LogsFilter } from '@solana/web3.js';
import { Program, AnchorProvider, Wallet } from '@coral-xyz/anchor';
import { updateWildSpawns, logBridgeEvent } from '../db/queries';
import { logger } from '../utils/logger';

const TREASURY_BRIDGE_PROGRAM_ID = new PublicKey(
  process.env.TREASURY_BRIDGE_PROGRAM_ID || 'BrdgPYm3GvXFTEHhgN2YXg5WqV9gLBYL7hdYbkBhxA1'
);

const MAX_WILD_SPAWNS_CAPACITY = 500_000; // Per element

interface BridgedToIngameEvent {
  element_id: string;
  amount: number;
  governor: string;
}

/**
 * Start listening for BridgedToIngame events
 */
export async function startEventListener() {
  const connection = new Connection(
    process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com',
    {
      commitment: 'confirmed',
      wsEndpoint: process.env.SOLANA_WS_URL,
    }
  );

  logger.info(`🎧 Starting event listener for program: ${TREASURY_BRIDGE_PROGRAM_ID.toBase58()}`);

  // Subscribe to program logs
  const subscriptionId = connection.onLogs(
    TREASURY_BRIDGE_PROGRAM_ID,
    async (logs, context) => {
      try {
        // Parse logs for BridgedToIngame event
        const event = parseEventFromLogs(logs.logs, 'BridgedToIngame');

        if (event) {
          logger.info(`🌉 BridgedToIngame event detected:`, event);
          await handleBridgedToIngame(event, logs.signature);
        }
      } catch (error) {
        logger.error('Error handling log:', error);
      }
    },
    'confirmed'
  );

  logger.info(`✅ Event listener started, subscription ID: ${subscriptionId}`);

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    logger.info('Shutting down event listener...');
    connection.removeOnLogsListener(subscriptionId);
    process.exit(0);
  });

  // Keep process alive
  await new Promise(() => {});
}

/**
 * Parse event data from transaction logs
 */
function parseEventFromLogs(logs: string[], eventName: string): BridgedToIngameEvent | null {
  // Anchor events are emitted in logs with format:
  // "Program log: EVENT: <event_name> <base64_data>"

  for (const log of logs) {
    if (log.includes(`Program data:`)) {
      // Try to parse as Anchor event
      try {
        // Example log format from Anchor:
        // "Program data: <base64_encoded_event_data>"

        // For now, we'll parse from plain text logs
        // In production, decode the base64 data properly

        if (log.includes(eventName)) {
          // Simple parsing (improve with proper Anchor event decoding)
          return parseEventDataSimple(logs);
        }
      } catch (error) {
        logger.debug('Failed to parse log:', log);
      }
    }
  }

  return null;
}

/**
 * Simple event parsing from logs (temporary implementation)
 * TODO: Implement proper Anchor event decoding
 */
function parseEventDataSimple(logs: string[]): BridgedToIngameEvent | null {
  // Look for msg! logs that contain event data
  // Format: "Program log: Burned X tokens, bridging to in-game"

  const burnedLog = logs.find((log) => log.includes('Burned') && log.includes('tokens'));

  if (burnedLog) {
    // Extract amount from log
    // Example: "Program log: Burned 1000 tokens, bridging to in-game"
    const amountMatch = burnedLog.match(/Burned (\d+) tokens/);

    if (amountMatch) {
      const amount = parseInt(amountMatch[1], 10);

      // Find element_id and governor from other logs
      // This is a simplified approach - in production, decode event data properly

      return {
        element_id: 'lkC', // TODO: Extract from event data
        amount,
        governor: '7xKXtg3xR...abc', // TODO: Extract from event data
      };
    }
  }

  return null;
}

/**
 * Handle BridgedToIngame event - credit wild_spawns
 */
async function handleBridgedToIngame(event: BridgedToIngameEvent, signature: string) {
  const { element_id, amount, governor } = event;

  logger.info(
    `📥 Processing bridge to in-game: ${amount} ${element_id} from ${governor}`
  );

  try {
    // 1. Check capacity constraints
    const canAdd = await checkWildSpawnsCapacity(element_id, amount);

    if (!canAdd) {
      logger.error(
        `❌ Cannot add to wild spawns: would exceed capacity (max ${MAX_WILD_SPAWNS_CAPACITY})`
      );
      return;
    }

    // 2. Add to wild spawns
    await updateWildSpawns(element_id, amount);

    logger.info(`✅ Added ${amount} ${element_id} to wild spawns`);

    // 3. Log bridge event for history
    await logBridgeEvent({
      element_id,
      direction: 'to_ingame',
      amount,
      player_or_governor: governor,
      transaction_signature: signature,
    });

    logger.info(`📝 Bridge event logged: ${signature}`);
  } catch (error) {
    logger.error('Failed to handle BridgedToIngame event:', error);
  }
}

/**
 * Check if adding to wild spawns would exceed capacity
 */
async function checkWildSpawnsCapacity(
  elementId: string,
  amountToAdd: number
): Promise<boolean> {
  // TODO: Query database for current totals
  // const currentData = await getElementData(elementId);
  // const totalInGame = currentData.wild_spawns + currentData.player_inventories + currentData.game_treasury;

  // For now, allow (implement proper check in DB queries)
  return true;
}

// Run if called directly
if (require.main === module) {
  startEventListener().catch((error) => {
    logger.error('Event listener crashed:', error);
    process.exit(1);
  });
}

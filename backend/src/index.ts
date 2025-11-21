/**
 * ReAgenyx Backend Server
 *
 * Main entry point - starts API server and event listener
 */

import dotenv from 'dotenv';
import { initializeBurnProofAuthority } from './services/burn-proof-signer';
import { startEventListener } from './services/event-listener';
import { startAPIServer } from './api/server';
import { initializeDatabase, closeDatabaseConnection } from './db/queries';
import { logger } from './utils/logger';

// Load environment variables
dotenv.config();

async function main() {
  try {
    logger.info('🚀 Starting ReAgenyx Backend...');

    // 1. Initialize database connection
    await initializeDatabase();

    // 2. Initialize burn proof authority
    const secretKeyString = process.env.BURN_PROOF_AUTHORITY_SECRET_KEY;

    if (!secretKeyString) {
      throw new Error('BURN_PROOF_AUTHORITY_SECRET_KEY not set in environment');
    }

    const secretKeyArray = JSON.parse(secretKeyString);
    initializeBurnProofAuthority(secretKeyArray);

    // 3. Start API server
    const port = parseInt(process.env.PORT || '3000');
    startAPIServer(port);

    // 4. Start event listener (in background)
    if (process.env.START_EVENT_LISTENER !== 'false') {
      logger.info('🎧 Starting event listener in background...');
      startEventListener().catch((error) => {
        logger.error('Event listener error:', error);
      });
    }

    logger.info('✅ ReAgenyx Backend started successfully');

    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      logger.info('Shutting down...');
      await closeDatabaseConnection();
      process.exit(0);
    });
  } catch (error) {
    logger.error('Failed to start backend:', error);
    process.exit(1);
  }
}

main();

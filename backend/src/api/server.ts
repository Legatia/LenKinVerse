/**
 * REST API Server
 *
 * Provides endpoints for Godot mobile app to interact with Solana blockchain
 */

import express, { Request, Response } from 'express';
import cors from 'cors';
import { signBurnProof, getBurnProofAuthorityPublicKey } from '../services/burn-proof-signer';
import {
  getPlayerInventory,
  getPlayerAlSOLBalance,
  creditPlayerAlSOL,
  debitPlayerAlSOL,
} from '../db/queries';
import { logger } from '../utils/logger';

const app = express();

// Middleware
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

/**
 * Health check endpoint
 */
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    burn_proof_authority: getBurnProofAuthorityPublicKey(),
  });
});

/**
 * POST /api/burn-proof
 * Generate burn proof for player bridging
 */
app.post('/api/burn-proof', async (req: Request, res: Response) => {
  try {
    const { player_wallet, element_id, amount, player_id } = req.body;

    // Validation
    if (!player_wallet || !element_id || !amount) {
      return res.status(400).json({
        error: 'Missing required fields: player_wallet, element_id, amount',
      });
    }

    if (amount <= 0) {
      return res.status(400).json({
        error: 'Amount must be greater than 0',
      });
    }

    // Generate and sign burn proof
    const proof = await signBurnProof(player_wallet, element_id, amount);

    res.json({
      ...proof,
      success: true,
      message: `Burn proof generated for ${amount} ${element_id}`,
    });
  } catch (error) {
    logger.error('Burn proof error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Internal server error',
      success: false,
    });
  }
});

/**
 * GET /api/player-balance
 * Get player's in-game balances
 */
app.get('/api/player-balance', async (req: Request, res: Response) => {
  try {
    const { player_id } = req.query;

    if (!player_id) {
      return res.status(400).json({
        error: 'Missing required parameter: player_id',
      });
    }

    const alsolBalance = await getPlayerAlSOLBalance(player_id as string);

    // TODO: Get element balances
    const elements = {
      lkC: 0,
      lkO: 0,
      lkH: 0,
    };

    res.json({
      alsol: alsolBalance,
      lkc: 0, // TODO: Get from database
      elements,
      inventory_capacity: 1000,
    });
  } catch (error) {
    logger.error('Get balance error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/buy-alsol
 * Buy alSOL with SOL or LKC
 */
app.post('/api/buy-alsol', async (req: Request, res: Response) => {
  try {
    const { player_id, payment_type, amount, transaction_signature } = req.body;

    if (!player_id || !payment_type || !amount) {
      return res.status(400).json({
        error: 'Missing required fields: player_id, payment_type, amount',
      });
    }

    if (payment_type === 'sol') {
      // SOL → alSOL: Verify transaction, then credit
      // TODO: Verify transaction on-chain

      if (!transaction_signature) {
        return res.status(400).json({
          error: 'transaction_signature required for SOL payment',
        });
      }

      // Credit alSOL (1:1 ratio)
      const amountLamports = Math.floor(amount * 1_000_000_000);
      const newBalance = await creditPlayerAlSOL(player_id, amountLamports);

      res.json({
        alsol_received: amount,
        new_balance: newBalance,
        payment_type: 'sol',
        success: true,
      });
    } else if (payment_type === 'lkc') {
      // LKC → alSOL: Check weekly limit, burn LKC, credit alSOL
      // TODO: Implement LKC weekly limit check
      // TODO: Burn LKC from player inventory

      // 1M LKC = 0.001 alSOL
      const alsolAmount = amount / 1_000_000;
      const amountLamports = Math.floor(alsolAmount * 1_000_000_000);

      const newBalance = await creditPlayerAlSOL(player_id, amountLamports);

      res.json({
        alsol_received: alsolAmount,
        new_balance: newBalance,
        payment_type: 'lkc',
        weekly_limit_remaining: 1.0, // TODO: Calculate from database
        success: true,
      });
    } else {
      return res.status(400).json({
        error: 'Invalid payment_type, must be "sol" or "lkc"',
      });
    }
  } catch (error) {
    logger.error('Buy alSOL error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * POST /api/send-transaction
 * Submit signed transaction to Solana
 */
app.post('/api/send-transaction', async (req: Request, res: Response) => {
  try {
    const { signed_transaction, instruction_type } = req.body;

    if (!signed_transaction || !instruction_type) {
      return res.status(400).json({
        error: 'Missing required fields: signed_transaction, instruction_type',
      });
    }

    // TODO: Decode and send transaction to Solana
    // TODO: Wait for confirmation
    // TODO: Return transaction signature

    res.json({
      signature: '5j7s8k9d...mock',
      status: 'confirmed',
      slot: 123456789,
      message: 'Transaction submitted (mock implementation)',
    });
  } catch (error) {
    logger.error('Send transaction error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * GET /api/element-prices
 * Get element prices from oracle
 */
app.get('/api/element-prices', async (req: Request, res: Response) => {
  try {
    const { elements } = req.query;

    if (!elements) {
      return res.status(400).json({
        error: 'Missing required parameter: elements',
      });
    }

    // TODO: Query price oracle on-chain

    const elementList = (elements as string).split(',');
    const prices: Record<string, any> = {};

    for (const element of elementList) {
      prices[element] = {
        price_sol: 0.00001,
        last_updated: Math.floor(Date.now() / 1000),
      };
    }

    res.json(prices);
  } catch (error) {
    logger.error('Get prices error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
});

/**
 * Error handler
 */
app.use((err: Error, req: Request, res: Response, next: any) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message,
  });
});

export function startAPIServer(port: number = 3000) {
  app.listen(port, () => {
    logger.info(`🚀 API server listening on port ${port}`);
  });
}

export default app;

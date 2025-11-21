/**
 * Burn Proof Signer Service
 *
 * Signs burn proofs for bridge operations
 * CRITICAL: Must burn in-game DATA before signing!
 */

import { Keypair, PublicKey } from '@solana/web3.js';
import * as ed25519 from '@noble/ed25519';
import * as borsh from 'borsh';
import { getPlayerInventory, burnPlayerInventory } from '../db/queries';
import { logger } from '../utils/logger';

// Backend authority keypair (loaded from env)
let BURN_PROOF_AUTHORITY: Keypair;

export function initializeBurnProofAuthority(secretKeyArray: number[]) {
  BURN_PROOF_AUTHORITY = Keypair.fromSecretKey(new Uint8Array(secretKeyArray));
  logger.info(`🔐 Burn proof authority initialized: ${BURN_PROOF_AUTHORITY.publicKey.toBase58()}`);
}

/**
 * Burn Proof struct (must match Rust definition in treasury_bridge)
 */
class BurnProof {
  element_id: string;
  amount: bigint;
  governor: Uint8Array; // Actually 'player' but contract uses 'governor' field name
  timestamp: bigint;

  constructor(elementId: string, amount: bigint, player: Uint8Array, timestamp: bigint) {
    this.element_id = elementId;
    this.amount = amount;
    this.governor = player;
    this.timestamp = timestamp;
  }
}

/**
 * Borsh schema for BurnProof serialization
 */
const BURN_PROOF_SCHEMA = new Map([
  [
    BurnProof,
    {
      kind: 'struct',
      fields: [
        ['element_id', 'string'],
        ['amount', 'u64'],
        ['governor', [32]], // 32-byte Pubkey
        ['timestamp', 'i64'],
      ],
    },
  ],
]);

/**
 * Generate and sign a burn proof for player bridging
 *
 * @param playerWallet - Player's Solana wallet address
 * @param elementId - Element to bridge (e.g., "lkC")
 * @param amount - Amount to bridge (in tokens, not lamports)
 * @returns Signature (64 bytes) and timestamp
 */
export async function signBurnProof(
  playerWallet: string,
  elementId: string,
  amount: number
): Promise<{
  signature: number[];
  timestamp: number;
}> {
  logger.info(`🔥 Burn proof request: ${playerWallet} → ${amount} ${elementId}`);

  // 1. Verify player owns this amount in-game
  const playerInventory = await getPlayerInventory(playerWallet, elementId);

  if (playerInventory < amount) {
    throw new Error(
      `Insufficient in-game balance: has ${playerInventory}, needs ${amount} ${elementId}`
    );
  }

  // 2. CRITICAL: Burn in-game DATA before signing
  // This prevents double-spending
  await burnPlayerInventory(playerWallet, elementId, amount);

  logger.warn(`🔥 BURNED ${amount} ${elementId} from ${playerWallet} (in-game DATA deleted)`);

  // 3. Create burn proof struct
  const timestamp = BigInt(Math.floor(Date.now() / 1000));

  const proof = new BurnProof(
    elementId,
    BigInt(amount),
    new PublicKey(playerWallet).toBytes(),
    timestamp
  );

  // 4. Serialize proof data using Borsh (must match Rust struct)
  const serialized = borsh.serialize(BURN_PROOF_SCHEMA, proof);

  logger.debug(`📦 Serialized burn proof: ${Buffer.from(serialized).toString('hex')}`);

  // 5. Sign with backend authority's private key
  const signature = await ed25519.sign(
    serialized,
    BURN_PROOF_AUTHORITY.secretKey.slice(0, 32) // ed25519 uses first 32 bytes
  );

  logger.info(`✅ Burn proof signed for ${playerWallet}`);

  // Return signature as array of numbers (for Godot compatibility)
  return {
    signature: Array.from(signature),
    timestamp: Number(timestamp),
  };
}

/**
 * Verify a burn proof signature (for testing)
 */
export async function verifyBurnProof(
  elementId: string,
  amount: number,
  playerWallet: string,
  timestamp: number,
  signature: Uint8Array
): Promise<boolean> {
  const proof = new BurnProof(
    elementId,
    BigInt(amount),
    new PublicKey(playerWallet).toBytes(),
    BigInt(timestamp)
  );

  const serialized = borsh.serialize(BURN_PROOF_SCHEMA, proof);

  const isValid = await ed25519.verify(
    signature,
    serialized,
    BURN_PROOF_AUTHORITY.publicKey.toBytes()
  );

  return isValid;
}

/**
 * Get backend authority public key (for program initialization)
 */
export function getBurnProofAuthorityPublicKey(): string {
  if (!BURN_PROOF_AUTHORITY) {
    throw new Error('Burn proof authority not initialized');
  }
  return BURN_PROOF_AUTHORITY.publicKey.toBase58();
}

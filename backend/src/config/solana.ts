import { PublicKey, Connection, Keypair, Cluster } from '@solana/web3.js';
import fs from 'fs';
import { logger } from '../utils/logger';

// Solana configuration for ReAgenyx programs
export interface SolanaConfig {
  cluster: Cluster;
  rpcUrl: string;
  connection: Connection;
  authority: Keypair;
  programs: {
    element_token_factory: PublicKey;
    item_marketplace: PublicKey;
    price_oracle: PublicKey;
    treasury_bridge: PublicKey;
  };
}

// Devnet configuration (current deployment)
const DEVNET_CONFIG = {
  cluster: 'devnet' as Cluster,
  rpcUrl: process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com',
  programs: {
    element_token_factory: 'D32BEf4TnLFBtoM1Z2smXY33MxGLT3HJZBGYNfenF7kA',
    item_marketplace: '4HvxXhE94xfP3viSZYWyyeuGJGNUH1oHpNF3cLCvWfvt',
    price_oracle: '5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz',
    treasury_bridge: '8h1aAT9QtnVB1jZWQ3ZuiLdp2KZkyV3xUJQUxSVsQ9Bb',
  },
};

// Mainnet configuration (when ready for production)
const MAINNET_CONFIG = {
  cluster: 'mainnet-beta' as Cluster,
  rpcUrl: process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
  programs: {
    element_token_factory: 'PLACEHOLDER', // Deploy to mainnet later
    item_marketplace: 'PLACEHOLDER',
    price_oracle: 'PLACEHOLDER',
    treasury_bridge: 'PLACEHOLDER',
  },
};

// Load authority keypair from file
function loadAuthorityKeypair(): Keypair {
  const keypairPath =
    process.env.SOLANA_AUTHORITY_KEYPAIR || `${process.env.HOME}/.config/solana/id.json`;

  try {
    const keypairData = JSON.parse(fs.readFileSync(keypairPath, 'utf-8'));
    return Keypair.fromSecretKey(new Uint8Array(keypairData));
  } catch (error) {
    logger.error(`Failed to load Solana authority keypair from ${keypairPath}:`, error);
    throw new Error(`Solana authority keypair not found at ${keypairPath}`);
  }
}

// Initialize Solana configuration
export function initSolanaConfig(): SolanaConfig {
  const env = process.env.NODE_ENV || 'development';
  const useMainnet = process.env.SOLANA_CLUSTER === 'mainnet';

  const config = useMainnet ? MAINNET_CONFIG : DEVNET_CONFIG;

  const connection = new Connection(config.rpcUrl, 'confirmed');
  const authority = loadAuthorityKeypair();

  logger.info(`🔗 Solana connection initialized: ${config.cluster}`);
  logger.info(`🔑 Authority public key: ${authority.publicKey.toString()}`);

  return {
    cluster: config.cluster,
    rpcUrl: config.rpcUrl,
    connection,
    authority,
    programs: {
      element_token_factory: new PublicKey(config.programs.element_token_factory),
      item_marketplace: new PublicKey(config.programs.item_marketplace),
      price_oracle: new PublicKey(config.programs.price_oracle),
      treasury_bridge: new PublicKey(config.programs.treasury_bridge),
    },
  };
}

// Singleton instance
let solanaConfigInstance: SolanaConfig | null = null;

export function getSolanaConfig(): SolanaConfig {
  if (!solanaConfigInstance) {
    solanaConfigInstance = initSolanaConfig();
  }
  return solanaConfigInstance;
}

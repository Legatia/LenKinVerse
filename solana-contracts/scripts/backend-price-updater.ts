/**
 * Backend Price Updater Service
 *
 * This script demonstrates how to run a backend service that:
 * 1. Monitors LKO price from your AMM pool or fixed formula
 * 2. Updates the on-chain oracle every 60 seconds or when price changes >1%
 * 3. Logs all updates for transparency
 *
 * Usage:
 *   ts-node scripts/backend-price-updater.ts
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import { PriceOracle } from "../target/types/price_oracle";
import fs from "fs";

// Configuration
const RPC_URL = process.env.RPC_URL || "https://api.devnet.solana.com";
const AUTHORITY_KEYPAIR_PATH = process.env.AUTHORITY_KEYPAIR || "~/.config/solana/id.json";
const UPDATE_INTERVAL_MS = 60_000; // 60 seconds
const PRICE_CHANGE_THRESHOLD = 0.01; // 1%

// Oracle PDA
const ORACLE_SEED = "price_oracle";

class PriceUpdaterService {
  private connection: Connection;
  private program: Program<PriceOracle>;
  private authority: Keypair;
  private oraclePda: PublicKey;
  private lastPrice: number = 0;
  private lastUpdate: Date = new Date(0);

  constructor() {
    // Initialize connection
    this.connection = new Connection(RPC_URL, "confirmed");

    // Load authority keypair
    const keypairPath = AUTHORITY_KEYPAIR_PATH.replace("~", process.env.HOME || "");
    const keypairData = JSON.parse(fs.readFileSync(keypairPath, "utf-8"));
    this.authority = Keypair.fromSecretKey(new Uint8Array(keypairData));

    // Initialize Anchor provider
    const provider = new anchor.AnchorProvider(
      this.connection,
      new anchor.Wallet(this.authority),
      { commitment: "confirmed" }
    );
    anchor.setProvider(provider);

    // Load program
    this.program = anchor.workspace.PriceOracle as Program<PriceOracle>;

    // Derive oracle PDA
    [this.oraclePda] = PublicKey.findProgramAddressSync(
      [Buffer.from(ORACLE_SEED)],
      this.program.programId
    );

    console.log("🔧 Price Updater Service Initialized");
    console.log("   Authority:", this.authority.publicKey.toString());
    console.log("   Oracle PDA:", this.oraclePda.toString());
    console.log("   RPC URL:", RPC_URL);
  }

  /**
   * Calculate LKO/SOL price
   *
   * OPTION 1: Fixed formula (for bootstrap phase)
   * OPTION 2: Read from AMM pool (Raydium/Orca)
   * OPTION 3: TWAP from multiple pools
   */
  private async calculateLkoPrice(): Promise<number> {
    // OPTION 1: Fixed formula (simple MVP)
    // Example: 1 SOL = 1000 LKO (with 9 decimals)
    const lkoPerSol = 1000 * 1e9; // 1000 LKO = 1 SOL

    // TODO: OPTION 2 - Read from DEX pool
    // const poolReserves = await this.getPoolReserves();
    // const lkoPerSol = (poolReserves.sol * 1e9) / poolReserves.lko;

    // TODO: OPTION 3 - TWAP from multiple sources
    // const prices = await Promise.all([
    //   this.getRadiumPrice(),
    //   this.getOrcaPrice(),
    // ]);
    // const lkoPerSol = prices.reduce((a, b) => a + b) / prices.length;

    return lkoPerSol;
  }

  /**
   * Get current on-chain oracle price
   */
  private async getOraclePrice(): Promise<number> {
    try {
      const oracleAccount = await this.program.account.priceOracle.fetch(this.oraclePda);
      return oracleAccount.lkoPerSol.toNumber();
    } catch (err) {
      console.error("❌ Failed to fetch oracle price:", err);
      return 0;
    }
  }

  /**
   * Update on-chain oracle price
   */
  private async updateOraclePrice(newPrice: number): Promise<boolean> {
    try {
      const tx = await this.program.methods
        .updatePrice(new anchor.BN(newPrice))
        .accounts({
          oracle: this.oraclePda,
          authority: this.authority.publicKey,
        })
        .rpc();

      console.log("✅ Price updated on-chain");
      console.log("   New price:", (newPrice / 1e9).toFixed(2), "LKO/SOL");
      console.log("   Transaction:", tx);

      return true;
    } catch (err) {
      console.error("❌ Failed to update price:", err);
      return false;
    }
  }

  /**
   * Check if price should be updated
   */
  private shouldUpdate(currentPrice: number, newPrice: number): boolean {
    // First update
    if (this.lastPrice === 0) {
      return true;
    }

    // Check price change threshold
    const priceChange = Math.abs((newPrice - currentPrice) / currentPrice);
    if (priceChange >= PRICE_CHANGE_THRESHOLD) {
      console.log(`💡 Price changed by ${(priceChange * 100).toFixed(2)}% - updating...`);
      return true;
    }

    // Check time since last update (max 5 minutes for staleness)
    const timeSinceUpdate = Date.now() - this.lastUpdate.getTime();
    if (timeSinceUpdate >= UPDATE_INTERVAL_MS) {
      console.log("⏰ Time-based update (60s interval)");
      return true;
    }

    return false;
  }

  /**
   * Main update loop
   */
  private async updateLoop() {
    console.log("\n🔄 Checking price...");

    // Get current on-chain price
    const currentPrice = await this.getOraclePrice();
    console.log("   Current oracle price:", (currentPrice / 1e9).toFixed(2), "LKO/SOL");

    // Calculate new price
    const newPrice = await this.calculateLkoPrice();
    console.log("   Calculated price:", (newPrice / 1e9).toFixed(2), "LKO/SOL");

    // Check if update is needed
    if (this.shouldUpdate(currentPrice, newPrice)) {
      const success = await this.updateOraclePrice(newPrice);
      if (success) {
        this.lastPrice = newPrice;
        this.lastUpdate = new Date();
      }
    } else {
      console.log("   No update needed (price stable)");
    }
  }

  /**
   * Start the price updater service
   */
  public async start() {
    console.log("\n🚀 Starting Price Updater Service...\n");

    // Initial price fetch
    this.lastPrice = await this.getOraclePrice();
    this.lastUpdate = new Date();

    // Update loop every 10 seconds
    setInterval(() => {
      this.updateLoop().catch((err) => {
        console.error("❌ Update loop error:", err);
      });
    }, 10_000); // Check every 10 seconds

    // Keep process alive
    process.on("SIGINT", () => {
      console.log("\n👋 Shutting down Price Updater Service...");
      process.exit(0);
    });
  }
}

// Example: Update element-specific price
async function updateElementPrice(
  program: Program<PriceOracle>,
  authority: Keypair,
  elementId: string,
  pricePerSol: number
) {
  const [elementOraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("element_price"), Buffer.from(elementId)],
    program.programId
  );

  const tx = await program.methods
    .updateElementPrice(elementId, new anchor.BN(pricePerSol))
    .accounts({
      elementOracle: elementOraclePda,
      oracle: PublicKey.findProgramAddressSync(
        [Buffer.from("price_oracle")],
        program.programId
      )[0],
      authority: authority.publicKey,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .rpc();

  console.log(`✅ Updated ${elementId} price to ${pricePerSol / 1e9} per SOL`);
  console.log("   Transaction:", tx);
}

// Main entry point
if (require.main === module) {
  const service = new PriceUpdaterService();
  service.start();
}

export { PriceUpdaterService, updateElementPrice };

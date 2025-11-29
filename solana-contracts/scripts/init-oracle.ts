import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PriceOracle } from "../target/types/price_oracle";
import { PublicKey } from "@solana/web3.js";

async function main() {
  // Configure the client to use devnet
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.PriceOracle as Program<PriceOracle>;

  console.log("🔧 Initializing Price Oracle on Devnet...");
  console.log("Program ID:", program.programId.toString());
  console.log("Authority:", provider.wallet.publicKey.toString());

  // Derive the oracle PDA
  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("price_oracle")],
    program.programId
  );

  console.log("Oracle PDA:", oraclePda.toString());

  try {
    // Initialize with initial LKC price: 0.00001 SOL (1e-5)
    // Stored as u64 with 9 decimals: 0.00001 * 1e9 = 10000
    const initialPrice = new anchor.BN(10000); // 0.00001 SOL per LKC

    // Initialize the oracle
    const tx = await program.methods
      .initializeOracle(initialPrice)
      .accounts({
        authority: provider.wallet.publicKey,
      })
      .rpc();

    console.log("✅ Oracle initialized successfully!");
    console.log("Transaction signature:", tx);
    console.log("Explorer:", `https://explorer.solana.com/tx/${tx}?cluster=devnet`);
    console.log("");
    console.log("Oracle PDA:", oraclePda.toString());
    console.log("Authority:", provider.wallet.publicKey.toString());
  } catch (error: any) {
    if (error?.toString().includes("already in use")) {
      console.log("⚠️  Oracle already initialized");
      console.log("Oracle PDA:", oraclePda.toString());
    } else {
      console.error("❌ Error initializing oracle:", error);
      throw error;
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

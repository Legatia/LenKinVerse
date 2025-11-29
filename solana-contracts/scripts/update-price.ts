import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PriceOracle } from "../target/types/price_oracle";
import { PublicKey } from "@solana/web3.js";

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.PriceOracle as Program<PriceOracle>;

  // Get price from command line or use default
  const priceArg = process.argv[2];
  const lkcSolPrice = priceArg ? parseFloat(priceArg) : 0.00001;

  console.log("📊 Updating LKC/SOL Price Oracle...");
  console.log("New price:", lkcSolPrice, "SOL per LKC");

  // Derive the oracle PDA
  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("price_oracle")],
    program.programId
  );

  try {
    // Convert to u64 (multiply by 1e9 for precision)
    const priceU64 = new anchor.BN(lkcSolPrice * 1_000_000_000);

    const tx = await program.methods
      .updatePrice(priceU64)
      .accounts({
        oracle: oraclePda,
        authority: provider.wallet.publicKey,
      })
      .rpc();

    console.log("✅ Price updated successfully!");
    console.log("Transaction signature:", tx);
    console.log("Explorer:", `https://explorer.solana.com/tx/${tx}?cluster=devnet`);
  } catch (error) {
    console.error("❌ Error updating price:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

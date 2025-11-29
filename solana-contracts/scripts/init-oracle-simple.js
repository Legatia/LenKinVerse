const anchor = require("@coral-xyz/anchor");
const {PublicKey} = require("@solana/web3.js");

async function main() {
  // Configure the client to use devnet
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const programId = new PublicKey("5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz");

  console.log("🔧 Initializing Price Oracle on Devnet...");
  console.log("Program ID:", programId.toString());
  console.log("Authority:", provider.wallet.publicKey.toString());

  // Load the IDL
  const idl = require("../target/idl/price_oracle.json");
  const program = new anchor.Program(idl, programId, provider);

  // Derive the oracle PDA
  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("price_oracle")],
    programId
  );

  console.log("Oracle PDA:", oraclePda.toString());

  try {
    // Initialize with initial LKC price: 0.00001 SOL
    // Stored as u64 with 9 decimals: 0.00001 * 1e9 = 10000
    const initialPrice = new anchor.BN(10000);

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
    console.log("Initial Price: 0.00001 SOL per LKC");
  } catch (error) {
    if (error.toString().includes("already in use")) {
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

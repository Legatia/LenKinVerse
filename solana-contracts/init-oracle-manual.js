const { Connection, PublicKey, Keypair, Transaction, SystemProgram, sendAndConfirmTransaction } = require('@solana/web3.js');
const fs = require('fs');

async function main() {
  console.log('🔧 Manual Price Oracle Initialization on Devnet...\n');

  // Connect to devnet
  const connection = new Connection('https://api.devnet.solana.com', 'confirmed');

  // Load wallet
  const keypairPath = process.env.HOME + '/.config/solana/id.json';
  const secretKey = new Uint8Array(JSON.parse(fs.readFileSync(keypairPath, 'utf-8')));
  const payer = Keypair.fromSecretKey(secretKey);

  console.log('Authority:', payer.publicKey.toString());
  console.log('Program ID: 5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz');

  // Derive oracle PDA
  const programId = new PublicKey('5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz');
  const [oraclePda, bump] = PublicKey.findProgramAddressSync(
    [Buffer.from('price_oracle')],
    programId
  );

  console.log('Oracle PDA:', oraclePda.toString());
  console.log('');

  // Check if already initialized
  const accountInfo = await connection.getAccountInfo(oraclePda);
  if (accountInfo) {
    console.log('⚠️  Oracle PDA account already exists!');
    console.log('Account owner:', accountInfo.owner.toString());
    console.log('Account data length:', accountInfo.data.length);
    console.log('');
    console.log('Explorer:', `https://explorer.solana.com/address/${oraclePda.toString()}?cluster=devnet`);
    console.log('');
    console.log('✅ Oracle is initialized. You can use:');
    console.log('  - POST /api/solana/update-price');
    console.log('  - GET /api/solana/price');
    return;
  }

  console.log('❌ Oracle not initialized yet.');
  console.log('');
  console.log('⚠️  Manual initialization via raw transaction is complex.');
  console.log('Please use one of these methods instead:');
  console.log('');
  console.log('1. Use Anchor Test:');
  console.log('   anchor test --skip-deploy --skip-local-validator');
  console.log('');
  console.log('2. Write a test in tests/price-oracle.ts:');
  console.log('   it("Initialize oracle", async () => {');
  console.log('     const initialPrice = new BN(10000);');
  console.log('     await program.methods');
  console.log('       .initializeOracle(initialPrice)');
  console.log('       .accounts({');
  console.log('         oracle: oraclePda,');
  console.log('         authority: provider.wallet.publicKey,');
  console.log('         systemProgram: SystemProgram.programId,');
  console.log('       })');
  console.log('       .rpc();');
  console.log('   });');
  console.log('');
  console.log('3. Or run: anchor run init-oracle (after adding to Anchor.toml)');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });

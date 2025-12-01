const anchor = require('@coral-xyz/anchor');
const { PublicKey, SystemProgram } = require('@solana/web3.js');
const fs = require('fs');

async function main() {
  console.log('🔧 Initializing Price Oracle on Devnet...\n');

  // Configure the client to use devnet
  const connection = new anchor.web3.Connection('https://api.devnet.solana.com', 'confirmed');

  // Load wallet
  const keypairPath = process.env.HOME + '/.config/solana/id.json';
  const secretKey = new Uint8Array(JSON.parse(fs.readFileSync(keypairPath, 'utf-8')));
  const wallet = new anchor.Wallet(anchor.web3.Keypair.fromSecretKey(secretKey));

  const provider = new anchor.AnchorProvider(connection, wallet, {
    commitment: 'confirmed'
  });
  anchor.setProvider(provider);

  // Load the IDL
  const idlPath = './target/idl/price_oracle.json';
  const idl = JSON.parse(fs.readFileSync(idlPath, 'utf-8'));

  const programId = new PublicKey('5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz');
  const program = new anchor.Program(idl, programId, provider);

  console.log('Program ID:', programId.toString());
  console.log('Authority:', wallet.publicKey.toString());

  // Derive the oracle PDA
  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from('price_oracle')],
    programId
  );

  console.log('Oracle PDA:', oraclePda.toString());
  console.log('');

  try {
    // Check if already initialized
    const account = await connection.getAccountInfo(oraclePda);
    if (account) {
      console.log('⚠️  Oracle already initialized!');
      console.log('Oracle PDA:', oraclePda.toString());
      console.log('');
      console.log('To view on Solana Explorer:');
      console.log(`https://explorer.solana.com/address/${oraclePda.toString()}?cluster=devnet`);
      return;
    }

    // Initialize with initial LKC price: 0.00001 SOL per LKC
    // Stored as u64 with 9 decimals: 0.00001 * 1e9 = 10000
    const initialPrice = new anchor.BN(10000); // 100,000 LKC per SOL

    console.log('Initializing oracle with price: 0.00001 SOL per LKC (100,000 LKC per SOL)');
    console.log('Sending transaction...\n');

    // Initialize the oracle
    const tx = await program.methods
      .initializeOracle(initialPrice)
      .accounts({
        oracle: oraclePda,
        authority: wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    console.log('✅ Oracle initialized successfully!\n');
    console.log('Transaction signature:', tx);
    console.log('Explorer:', `https://explorer.solana.com/tx/${tx}?cluster=devnet`);
    console.log('');
    console.log('Oracle Details:');
    console.log('  PDA:', oraclePda.toString());
    console.log('  Authority:', wallet.publicKey.toString());
    console.log('  Initial Price: 0.00001 SOL per LKC');
    console.log('');
    console.log('✅ Backend can now use:');
    console.log('  - POST /api/solana/update-price');
    console.log('  - GET /api/solana/price');
  } catch (error) {
    if (error?.toString().includes('already in use')) {
      console.log('⚠️  Oracle already initialized');
      console.log('Oracle PDA:', oraclePda.toString());
    } else {
      console.error('❌ Error initializing oracle:', error);
      throw error;
    }
  }
}

main()
  .then(() => {
    console.log('\n🎉 Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

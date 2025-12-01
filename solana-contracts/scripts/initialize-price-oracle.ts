import * as anchor from '@coral-xyz/anchor';
import { Program } from '@coral-xyz/anchor';
import { PublicKey } from '@solana/web3.js';
import fs from 'fs';

async function main() {
  console.log('🔧 Initializing Price Oracle on Devnet...\n');

  // Configure the client to use devnet
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  // Load the IDL
  const idl = JSON.parse(
    fs.readFileSync('./target/idl/price_oracle.json', 'utf-8')
  );

  const programId = new PublicKey('5sJZ28FwcX8QYTPN1z6cryHUC8eHhX5HSdxhaBBxptKz');
  const program = new Program(idl as anchor.Idl, programId, provider);

  console.log('Program ID:', program.programId.toString());
  console.log('Authority:', provider.wallet.publicKey.toString());

  // Derive the oracle PDA
  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from('price_oracle')],
    program.programId
  );

  console.log('Oracle PDA:', oraclePda.toString());
  console.log('');

  try {
    // Check if already initialized
    const account = await provider.connection.getAccountInfo(oraclePda);
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
        authority: provider.wallet.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    console.log('✅ Oracle initialized successfully!\n');
    console.log('Transaction signature:', tx);
    console.log('Explorer:', `https://explorer.solana.com/tx/${tx}?cluster=devnet`);
    console.log('');
    console.log('Oracle Details:');
    console.log('  PDA:', oraclePda.toString());
    console.log('  Authority:', provider.wallet.publicKey.toString());
    console.log('  Initial Price: 0.00001 SOL per LKC');
    console.log('');
    console.log('✅ Backend can now use:');
    console.log('  - POST /api/solana/update-price');
    console.log('  - GET /api/solana/price');
  } catch (error: any) {
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

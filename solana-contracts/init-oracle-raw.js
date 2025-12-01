const {
  Connection,
  PublicKey,
  Keypair,
  Transaction,
  SystemProgram,
  TransactionInstruction,
  sendAndConfirmTransaction
} = require('@solana/web3.js');
const fs = require('fs');
const BN = require('bn.js');

async function main() {
  console.log('🔧 Manual Price Oracle Initialization (Raw Transaction)...\n');

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

  console.log('Initializing oracle...');

  // Manually craft the initialize_oracle instruction
  // Discriminator from the IDL (newer Anchor version format)
  const discriminator = Buffer.from([144, 223, 131, 120, 196, 253, 181, 99]);

  // Initial price as u64 (little-endian)
  // 0.00001 SOL per LKC = 10000 (with 9 decimals)
  const initialPrice = new BN(10000);
  const priceBuffer = Buffer.alloc(8);
  initialPrice.toArrayLike(Buffer, 'le', 8).copy(priceBuffer);

  const instructionData = Buffer.concat([discriminator, priceBuffer]);

  const instruction = new TransactionInstruction({
    keys: [
      { pubkey: oraclePda, isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: true },
      { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
    ],
    programId,
    data: instructionData,
  });

  const transaction = new Transaction().add(instruction);

  console.log('Sending transaction...\n');

  try {
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [payer],
      {
        commitment: 'confirmed',
      }
    );

    console.log('✅ Oracle initialized successfully!\n');
    console.log('Transaction signature:', signature);
    console.log('Explorer:', `https://explorer.solana.com/tx/${signature}?cluster=devnet`);
    console.log('');
    console.log('Oracle Details:');
    console.log('  PDA:', oraclePda.toString());
    console.log('  Authority:', payer.publicKey.toString());
    console.log('  Initial Price: 0.00001 SOL per LKC');
    console.log('');
    console.log('✅ Backend can now use:');
    console.log('  - POST /api/solana/update-price');
    console.log('  - GET /api/solana/price');
  } catch (error) {
    console.error('❌ Error:', error);
    if (error.logs) {
      console.error('Transaction logs:', error.logs);
    }
    throw error;
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

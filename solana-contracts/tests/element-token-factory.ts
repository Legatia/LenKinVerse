import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { ElementTokenFactory } from "../target/types/element_token_factory";
import { PublicKey, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddress } from "@solana/spl-token";
import { assert } from "chai";

describe("element-token-factory", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.ElementTokenFactory as Program<ElementTokenFactory>;

  const governor = Keypair.generate();
  const player = Keypair.generate();

  const elementId = "Carbon_X";
  const rarity = 2; // Rare
  const uri = "https://arweave.net/carbon_x_metadata";

  let elementMintPda: PublicKey;
  let elementRegistryPda: PublicKey;

  before(async () => {
    // Airdrop SOL to test accounts
    await provider.connection.requestAirdrop(
      governor.publicKey,
      2 * LAMPORTS_PER_SOL
    );

    await provider.connection.requestAirdrop(
      player.publicKey,
      2 * LAMPORTS_PER_SOL
    );

    // Wait for airdrops to confirm
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // Find PDAs
    [elementRegistryPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("element_registry")],
      program.programId
    );

    [elementMintPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("element_mint"), Buffer.from(elementId)],
      program.programId
    );
  });

  it("Registers a new element", async () => {
    const metadataProgram = new PublicKey(
      "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
    );

    const [metadataPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("metadata"),
        metadataProgram.toBuffer(),
        elementMintPda.toBuffer(),
      ],
      metadataProgram
    );

    const tx = await program.methods
      .registerElement(elementId, rarity, uri)
      .accounts({
        elementRegistry: elementRegistryPda,
        elementMint: elementMintPda,
        metadata: metadataPda,
        governor: governor.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
        tokenMetadataProgram: metadataProgram,
      } as any)
      .signers([governor])
      .rpc();

    console.log("Register element transaction:", tx);

    // Fetch element registry
    const registry = await program.account.elementRegistry.fetch(
      elementRegistryPda
    );

    assert.equal(registry.elementCount.toNumber(), 1);
    assert.equal(registry.elements[0].elementId, elementId);
    assert.equal(registry.elements[0].rarity, rarity);
    assert.equal(registry.elements[0].governor.toBase58(), governor.publicKey.toBase58());
    assert.equal(registry.elements[0].isTradeable, false);

    console.log("✅ Element registered successfully");
    console.log("Element ID:", elementId);
    console.log("Mint:", elementMintPda.toBase58());
    console.log("Governor:", governor.publicKey.toBase58());
  });

  it("Mints element tokens to player", async () => {
    const amount = 100 * 1_000_000; // 100 tokens (6 decimals)

    const playerTokenAccount = await getAssociatedTokenAddress(
      elementMintPda,
      player.publicKey
    );

    const tx = await program.methods
      .mintElementTokens(elementId, new anchor.BN(amount))
      .accounts({
        elementRegistry: elementRegistryPda,
        elementMint: elementMintPda,
        playerTokenAccount,
        player: player.publicKey,
      } as any)
      .signers([player])
      .rpc();

    console.log("Mint tokens transaction:", tx);

    // Check token balance
    const tokenAccountInfo = await provider.connection.getTokenAccountBalance(
      playerTokenAccount
    );

    assert.equal(tokenAccountInfo.value.amount, amount.toString());
    console.log("✅ Minted", amount / 1_000_000, "tokens to player");
  });

  it("Waits and marks element as tradeable", async () => {
    // In real scenario, wait 30 minutes
    // For testing, we'll skip ahead (requires manipulating Clock in test validator)

    console.log("⏳ In production, wait 30 minutes before calling mark_tradeable");

    // Note: This will fail in test unless we manipulate the clock
    // Uncomment when testing with manipulated clock
    /*
    const tx = await program.methods
      .markTradeable(elementId)
      .accounts({
        elementRegistry: elementRegistryPda,
      } as any)
      .rpc();

    const registry = await program.account.elementRegistry.fetch(
      elementRegistryPda
    );

    assert.equal(registry.elements[0].isTradeable, true);
    console.log("✅ Element marked as tradeable");
    */
  });

  it("Fails to register duplicate element", async () => {
    try {
      await program.methods
        .registerElement(elementId, rarity, uri)
        .accounts({
          elementRegistry: elementRegistryPda,
          elementMint: elementMintPda,
          governor: governor.publicKey,
        } as any)
        .signers([governor])
        .rpc();

      assert.fail("Should have thrown error for duplicate element");
    } catch (error) {
      assert.include(error.toString(), "ElementAlreadyExists");
      console.log("✅ Correctly rejected duplicate element registration");
    }
  });
});

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { ElementNft } from "../target/types/element_nft";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress,
} from "@solana/spl-token";
import { expect } from "chai";

describe("element-nft", () => {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.ElementNft as Program<ElementNft>;
  const owner = provider.wallet as anchor.Wallet;

  let mintKeypair: Keypair;
  let elementPda: PublicKey;
  let tokenAccount: PublicKey;

  beforeEach(async () => {
    // Generate new mint for each test
    mintKeypair = Keypair.generate();

    // Derive element PDA
    [elementPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("element"), mintKeypair.publicKey.toBuffer()],
      program.programId
    );

    // Get associated token account address
    tokenAccount = await getAssociatedTokenAddress(
      mintKeypair.publicKey,
      owner.publicKey
    );
  });

  it("Mints a common element NFT", async () => {
    const elementId = "lkC";
    const elementName = "Carbon";
    const symbol = "C";
    const rarity = 0; // Common
    const amount = new anchor.BN(100);
    const generationMethod = "collected";
    const decayTime = null;

    const tx = await program.methods
      .mintElement(
        elementId,
        elementName,
        symbol,
        rarity,
        amount,
        generationMethod,
        decayTime
      )
      .accounts({
        elementAccount: elementPda,
        mint: mintKeypair.publicKey,
        tokenAccount: tokenAccount,
        owner: owner.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      })
      .signers([mintKeypair])
      .rpc();

    console.log("Mint transaction signature:", tx);

    // Fetch the element account
    const elementAccount = await program.account.elementAccount.fetch(
      elementPda
    );

    // Verify account data
    expect(elementAccount.owner.toString()).to.equal(owner.publicKey.toString());
    expect(elementAccount.mint.toString()).to.equal(mintKeypair.publicKey.toString());
    expect(elementAccount.elementId).to.equal(elementId);
    expect(elementAccount.elementName).to.equal(elementName);
    expect(elementAccount.symbol).to.equal(symbol);
    expect(elementAccount.rarity).to.equal(rarity);
    expect(elementAccount.amount.toNumber()).to.equal(amount.toNumber());
    expect(elementAccount.generationMethod).to.equal(generationMethod);
    expect(elementAccount.decayTime).to.be.null;
    expect(elementAccount.discoveredAt).to.be.greaterThan(0);
  });

  it("Mints a rare isotope NFT with decay time", async () => {
    const elementId = "C14";
    const elementName = "Carbon-14";
    const symbol = "C14";
    const rarity = 3; // Legendary
    const amount = new anchor.BN(1);
    const generationMethod = "analyzed";
    const decayTime = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    const tx = await program.methods
      .mintElement(
        elementId,
        elementName,
        symbol,
        rarity,
        amount,
        generationMethod,
        decayTime
      )
      .accounts({
        elementAccount: elementPda,
        mint: mintKeypair.publicKey,
        tokenAccount: tokenAccount,
        owner: owner.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      })
      .signers([mintKeypair])
      .rpc();

    console.log("Mint transaction signature:", tx);

    const elementAccount = await program.account.elementAccount.fetch(
      elementPda
    );

    expect(elementAccount.elementId).to.equal(elementId);
    expect(elementAccount.rarity).to.equal(rarity);
    expect(elementAccount.decayTime).to.equal(decayTime);
  });

  it("Updates element amount", async () => {
    // First mint an element
    await program.methods
      .mintElement(
        "lkO",
        "Oxygen",
        "O",
        0,
        new anchor.BN(50),
        "collected",
        null
      )
      .accounts({
        elementAccount: elementPda,
        mint: mintKeypair.publicKey,
        tokenAccount: tokenAccount,
        owner: owner.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      })
      .signers([mintKeypair])
      .rpc();

    // Update the amount
    const newAmount = new anchor.BN(150);
    await program.methods
      .updateAmount(newAmount)
      .accounts({
        elementAccount: elementPda,
        owner: owner.publicKey,
      })
      .rpc();

    const elementAccount = await program.account.elementAccount.fetch(
      elementPda
    );

    expect(elementAccount.amount.toNumber()).to.equal(newAmount.toNumber());
  });

  it("Burns element NFT", async () => {
    // First mint an element
    await program.methods
      .mintElement(
        "lkH",
        "Hydrogen",
        "H",
        0,
        new anchor.BN(10),
        "reacted",
        null
      )
      .accounts({
        elementAccount: elementPda,
        mint: mintKeypair.publicKey,
        tokenAccount: tokenAccount,
        owner: owner.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      })
      .signers([mintKeypair])
      .rpc();

    // Burn the element
    await program.methods
      .burnElement()
      .accounts({
        elementAccount: elementPda,
        mint: mintKeypair.publicKey,
        tokenAccount: tokenAccount,
        owner: owner.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .rpc();

    // Verify account is closed
    try {
      await program.account.elementAccount.fetch(elementPda);
      expect.fail("Expected account to be closed");
    } catch (error) {
      expect(error.message).to.include("Account does not exist");
    }
  });

  it("Rejects invalid rarity", async () => {
    const invalidRarity = 5; // Max is 3

    try {
      await program.methods
        .mintElement(
          "lkC",
          "Carbon",
          "C",
          invalidRarity,
          new anchor.BN(100),
          "collected",
          null
        )
        .accounts({
          elementAccount: elementPda,
          mint: mintKeypair.publicKey,
          tokenAccount: tokenAccount,
          owner: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .signers([mintKeypair])
        .rpc();

      expect.fail("Expected transaction to fail with invalid rarity");
    } catch (error) {
      expect(error.message).to.include("InvalidRarity");
    }
  });

  it("Rejects zero amount", async () => {
    try {
      await program.methods
        .mintElement(
          "lkC",
          "Carbon",
          "C",
          0,
          new anchor.BN(0), // Invalid: zero amount
          "collected",
          null
        )
        .accounts({
          elementAccount: elementPda,
          mint: mintKeypair.publicKey,
          tokenAccount: tokenAccount,
          owner: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .signers([mintKeypair])
        .rpc();

      expect.fail("Expected transaction to fail with zero amount");
    } catch (error) {
      expect(error.message).to.include("InvalidAmount");
    }
  });
});

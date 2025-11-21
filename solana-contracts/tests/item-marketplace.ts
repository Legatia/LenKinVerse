import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { ItemMarketplace } from "../target/types/item_marketplace";
import { PublicKey, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddress } from "@solana/spl-token";
import { assert } from "chai";

describe("item-marketplace", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.ItemMarketplace as Program<ItemMarketplace>;

  const owner = Keypair.generate();
  const buyer = Keypair.generate();

  const itemType = "Gloves";
  const itemLevel = 5;
  const itemAttributes = JSON.stringify({
    power: 95,
    speed: 0.3,
    batchSize: 50,
  });
  const uri = "https://arweave.net/gloves_lv5_metadata";
  const listingPrice = 0.5 * LAMPORTS_PER_SOL; // 0.5 SOL

  let itemMintPda: PublicKey;
  let listingPda: PublicKey;

  before(async () => {
    // Airdrop SOL to test accounts
    await provider.connection.requestAirdrop(
      owner.publicKey,
      2 * LAMPORTS_PER_SOL
    );

    await provider.connection.requestAirdrop(
      buyer.publicKey,
      2 * LAMPORTS_PER_SOL
    );

    // Wait for airdrops
    await new Promise((resolve) => setTimeout(resolve, 1000));

    const itemId = `${itemType}_${itemLevel}`;

    // Find PDAs
    [itemMintPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("item_mint"),
        owner.publicKey.toBuffer(),
        Buffer.from(itemId),
      ],
      program.programId
    );

    [listingPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("listing"),
        owner.publicKey.toBuffer(),
        itemMintPda.toBuffer(),
      ],
      program.programId
    );
  });

  it("Mints an item NFT", async () => {
    const metadataProgram = new PublicKey(
      "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
    );

    const [metadataPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("metadata"),
        metadataProgram.toBuffer(),
        itemMintPda.toBuffer(),
      ],
      metadataProgram
    );

    const ownerTokenAccount = await getAssociatedTokenAddress(
      itemMintPda,
      owner.publicKey
    );

    const tx = await program.methods
      .mintItemNft(itemType, itemLevel, itemAttributes, uri)
      .accounts({
        itemMint: itemMintPda,
        ownerTokenAccount,
        metadata: metadataPda,
        owner: owner.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
        tokenMetadataProgram: metadataProgram,
      } as any)
      .signers([owner])
      .rpc();

    console.log("Mint NFT transaction:", tx);

    // Check NFT balance
    const tokenAccountInfo = await provider.connection.getTokenAccountBalance(
      ownerTokenAccount
    );

    assert.equal(tokenAccountInfo.value.amount, "1"); // NFT has supply of 1
    console.log("✅ Minted NFT:", itemType, "Lv.", itemLevel);
  });

  it("Lists item for sale", async () => {
    const sellerTokenAccount = await getAssociatedTokenAddress(
      itemMintPda,
      owner.publicKey
    );

    const escrowTokenAccount = await getAssociatedTokenAddress(
      itemMintPda,
      listingPda,
      true // allowOwnerOffCurve
    );

    const tx = await program.methods
      .listItem(new anchor.BN(listingPrice))
      .accounts({
        listing: listingPda,
        itemMint: itemMintPda,
        sellerTokenAccount,
        escrowTokenAccount,
        seller: owner.publicKey,
      } as any)
      .signers([owner])
      .rpc();

    console.log("List item transaction:", tx);

    // Check listing
    const listing = await program.account.listing.fetch(listingPda);
    assert.equal(listing.seller.toBase58(), owner.publicKey.toBase58());
    assert.equal(listing.price.toNumber(), listingPrice);
    assert.equal(listing.isActive, true);

    // Check NFT is in escrow
    const escrowBalance = await provider.connection.getTokenAccountBalance(
      escrowTokenAccount
    );
    assert.equal(escrowBalance.value.amount, "1");

    console.log("✅ Listed item for", listingPrice / LAMPORTS_PER_SOL, "SOL");
  });

  it("Buys listed item", async () => {
    const sellerBalanceBefore = await provider.connection.getBalance(
      owner.publicKey
    );

    const escrowTokenAccount = await getAssociatedTokenAddress(
      itemMintPda,
      listingPda,
      true
    );

    const buyerTokenAccount = await getAssociatedTokenAddress(
      itemMintPda,
      buyer.publicKey
    );

    const tx = await program.methods
      .buyItem()
      .accounts({
        listing: listingPda,
        itemMint: itemMintPda,
        escrowTokenAccount,
        buyerTokenAccount,
        sellerAccount: owner.publicKey,
        buyer: buyer.publicKey,
      } as any)
      .signers([buyer])
      .rpc();

    console.log("Buy item transaction:", tx);

    // Check listing is inactive
    const listing = await program.account.listing.fetch(listingPda);
    assert.equal(listing.isActive, false);

    // Check NFT transferred to buyer
    const buyerBalance = await provider.connection.getTokenAccountBalance(
      buyerTokenAccount
    );
    assert.equal(buyerBalance.value.amount, "1");

    // Check seller received payment
    const sellerBalanceAfter = await provider.connection.getBalance(
      owner.publicKey
    );
    assert.approximately(
      sellerBalanceAfter - sellerBalanceBefore,
      listingPrice,
      1000000 // Allow for small discrepancy due to fees
    );

    console.log("✅ Item purchased successfully");
    console.log("Buyer received NFT");
    console.log("Seller received", listingPrice / LAMPORTS_PER_SOL, "SOL");
  });

  it("Mints and cancels a listing", async () => {
    // Mint another NFT
    const itemId2 = `${itemType}_6`;

    const [itemMintPda2] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("item_mint"),
        owner.publicKey.toBuffer(),
        Buffer.from(itemId2),
      ],
      program.programId
    );

    const metadataProgram = new PublicKey(
      "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
    );

    const [metadataPda2] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("metadata"),
        metadataProgram.toBuffer(),
        itemMintPda2.toBuffer(),
      ],
      metadataProgram
    );

    const ownerTokenAccount2 = await getAssociatedTokenAddress(
      itemMintPda2,
      owner.publicKey
    );

    await program.methods
      .mintItemNft(itemType, 6, itemAttributes, uri)
      .accounts({
        itemMint: itemMintPda2,
        ownerTokenAccount: ownerTokenAccount2,
        metadata: metadataPda2,
        owner: owner.publicKey,
        tokenMetadataProgram: metadataProgram,
      } as any)
      .signers([owner])
      .rpc();

    // List it
    const [listingPda2] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("listing"),
        owner.publicKey.toBuffer(),
        itemMintPda2.toBuffer(),
      ],
      program.programId
    );

    const escrowTokenAccount2 = await getAssociatedTokenAddress(
      itemMintPda2,
      listingPda2,
      true
    );

    await program.methods
      .listItem(new anchor.BN(listingPrice))
      .accounts({
        listing: listingPda2,
        itemMint: itemMintPda2,
        sellerTokenAccount: ownerTokenAccount2,
        escrowTokenAccount: escrowTokenAccount2,
        seller: owner.publicKey,
      } as any)
      .signers([owner])
      .rpc();

    // Cancel listing
    const tx = await program.methods
      .cancelListing()
      .accounts({
        listing: listingPda2,
        itemMint: itemMintPda2,
        escrowTokenAccount: escrowTokenAccount2,
        sellerTokenAccount: ownerTokenAccount2,
        seller: owner.publicKey,
      } as any)
      .signers([owner])
      .rpc();

    console.log("Cancel listing transaction:", tx);

    // Check listing is inactive
    const listing = await program.account.listing.fetch(listingPda2);
    assert.equal(listing.isActive, false);

    // Check NFT returned to owner
    const ownerBalance = await provider.connection.getTokenAccountBalance(
      ownerTokenAccount2
    );
    assert.equal(ownerBalance.value.amount, "1");

    console.log("✅ Listing cancelled, NFT returned to owner");
  });
});

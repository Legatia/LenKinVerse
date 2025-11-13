import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Marketplace } from "../target/types/marketplace";
import { ElementNft } from "../target/types/element_nft";
import { PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress,
  createMint,
  mintTo,
  getOrCreateAssociatedTokenAccount,
} from "@solana/spl-token";
import { expect } from "chai";

describe("marketplace", () => {
  // Configure the client
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const marketplace = anchor.workspace.Marketplace as Program<Marketplace>;
  const elementNft = anchor.workspace.ElementNft as Program<ElementNft>;
  const owner = provider.wallet as anchor.Wallet;

  let alsolMint: PublicKey;
  let elementMintKeypair: Keypair;
  let elementPda: PublicKey;
  let sellerTokenAccount: PublicKey;
  let sellerAlsolAccount: PublicKey;
  let listingPda: PublicKey;
  let escrowTokenAccount: PublicKey;

  before(async () => {
    // Create alSOL mint for testing (simulates the in-game currency)
    alsolMint = await createMint(
      provider.connection,
      owner.payer,
      owner.publicKey,
      null,
      9 // 9 decimals like SOL
    );

    console.log("Created alSOL mint:", alsolMint.toString());

    // Create alSOL token account for seller and mint some tokens
    const sellerAlsolAccountInfo = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      owner.payer,
      alsolMint,
      owner.publicKey
    );
    sellerAlsolAccount = sellerAlsolAccountInfo.address;

    // Mint 1000 alSOL to seller for testing
    await mintTo(
      provider.connection,
      owner.payer,
      alsolMint,
      sellerAlsolAccount,
      owner.publicKey,
      1000 * 1e9 // 1000 alSOL with 9 decimals
    );

    console.log("Minted 1000 alSOL to seller");
  });

  describe("Listing Management", () => {
    beforeEach(async () => {
      // Create a new element NFT for each test
      elementMintKeypair = Keypair.generate();

      // Derive element PDA
      [elementPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("element"), elementMintKeypair.publicKey.toBuffer()],
        elementNft.programId
      );

      // Get seller's token account for the element NFT
      sellerTokenAccount = await getAssociatedTokenAddress(
        elementMintKeypair.publicKey,
        owner.publicKey
      );

      // Derive listing PDA
      [listingPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("listing"),
          owner.publicKey.toBuffer(),
          elementMintKeypair.publicKey.toBuffer(),
        ],
        marketplace.programId
      );

      // Derive escrow token account
      escrowTokenAccount = await getAssociatedTokenAddress(
        elementMintKeypair.publicKey,
        listingPda,
        true
      );

      // Mint the element NFT first
      await elementNft.methods
        .mintElement(
          "lkC",
          "Carbon",
          "C",
          0,
          new anchor.BN(100),
          "collected",
          null
        )
        .accounts({
          elementAccount: elementPda,
          mint: elementMintKeypair.publicKey,
          tokenAccount: sellerTokenAccount,
          owner: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .signers([elementMintKeypair])
        .rpc();

      console.log("Minted test element NFT");
    });

    it("Creates a listing for an element NFT", async () => {
      const priceAlsol = new anchor.BN(5 * 1e9); // 5 alSOL

      const tx = await marketplace.methods
        .createListing(priceAlsol)
        .accounts({
          listingAccount: listingPda,
          elementAccount: elementPda,
          elementMint: elementMintKeypair.publicKey,
          sellerTokenAccount: sellerTokenAccount,
          escrowTokenAccount: escrowTokenAccount,
          seller: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .rpc();

      console.log("Create listing transaction signature:", tx);

      // Fetch the listing account
      const listing = await marketplace.account.listingAccount.fetch(
        listingPda
      );

      // Verify listing data
      expect(listing.seller.toString()).to.equal(owner.publicKey.toString());
      expect(listing.elementMint.toString()).to.equal(
        elementMintKeypair.publicKey.toString()
      );
      expect(listing.priceAlsol.toNumber()).to.equal(priceAlsol.toNumber());
      expect(listing.isActive).to.be.true;
      expect(listing.createdAt).to.be.greaterThan(0);

      // Verify NFT was transferred to escrow
      const escrowAccount = await provider.connection.getTokenAccountBalance(
        escrowTokenAccount
      );
      expect(escrowAccount.value.uiAmount).to.equal(1);
    });

    it("Updates listing price", async () => {
      const initialPrice = new anchor.BN(5 * 1e9);
      const newPrice = new anchor.BN(10 * 1e9);

      // Create listing first
      await marketplace.methods
        .createListing(initialPrice)
        .accounts({
          listingAccount: listingPda,
          elementAccount: elementPda,
          elementMint: elementMintKeypair.publicKey,
          sellerTokenAccount: sellerTokenAccount,
          escrowTokenAccount: escrowTokenAccount,
          seller: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .rpc();

      // Update price
      await marketplace.methods
        .updatePrice(newPrice)
        .accounts({
          listingAccount: listingPda,
          seller: owner.publicKey,
        })
        .rpc();

      const listing = await marketplace.account.listingAccount.fetch(
        listingPda
      );
      expect(listing.priceAlsol.toNumber()).to.equal(newPrice.toNumber());
    });

    it("Cancels a listing and returns NFT to seller", async () => {
      const priceAlsol = new anchor.BN(5 * 1e9);

      // Create listing
      await marketplace.methods
        .createListing(priceAlsol)
        .accounts({
          listingAccount: listingPda,
          elementAccount: elementPda,
          elementMint: elementMintKeypair.publicKey,
          sellerTokenAccount: sellerTokenAccount,
          escrowTokenAccount: escrowTokenAccount,
          seller: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .rpc();

      // Cancel listing
      await marketplace.methods
        .cancelListing()
        .accounts({
          listingAccount: listingPda,
          escrowTokenAccount: escrowTokenAccount,
          sellerTokenAccount: sellerTokenAccount,
          seller: owner.publicKey,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      // Verify listing is inactive
      const listing = await marketplace.account.listingAccount.fetch(
        listingPda
      );
      expect(listing.isActive).to.be.false;

      // Verify NFT was returned to seller
      const sellerAccount = await provider.connection.getTokenAccountBalance(
        sellerTokenAccount
      );
      expect(sellerAccount.value.uiAmount).to.equal(1);
    });

    it("Rejects invalid price (zero)", async () => {
      try {
        await marketplace.methods
          .createListing(new anchor.BN(0))
          .accounts({
            listingAccount: listingPda,
            elementAccount: elementPda,
            elementMint: elementMintKeypair.publicKey,
            sellerTokenAccount: sellerTokenAccount,
            escrowTokenAccount: escrowTokenAccount,
            seller: owner.publicKey,
            systemProgram: SystemProgram.programId,
            tokenProgram: TOKEN_PROGRAM_ID,
            associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
            rent: anchor.web3.SYSVAR_RENT_PUBKEY,
          })
          .rpc();

        expect.fail("Expected transaction to fail with invalid price");
      } catch (error) {
        expect(error.message).to.include("InvalidPrice");
      }
    });
  });

  describe("Buying NFTs", () => {
    let buyer: Keypair;
    let buyerAlsolAccount: PublicKey;
    let buyerTokenAccount: PublicKey;
    const listingPrice = new anchor.BN(10 * 1e9); // 10 alSOL

    before(async () => {
      // Create buyer wallet
      buyer = Keypair.generate();

      // Airdrop SOL to buyer for transaction fees
      const airdropSig = await provider.connection.requestAirdrop(
        buyer.publicKey,
        2 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSig);

      // Create buyer's alSOL token account
      const buyerAlsolAccountInfo = await getOrCreateAssociatedTokenAccount(
        provider.connection,
        owner.payer,
        alsolMint,
        buyer.publicKey
      );
      buyerAlsolAccount = buyerAlsolAccountInfo.address;

      // Mint 100 alSOL to buyer for testing
      await mintTo(
        provider.connection,
        owner.payer,
        alsolMint,
        buyerAlsolAccount,
        owner.publicKey,
        100 * 1e9
      );

      console.log("Setup buyer with 100 alSOL");
    });

    beforeEach(async () => {
      // Create a new element NFT
      elementMintKeypair = Keypair.generate();

      [elementPda] = PublicKey.findProgramAddressSync(
        [Buffer.from("element"), elementMintKeypair.publicKey.toBuffer()],
        elementNft.programId
      );

      sellerTokenAccount = await getAssociatedTokenAddress(
        elementMintKeypair.publicKey,
        owner.publicKey
      );

      [listingPda] = PublicKey.findProgramAddressSync(
        [
          Buffer.from("listing"),
          owner.publicKey.toBuffer(),
          elementMintKeypair.publicKey.toBuffer(),
        ],
        marketplace.programId
      );

      escrowTokenAccount = await getAssociatedTokenAddress(
        elementMintKeypair.publicKey,
        listingPda,
        true
      );

      buyerTokenAccount = await getAssociatedTokenAddress(
        elementMintKeypair.publicKey,
        buyer.publicKey
      );

      // Mint element NFT
      await elementNft.methods
        .mintElement(
          "lkO",
          "Oxygen",
          "O",
          1,
          new anchor.BN(50),
          "analyzed",
          null
        )
        .accounts({
          elementAccount: elementPda,
          mint: elementMintKeypair.publicKey,
          tokenAccount: sellerTokenAccount,
          owner: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .signers([elementMintKeypair])
        .rpc();

      // Create listing
      await marketplace.methods
        .createListing(listingPrice)
        .accounts({
          listingAccount: listingPda,
          elementAccount: elementPda,
          elementMint: elementMintKeypair.publicKey,
          sellerTokenAccount: sellerTokenAccount,
          escrowTokenAccount: escrowTokenAccount,
          seller: owner.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .rpc();
    });

    it("Buys NFT with alSOL", async () => {
      // Get initial balances
      const sellerInitialBalance = await provider.connection.getTokenAccountBalance(
        sellerAlsolAccount
      );
      const buyerInitialBalance = await provider.connection.getTokenAccountBalance(
        buyerAlsolAccount
      );

      // Buy NFT
      const tx = await marketplace.methods
        .buyNft()
        .accounts({
          listingAccount: listingPda,
          escrowTokenAccount: escrowTokenAccount,
          buyerTokenAccount: buyerTokenAccount,
          seller: owner.publicKey,
          alsolMint: alsolMint,
          buyerAlsolAccount: buyerAlsolAccount,
          sellerAlsolAccount: sellerAlsolAccount,
          buyer: buyer.publicKey,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: anchor.web3.SYSVAR_RENT_PUBKEY,
        })
        .signers([buyer])
        .rpc();

      console.log("Buy NFT transaction signature:", tx);

      // Verify listing is now inactive
      const listing = await marketplace.account.listingAccount.fetch(
        listingPda
      );
      expect(listing.isActive).to.be.false;

      // Verify NFT was transferred to buyer
      const buyerNftBalance = await provider.connection.getTokenAccountBalance(
        buyerTokenAccount
      );
      expect(buyerNftBalance.value.uiAmount).to.equal(1);

      // Verify alSOL was transferred
      const sellerFinalBalance = await provider.connection.getTokenAccountBalance(
        sellerAlsolAccount
      );
      const buyerFinalBalance = await provider.connection.getTokenAccountBalance(
        buyerAlsolAccount
      );

      const priceInAlsol = listingPrice.toNumber() / 1e9;
      expect(
        sellerFinalBalance.value.uiAmount -
          sellerInitialBalance.value.uiAmount
      ).to.equal(priceInAlsol);
      expect(
        buyerInitialBalance.value.uiAmount - buyerFinalBalance.value.uiAmount
      ).to.equal(priceInAlsol);
    });

    it("Rejects buying from inactive listing", async () => {
      // Cancel the listing first
      await marketplace.methods
        .cancelListing()
        .accounts({
          listingAccount: listingPda,
          escrowTokenAccount: escrowTokenAccount,
          sellerTokenAccount: sellerTokenAccount,
          seller: owner.publicKey,
          tokenProgram: TOKEN_PROGRAM_ID,
        })
        .rpc();

      // Try to buy
      try {
        await marketplace.methods
          .buyNft()
          .accounts({
            listingAccount: listingPda,
            escrowTokenAccount: escrowTokenAccount,
            buyerTokenAccount: buyerTokenAccount,
            seller: owner.publicKey,
            alsolMint: alsolMint,
            buyerAlsolAccount: buyerAlsolAccount,
            sellerAlsolAccount: sellerAlsolAccount,
            buyer: buyer.publicKey,
            systemProgram: SystemProgram.programId,
            tokenProgram: TOKEN_PROGRAM_ID,
            associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
            rent: anchor.web3.SYSVAR_RENT_PUBKEY,
          })
          .signers([buyer])
          .rpc();

        expect.fail("Expected transaction to fail on inactive listing");
      } catch (error) {
        expect(error.message).to.include("ListingNotActive");
      }
    });
  });
});

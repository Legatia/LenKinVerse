import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PriceOracle } from "../target/types/price_oracle";
import { expect } from "chai";

describe("price_oracle", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.PriceOracle as Program<PriceOracle>;
  const authority = provider.wallet;

  // PDAs
  const [oraclePda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("price_oracle")],
    program.programId
  );

  it("Initializes the price oracle", async () => {
    const initialPrice = new anchor.BN(1_000_000_000); // 1 LKO = 1 SOL

    const tx = await program.methods
      .initializeOracle(initialPrice)
      .accounts({
        oracle: oraclePda,
        authority: authority.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    console.log("Initialize oracle transaction:", tx);

    // Fetch oracle account
    const oracleAccount = await program.account.priceOracle.fetch(oraclePda);

    expect(oracleAccount.authority.toString()).to.equal(
      authority.publicKey.toString()
    );
    expect(oracleAccount.lkoPerSol.toString()).to.equal(
      initialPrice.toString()
    );
    expect(oracleAccount.isActive).to.be.true;
    expect(oracleAccount.updateCount.toNumber()).to.equal(0);
  });

  it("Updates the LKO/SOL price", async () => {
    const newPrice = new anchor.BN(1_500_000_000); // 1.5 LKO = 1 SOL

    const tx = await program.methods
      .updatePrice(newPrice)
      .accounts({
        oracle: oraclePda,
        authority: authority.publicKey,
      })
      .rpc();

    console.log("Update price transaction:", tx);

    // Fetch updated oracle
    const oracleAccount = await program.account.priceOracle.fetch(oraclePda);

    expect(oracleAccount.lkoPerSol.toString()).to.equal(newPrice.toString());
    expect(oracleAccount.updateCount.toNumber()).to.equal(1);
  });

  it("Gets the current price", async () => {
    const oracleAccount = await program.account.priceOracle.fetch(oraclePda);

    console.log("Current LKO/SOL price:", oracleAccount.lkoPerSol.toString());
    console.log("Last updated:", new Date(oracleAccount.lastUpdated.toNumber() * 1000).toISOString());
    console.log("Update count:", oracleAccount.updateCount.toString());
    console.log("Is active:", oracleAccount.isActive);
  });

  it("Updates element-specific price", async () => {
    const elementId = "Carbon_X";
    const pricePerSol = new anchor.BN(500_000_000); // 0.5 Carbon_X = 1 SOL

    const [elementOraclePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("element_price"), Buffer.from(elementId)],
      program.programId
    );

    const tx = await program.methods
      .updateElementPrice(elementId, pricePerSol)
      .accounts({
        elementOracle: elementOraclePda,
        oracle: oraclePda,
        authority: authority.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    console.log("Update element price transaction:", tx);

    // Fetch element oracle
    const elementOracleAccount = await program.account.elementPriceOracle.fetch(
      elementOraclePda
    );

    expect(elementOracleAccount.elementId).to.equal(elementId);
    expect(elementOracleAccount.pricePerSol.toString()).to.equal(
      pricePerSol.toString()
    );
    expect(elementOracleAccount.updateCount.toNumber()).to.equal(1);
  });

  it("Pauses and unpauses the oracle", async () => {
    // Pause
    await program.methods
      .setOracleActive(false)
      .accounts({
        oracle: oraclePda,
        authority: authority.publicKey,
      })
      .rpc();

    let oracleAccount = await program.account.priceOracle.fetch(oraclePda);
    expect(oracleAccount.isActive).to.be.false;

    // Try to update while paused (should fail)
    try {
      await program.methods
        .updatePrice(new anchor.BN(2_000_000_000))
        .accounts({
          oracle: oraclePda,
          authority: authority.publicKey,
        })
        .rpc();

      expect.fail("Should have thrown error for inactive oracle");
    } catch (err) {
      expect(err.toString()).to.include("OracleInactive");
    }

    // Unpause
    await program.methods
      .setOracleActive(true)
      .accounts({
        oracle: oraclePda,
        authority: authority.publicKey,
      })
      .rpc();

    oracleAccount = await program.account.priceOracle.fetch(oraclePda);
    expect(oracleAccount.isActive).to.be.true;
  });

  it("Rejects unauthorized price updates", async () => {
    const unauthorizedKeypair = anchor.web3.Keypair.generate();

    // Airdrop SOL to unauthorized keypair
    const airdropSig = await provider.connection.requestAirdrop(
      unauthorizedKeypair.publicKey,
      anchor.web3.LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(airdropSig);

    try {
      await program.methods
        .updatePrice(new anchor.BN(3_000_000_000))
        .accounts({
          oracle: oraclePda,
          authority: unauthorizedKeypair.publicKey,
        })
        .signers([unauthorizedKeypair])
        .rpc();

      expect.fail("Should have thrown error for unauthorized user");
    } catch (err) {
      expect(err.toString()).to.include("Unauthorized");
    }
  });
});

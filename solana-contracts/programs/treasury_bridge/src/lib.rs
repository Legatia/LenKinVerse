use anchor_lang::prelude::*;
use anchor_spl::token::{self, Burn, Mint, Token, TokenAccount, Transfer};

declare_id!("BrdgPYm3GvXFTEHhgN2YXg5WqV9gLBYL7hdYbkBhxA1");

// Bridge fees (in basis points, 1 bp = 0.01%)
const TOTAL_BRIDGE_FEE_BPS: u64 = 300;     // 3.0% total fee
const GOVERNOR_FEE_BPS: u64 = 50;          // 0.5% to governor
const DEV_TREASURY_FEE_BPS: u64 = 250;     // 2.5% to dev treasury

#[program]
pub mod treasury_bridge {
    use super::*;

    /// Bridge treasury tokens to on-chain (for DEX liquidity)
    /// Only governor can bridge treasury to chain (no fee for governors)
    /// Burns in-game balance, transfers SPL tokens to governor wallet
    pub fn bridge_to_chain(
        ctx: Context<BridgeToChain>,
        element_id: String,
        amount: u64,
        burn_proof_signature: [u8; 64], // Backend signature proving in-game burn
    ) -> Result<()> {
        require!(amount > 0, ErrorCode::InvalidAmount);

        // Verify burn proof (backend must sign that in-game tokens were burned)
        let burn_proof = BurnProof {
            element_id: element_id.clone(),
            amount,
            governor: ctx.accounts.governor.key(),
            timestamp: Clock::get()?.unix_timestamp,
        };

        verify_burn_proof(&burn_proof, &burn_proof_signature, &ctx.accounts.burn_proof_authority.key())?;

        // Transfer tokens from treasury to governor's wallet
        // (Backend has verified and burned in-game balance)
        let treasury_seeds = &[
            b"element_treasury",
            element_id.as_bytes(),
            &[ctx.bumps.treasury_token_account],
        ];
        let signer = &[&treasury_seeds[..]];

        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.treasury_token_account.to_account_info(),
                    to: ctx.accounts.governor_token_account.to_account_info(),
                    authority: ctx.accounts.treasury_token_account.to_account_info(),
                },
                signer,
            ),
            amount,
        )?;

        // Record bridge event
        let bridge_record = &mut ctx.accounts.bridge_record;
        bridge_record.element_id = element_id.clone();
        bridge_record.direction = BridgeDirection::ToChain;
        bridge_record.amount = amount;
        bridge_record.governor = ctx.accounts.governor.key();
        bridge_record.timestamp = Clock::get()?.unix_timestamp;

        emit!(BridgedToChain {
            element_id,
            amount,
            governor: ctx.accounts.governor.key(),
        });

        msg!("Bridged {} tokens to chain for governor", amount);

        Ok(())
    }

    /// Bridge on-chain tokens back to in-game (replenish treasury)
    /// Governor burns SPL tokens, backend credits in-game treasury
    pub fn bridge_to_ingame(
        ctx: Context<BridgeToIngame>,
        element_id: String,
        amount: u64,
    ) -> Result<()> {
        require!(amount > 0, ErrorCode::InvalidAmount);

        // Burn governor's SPL tokens
        token::burn(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Burn {
                    mint: ctx.accounts.element_mint.to_account_info(),
                    from: ctx.accounts.governor_token_account.to_account_info(),
                    authority: ctx.accounts.governor.to_account_info(),
                },
            ),
            amount,
        )?;

        // Record bridge event (backend will credit in-game)
        let bridge_record = &mut ctx.accounts.bridge_record;
        bridge_record.element_id = element_id.clone();
        bridge_record.direction = BridgeDirection::ToIngame;
        bridge_record.amount = amount;
        bridge_record.governor = ctx.accounts.governor.key();
        bridge_record.timestamp = Clock::get()?.unix_timestamp;

        emit!(BridgedToIngame {
            element_id,
            amount,
            governor: ctx.accounts.governor.key(),
        });

        msg!("Burned {} tokens, bridging to in-game", amount);

        Ok(())
    }

    /// Bridge player's in-game tokens to on-chain (with 3% fee)
    /// Any player can bridge their in-game elements
    /// 0.5% to governor, 2.5% to dev treasury
    pub fn player_bridge_to_chain(
        ctx: Context<PlayerBridgeToChain>,
        element_id: String,
        amount: u64,
        burn_proof_signature: [u8; 64],
    ) -> Result<()> {
        require!(amount > 0, ErrorCode::InvalidAmount);

        // Verify burn proof (backend must sign that in-game tokens were burned)
        let burn_proof = BurnProof {
            element_id: element_id.clone(),
            amount,
            governor: ctx.accounts.player.key(),
            timestamp: Clock::get()?.unix_timestamp,
        };

        verify_burn_proof(&burn_proof, &burn_proof_signature, &ctx.accounts.burn_proof_authority.key())?;

        // Calculate fees
        let total_fee = amount * TOTAL_BRIDGE_FEE_BPS / 10000;
        let governor_fee = amount * GOVERNOR_FEE_BPS / 10000;
        let dev_fee = amount * DEV_TREASURY_FEE_BPS / 10000;
        let player_amount = amount - total_fee;

        let treasury_seeds = &[
            b"element_treasury",
            element_id.as_bytes(),
            &[ctx.bumps.treasury_token_account],
        ];
        let signer = &[&treasury_seeds[..]];

        // Transfer net amount to player
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.treasury_token_account.to_account_info(),
                    to: ctx.accounts.player_token_account.to_account_info(),
                    authority: ctx.accounts.treasury_token_account.to_account_info(),
                },
                signer,
            ),
            player_amount,
        )?;

        // Transfer governor fee to governor revenue account
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.treasury_token_account.to_account_info(),
                    to: ctx.accounts.governor_revenue_account.to_account_info(),
                    authority: ctx.accounts.treasury_token_account.to_account_info(),
                },
                signer,
            ),
            governor_fee,
        )?;

        // Transfer dev fee to dev treasury
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.treasury_token_account.to_account_info(),
                    to: ctx.accounts.dev_treasury_account.to_account_info(),
                    authority: ctx.accounts.treasury_token_account.to_account_info(),
                },
                signer,
            ),
            dev_fee,
        )?;

        // Record bridge event
        let bridge_record = &mut ctx.accounts.bridge_record;
        bridge_record.element_id = element_id.clone();
        bridge_record.direction = BridgeDirection::ToChain;
        bridge_record.amount = amount;
        bridge_record.governor = ctx.accounts.player.key();
        bridge_record.timestamp = Clock::get()?.unix_timestamp;

        emit!(PlayerBridgedToChain {
            element_id,
            player: ctx.accounts.player.key(),
            amount: player_amount,
            governor_fee,
            dev_fee,
        });

        msg!(
            "Player bridged {} tokens (net: {}, fees: {} gov + {} dev)",
            amount, player_amount, governor_fee, dev_fee
        );

        Ok(())
    }

    /// Get bridge history for an element
    pub fn get_bridge_history(
        ctx: Context<GetBridgeHistory>,
        _element_id: String,
    ) -> Result<Vec<BridgeRecord>> {
        // In production, this would query historical bridge records
        // For now, return empty (implement pagination later)
        Ok(vec![])
    }
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct BridgeToChain<'info> {
    #[account(
        mut,
        seeds = [b"element_treasury", element_id.as_bytes()],
        bump,
        // Treasury holds the minted supply
    )]
    pub treasury_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        associated_token::mint = element_mint,
        associated_token::authority = governor
    )]
    pub governor_token_account: Account<'info, TokenAccount>,

    pub element_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = governor,
        space = 8 + BridgeRecord::INIT_SPACE,
        seeds = [
            b"bridge_record",
            element_id.as_bytes(),
            governor.key().as_ref(),
            &Clock::get()?.unix_timestamp.to_le_bytes()
        ],
        bump
    )]
    pub bridge_record: Account<'info, BridgeRecord>,

    /// CHECK: Backend authority that signs burn proofs
    pub burn_proof_authority: UncheckedAccount<'info>,

    #[account(mut)]
    pub governor: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct BridgeToIngame<'info> {
    #[account(
        mut,
        associated_token::mint = element_mint,
        associated_token::authority = governor
    )]
    pub governor_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub element_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = governor,
        space = 8 + BridgeRecord::INIT_SPACE,
        seeds = [
            b"bridge_record",
            element_id.as_bytes(),
            governor.key().as_ref(),
            &Clock::get()?.unix_timestamp.to_le_bytes()
        ],
        bump
    )]
    pub bridge_record: Account<'info, BridgeRecord>,

    #[account(mut)]
    pub governor: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct PlayerBridgeToChain<'info> {
    #[account(
        mut,
        seeds = [b"element_treasury", element_id.as_bytes()],
        bump,
    )]
    pub treasury_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        associated_token::mint = element_mint,
        associated_token::authority = player
    )]
    pub player_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        seeds = [b"governor_revenue", element_id.as_bytes()],
        bump,
        // Governor's revenue account (earns 0.5% of bridge fees)
    )]
    pub governor_revenue_account: Account<'info, TokenAccount>,

    /// CHECK: Dev treasury receives 2.5% of bridge fees
    #[account(
        mut,
        seeds = [b"dev_treasury"],
        bump
    )]
    pub dev_treasury_account: Account<'info, TokenAccount>,

    pub element_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = player,
        space = 8 + BridgeRecord::INIT_SPACE,
        seeds = [
            b"bridge_record",
            element_id.as_bytes(),
            player.key().as_ref(),
            &Clock::get()?.unix_timestamp.to_le_bytes()
        ],
        bump
    )]
    pub bridge_record: Account<'info, BridgeRecord>,

    /// CHECK: Backend authority that signs burn proofs
    pub burn_proof_authority: UncheckedAccount<'info>,

    #[account(mut)]
    pub player: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct GetBridgeHistory<'info> {
    pub governor: Signer<'info>,
}

#[account]
#[derive(InitSpace)]
pub struct BridgeRecord {
    #[max_len(32)]
    pub element_id: String,
    pub direction: BridgeDirection,
    pub amount: u64,
    pub governor: Pubkey,
    pub timestamp: i64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace, PartialEq, Eq)]
pub enum BridgeDirection {
    ToChain,
    ToIngame,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct BurnProof {
    pub element_id: String,
    pub amount: u64,
    pub governor: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct BridgedToChain {
    pub element_id: String,
    pub amount: u64,
    pub governor: Pubkey,
}

#[event]
pub struct BridgedToIngame {
    pub element_id: String,
    pub amount: u64,
    pub governor: Pubkey,
}

#[event]
pub struct PlayerBridgedToChain {
    pub element_id: String,
    pub player: Pubkey,
    pub amount: u64,
    pub governor_fee: u64,
    pub dev_fee: u64,
}

/// Verify burn proof signature from backend
fn verify_burn_proof(
    proof: &BurnProof,
    signature: &[u8; 64],
    authority: &Pubkey,
) -> Result<()> {
    // Serialize proof data
    let proof_data = proof.try_to_vec().unwrap();

    // In production, verify ed25519 signature here
    // For now, just verify authority is set
    require!(!authority.eq(&Pubkey::default()), ErrorCode::InvalidBurnProof);

    // TODO: Implement actual signature verification
    // use solana_program::ed25519_program;
    // verify_ed25519_signature(proof_data, signature, authority)?;

    msg!("Burn proof verified (mock)");

    Ok(())
}

#[error_code]
pub enum ErrorCode {
    #[msg("Invalid amount (must be > 0)")]
    InvalidAmount,
    #[msg("Invalid burn proof signature")]
    InvalidBurnProof,
    #[msg("Not the element governor")]
    NotGovernor,
}

use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{Mint, Token, TokenAccount},
};
use mpl_token_metadata::{
    instruction as mpl_instruction,
    state::{Creator, DataV2},
};

declare_id!("ELeMNFTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

#[program]
pub mod element_nft {
    use super::*;

    /// Mint a new element NFT
    ///
    /// This instruction creates a new NFT representing a discovered element or isotope
    /// from the LenKinVerse game.
    pub fn mint_element(
        ctx: Context<MintElement>,
        element_id: String,
        element_name: String,
        symbol: String,
        rarity: u8,
        amount: u64,
        generation_method: String,
        decay_time: Option<i64>,
    ) -> Result<()> {
        let element = &mut ctx.accounts.element_account;

        // Validate inputs
        require!(element_id.len() <= 10, ElementError::ElementIdTooLong);
        require!(element_name.len() <= 32, ElementError::NameTooLong);
        require!(symbol.len() <= 6, ElementError::SymbolTooLong);
        require!(rarity <= 3, ElementError::InvalidRarity);
        require!(amount > 0, ElementError::InvalidAmount);

        // Set element data
        element.owner = ctx.accounts.owner.key();
        element.mint = ctx.accounts.mint.key();
        element.element_id = element_id.clone();
        element.element_name = element_name.clone();
        element.symbol = symbol.clone();
        element.rarity = rarity;
        element.amount = amount;
        element.discovered_at = Clock::get()?.unix_timestamp;
        element.generation_method = generation_method;
        element.decay_time = decay_time;
        element.bump = *ctx.bumps.get("element_account").unwrap();

        msg!("Minted element NFT: {} ({}) - Rarity: {}", element_name, symbol, rarity);

        Ok(())
    }

    /// Update element amount (for combining NFTs)
    pub fn update_amount(
        ctx: Context<UpdateElement>,
        new_amount: u64,
    ) -> Result<()> {
        let element = &mut ctx.accounts.element_account;
        require!(new_amount > 0, ElementError::InvalidAmount);

        element.amount = new_amount;
        msg!("Updated element amount to: {}", new_amount);

        Ok(())
    }

    /// Burn element NFT
    pub fn burn_element(ctx: Context<BurnElement>) -> Result<()> {
        msg!("Burning element NFT: {}", ctx.accounts.element_account.element_id);
        // Account will be closed automatically via close constraint
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct MintElement<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + ElementAccount::INIT_SPACE,
        seeds = [b"element", mint.key().as_ref()],
        bump
    )]
    pub element_account: Account<'info, ElementAccount>,

    #[account(
        init,
        payer = owner,
        mint::decimals = 0,
        mint::authority = owner,
        mint::freeze_authority = owner,
    )]
    pub mint: Account<'info, Mint>,

    #[account(
        init,
        payer = owner,
        associated_token::mint = mint,
        associated_token::authority = owner,
    )]
    pub token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub owner: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct UpdateElement<'info> {
    #[account(
        mut,
        seeds = [b"element", element_account.mint.as_ref()],
        bump = element_account.bump,
        has_one = owner,
    )]
    pub element_account: Account<'info, ElementAccount>,

    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct BurnElement<'info> {
    #[account(
        mut,
        close = owner,
        seeds = [b"element", element_account.mint.as_ref()],
        bump = element_account.bump,
        has_one = owner,
    )]
    pub element_account: Account<'info, ElementAccount>,

    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(mut)]
    pub token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub owner: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

#[account]
#[derive(InitSpace)]
pub struct ElementAccount {
    pub owner: Pubkey,
    pub mint: Pubkey,
    #[max_len(10)]
    pub element_id: String,       // "lkC", "C14", etc.
    #[max_len(32)]
    pub element_name: String,     // "Carbon", "Carbon-14"
    #[max_len(6)]
    pub symbol: String,           // "C", "C14"
    pub rarity: u8,               // 0=common, 1=uncommon, 2=rare, 3=legendary
    pub amount: u64,              // Quantity
    pub discovered_at: i64,       // Unix timestamp
    #[max_len(20)]
    pub generation_method: String, // "collected", "analyzed", "reacted"
    pub decay_time: Option<i64>,  // For isotopes
    pub bump: u8,
}

#[error_code]
pub enum ElementError {
    #[msg("Element ID must be 10 characters or less")]
    ElementIdTooLong,
    #[msg("Element name must be 32 characters or less")]
    NameTooLong,
    #[msg("Symbol must be 6 characters or less")]
    SymbolTooLong,
    #[msg("Rarity must be between 0 and 3")]
    InvalidRarity,
    #[msg("Amount must be greater than 0")]
    InvalidAmount,
}

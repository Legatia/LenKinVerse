use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

declare_id!("MarketP1aceProgram11111111111111111111111111");

#[program]
pub mod marketplace {
    use super::*;

    /// Create a new listing for an element NFT
    ///
    /// This instruction lists an element NFT for sale at a specified price in alSOL.
    /// The NFT is transferred to an escrow account controlled by the marketplace PDA.
    pub fn create_listing(
        ctx: Context<CreateListing>,
        price_alsol: u64, // Price in alSOL (smallest unit)
    ) -> Result<()> {
        let listing = &mut ctx.accounts.listing_account;

        require!(price_alsol > 0, MarketplaceError::InvalidPrice);

        // Set listing data
        listing.seller = ctx.accounts.seller.key();
        listing.element_mint = ctx.accounts.element_mint.key();
        listing.element_account = ctx.accounts.element_account.key();
        listing.price_alsol = price_alsol;
        listing.created_at = Clock::get()?.unix_timestamp;
        listing.is_active = true;
        listing.bump = ctx.bumps.listing_account;

        // Transfer NFT to escrow
        let cpi_accounts = Transfer {
            from: ctx.accounts.seller_token_account.to_account_info(),
            to: ctx.accounts.escrow_token_account.to_account_info(),
            authority: ctx.accounts.seller.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, 1)?; // NFTs have amount = 1

        msg!(
            "Created listing for element {} at {} alSOL",
            ctx.accounts.element_mint.key(),
            price_alsol
        );

        Ok(())
    }

    /// Cancel an active listing
    ///
    /// Returns the NFT from escrow back to the seller and marks the listing as inactive.
    pub fn cancel_listing(ctx: Context<CancelListing>) -> Result<()> {
        require!(ctx.accounts.listing_account.is_active, MarketplaceError::ListingNotActive);

        // Get bump and keys before mutable borrow
        let seller = ctx.accounts.listing_account.seller;
        let element_mint = ctx.accounts.listing_account.element_mint;
        let bump = ctx.accounts.listing_account.bump;

        // Transfer NFT back to seller using PDA as authority
        let seeds = &[
            b"listing",
            seller.as_ref(),
            element_mint.as_ref(),
            &[bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.escrow_token_account.to_account_info(),
            to: ctx.accounts.seller_token_account.to_account_info(),
            authority: ctx.accounts.listing_account.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);
        token::transfer(cpi_ctx, 1)?;

        // Mark listing as inactive after transfer
        let listing = &mut ctx.accounts.listing_account;
        listing.is_active = false;

        msg!("Cancelled listing for element {}", element_mint);

        Ok(())
    }

    /// Update the price of an active listing
    pub fn update_price(
        ctx: Context<UpdatePrice>,
        new_price_alsol: u64,
    ) -> Result<()> {
        let listing = &mut ctx.accounts.listing_account;

        require!(listing.is_active, MarketplaceError::ListingNotActive);
        require!(new_price_alsol > 0, MarketplaceError::InvalidPrice);

        let old_price = listing.price_alsol;
        listing.price_alsol = new_price_alsol;

        msg!(
            "Updated listing price from {} to {} alSOL",
            old_price,
            new_price_alsol
        );

        Ok(())
    }

    /// Buy an NFT from the marketplace
    ///
    /// Transfers alSOL from buyer to seller and transfers the NFT from escrow to buyer.
    pub fn buy_nft(ctx: Context<BuyNft>) -> Result<()> {
        require!(ctx.accounts.listing_account.is_active, MarketplaceError::ListingNotActive);

        // Get values before mutable borrow
        let price = ctx.accounts.listing_account.price_alsol;
        let seller = ctx.accounts.listing_account.seller;
        let element_mint = ctx.accounts.listing_account.element_mint;
        let bump = ctx.accounts.listing_account.bump;

        // Transfer alSOL from buyer to seller
        let cpi_accounts = Transfer {
            from: ctx.accounts.buyer_alsol_account.to_account_info(),
            to: ctx.accounts.seller_alsol_account.to_account_info(),
            authority: ctx.accounts.buyer.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, price)?;

        // Transfer NFT from escrow to buyer using PDA as authority
        let seeds = &[
            b"listing",
            seller.as_ref(),
            element_mint.as_ref(),
            &[bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.escrow_token_account.to_account_info(),
            to: ctx.accounts.buyer_token_account.to_account_info(),
            authority: ctx.accounts.listing_account.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);
        token::transfer(cpi_ctx, 1)?;

        // Mark listing as inactive
        let listing = &mut ctx.accounts.listing_account;
        listing.is_active = false;

        msg!(
            "Sold element {} for {} alSOL",
            element_mint,
            price
        );

        Ok(())
    }

    /// Swap SOL for alSOL (1:1 ratio)
    ///
    /// Transfers SOL to dev vault and transfers alSOL from treasury to buyer.
    pub fn swap_sol_for_alsol(
        ctx: Context<SwapSolForAlsol>,
        sol_amount: u64, // Amount in lamports
    ) -> Result<()> {
        require!(sol_amount > 0, MarketplaceError::InvalidAmount);

        // Transfer SOL from buyer to dev vault
        let transfer_ix = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.buyer.key(),
            &ctx.accounts.dev_vault.key(),
            sol_amount,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_ix,
            &[
                ctx.accounts.buyer.to_account_info(),
                ctx.accounts.dev_vault.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
        )?;

        // Transfer alSOL from treasury to buyer (1:1 ratio, same amount with 9 decimals)
        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_alsol_account.to_account_info(),
            to: ctx.accounts.buyer_alsol_account.to_account_info(),
            authority: ctx.accounts.treasury_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, sol_amount)?; // 1 lamport SOL = 1 lamport alSOL

        msg!("Swapped {} SOL for {} alSOL", sol_amount as f64 / 1e9, sol_amount as f64 / 1e9);

        Ok(())
    }

    /// Swap LKC for alSOL (1,000,000:1 ratio)
    ///
    /// Transfers 1,000,000 LKC to dev vault and transfers 1 alSOL from treasury to buyer.
    pub fn swap_lkc_for_alsol(
        ctx: Context<SwapLkcForAlsol>,
        lkc_amount: u64, // Amount of LKC tokens (must be multiple of 1M)
    ) -> Result<()> {
        const LKC_PER_ALSOL: u64 = 1_000_000; // 1 million LKC = 1 alSOL

        require!(lkc_amount > 0, MarketplaceError::InvalidAmount);
        require!(lkc_amount % LKC_PER_ALSOL == 0, MarketplaceError::InvalidLkcAmount);

        // Calculate alSOL amount (1M LKC = 1 alSOL with 9 decimals)
        let alsol_amount = (lkc_amount / LKC_PER_ALSOL) * 1_000_000_000; // Convert to alSOL with 9 decimals

        // Transfer LKC from buyer to dev vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.buyer_lkc_account.to_account_info(),
            to: ctx.accounts.dev_lkc_vault.to_account_info(),
            authority: ctx.accounts.buyer.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, lkc_amount)?;

        // Transfer alSOL from treasury to buyer
        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_alsol_account.to_account_info(),
            to: ctx.accounts.buyer_alsol_account.to_account_info(),
            authority: ctx.accounts.treasury_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, alsol_amount)?;

        msg!(
            "Swapped {} LKC for {} alSOL",
            lkc_amount,
            alsol_amount as f64 / 1e9
        );

        Ok(())
    }
}

#[derive(Accounts)]
pub struct CreateListing<'info> {
    #[account(
        init,
        payer = seller,
        space = 8 + ListingAccount::INIT_SPACE,
        seeds = [b"listing", seller.key().as_ref(), element_mint.key().as_ref()],
        bump
    )]
    pub listing_account: Account<'info, ListingAccount>,

    /// CHECK: Element account from element-nft program
    pub element_account: UncheckedAccount<'info>,

    pub element_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = element_mint,
        associated_token::authority = seller,
    )]
    pub seller_token_account: Account<'info, TokenAccount>,

    #[account(
        init,
        payer = seller,
        associated_token::mint = element_mint,
        associated_token::authority = listing_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub seller: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct CancelListing<'info> {
    #[account(
        mut,
        seeds = [b"listing", listing_account.seller.as_ref(), listing_account.element_mint.as_ref()],
        bump = listing_account.bump,
        has_one = seller,
    )]
    pub listing_account: Account<'info, ListingAccount>,

    #[account(
        mut,
        associated_token::mint = listing_account.element_mint,
        associated_token::authority = listing_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        associated_token::mint = listing_account.element_mint,
        associated_token::authority = seller,
    )]
    pub seller_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub seller: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct UpdatePrice<'info> {
    #[account(
        mut,
        seeds = [b"listing", listing_account.seller.as_ref(), listing_account.element_mint.as_ref()],
        bump = listing_account.bump,
        has_one = seller,
    )]
    pub listing_account: Account<'info, ListingAccount>,

    pub seller: Signer<'info>,
}

#[derive(Accounts)]
pub struct BuyNft<'info> {
    #[account(
        mut,
        seeds = [b"listing", listing_account.seller.as_ref(), element_mint.key().as_ref()],
        bump = listing_account.bump,
        constraint = listing_account.element_mint == element_mint.key(),
    )]
    pub listing_account: Account<'info, ListingAccount>,

    pub element_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = element_mint,
        associated_token::authority = listing_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(
        init,
        payer = buyer,
        associated_token::mint = element_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_token_account: Account<'info, TokenAccount>,

    /// CHECK: Seller's wallet address from listing
    #[account(mut, address = listing_account.seller)]
    pub seller: UncheckedAccount<'info>,

    pub alsol_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = alsol_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_alsol_account: Account<'info, TokenAccount>,

    #[account(
        init,
        payer = buyer,
        associated_token::mint = alsol_mint,
        associated_token::authority = seller,
    )]
    pub seller_alsol_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[account]
#[derive(InitSpace)]
pub struct ListingAccount {
    pub seller: Pubkey,
    pub element_mint: Pubkey,
    /// CHECK: Element account reference
    pub element_account: Pubkey,
    pub price_alsol: u64,
    pub created_at: i64,
    pub is_active: bool,
    pub bump: u8,
}

#[derive(Accounts)]
pub struct SwapSolForAlsol<'info> {
    /// CHECK: Dev vault receiving SOL
    #[account(mut)]
    pub dev_vault: UncheckedAccount<'info>,

    pub alsol_mint: Account<'info, Mint>,

    #[account(
        mut,
        token::mint = alsol_mint,
        token::authority = treasury_authority,
    )]
    pub treasury_alsol_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        associated_token::mint = alsol_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_alsol_account: Account<'info, TokenAccount>,

    /// CHECK: Treasury authority (dev team wallet or multisig)
    pub treasury_authority: Signer<'info>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct SwapLkcForAlsol<'info> {
    pub lkc_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = lkc_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_lkc_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        associated_token::mint = lkc_mint,
        associated_token::authority = dev_vault_authority,
    )]
    pub dev_lkc_vault: Account<'info, TokenAccount>,

    /// CHECK: Dev vault authority
    pub dev_vault_authority: UncheckedAccount<'info>,

    pub alsol_mint: Account<'info, Mint>,

    #[account(
        mut,
        token::mint = alsol_mint,
        token::authority = treasury_authority,
    )]
    pub treasury_alsol_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        associated_token::mint = alsol_mint,
        associated_token::authority = buyer,
    )]
    pub buyer_alsol_account: Account<'info, TokenAccount>,

    /// CHECK: Treasury authority (dev team wallet or multisig)
    pub treasury_authority: Signer<'info>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[error_code]
pub enum MarketplaceError {
    #[msg("Price must be greater than 0")]
    InvalidPrice,
    #[msg("Listing is not active")]
    ListingNotActive,
    #[msg("Insufficient balance")]
    InsufficientBalance,
    #[msg("Amount must be greater than 0")]
    InvalidAmount,
    #[msg("LKC amount must be a multiple of 1,000,000")]
    InvalidLkcAmount,
}

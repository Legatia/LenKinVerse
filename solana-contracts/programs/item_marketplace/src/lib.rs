use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::metadata::{
    Metadata as Metaplex,
    create_metadata_accounts_v3,
    CreateMetadataAccountsV3,
    mpl_token_metadata::types::{DataV2, Creator},
};

declare_id!("F7TehQFrx3XkuMsLPcmKLz44UxTWWfyodNLSungdqoRX");

#[program]
pub mod item_marketplace {
    use super::*;

    /// Mint an in-game item as NFT
    /// Called by backend after player obtains item (gloves, isotope, etc.)
    pub fn mint_item_nft(
        ctx: Context<MintItemNFT>,
        item_type: String,
        item_level: u8,
        item_id: String,          // Pre-formatted: "ItemType_Level"
        item_attributes: String,  // JSON encoded attributes
        uri: String,
    ) -> Result<()> {
        require!(item_type.len() <= 32, ErrorCode::ItemTypeTooLong);
        require!(item_id.len() <= 64, ErrorCode::ItemIdTooLong);
        require!(item_attributes.len() <= 200, ErrorCode::AttributesTooLong);

        // Mint NFT (supply = 1)
        let cpi_accounts = anchor_spl::token::MintTo {
            mint: ctx.accounts.item_mint.to_account_info(),
            to: ctx.accounts.owner_token_account.to_account_info(),
            authority: ctx.accounts.item_mint.to_account_info(),
        };
        let owner_key = ctx.accounts.owner.key();
        let seeds = &[
            b"item_mint",
            owner_key.as_ref(),
            item_id.as_bytes(),
            &[ctx.bumps.item_mint],
        ];
        let signer = &[&seeds[..]];

        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

        anchor_spl::token::mint_to(cpi_ctx, 1)?; // Mint exactly 1 NFT

        // Create metadata
        let token_data: DataV2 = DataV2 {
            name: format!("LenKinVerse {} Lv.{}", item_type, item_level),
            symbol: "LKVITEM".to_string(),
            uri,
            seller_fee_basis_points: 500, // 5% royalty
            creators: Some(vec![Creator {
                address: ctx.accounts.owner.key(),
                verified: false,
                share: 100,
            }]),
            collection: None,
            uses: None,
        };

        let metadata_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_metadata_program.to_account_info(),
            CreateMetadataAccountsV3 {
                payer: ctx.accounts.owner.to_account_info(),
                update_authority: ctx.accounts.item_mint.to_account_info(),
                mint: ctx.accounts.item_mint.to_account_info(),
                metadata: ctx.accounts.metadata.to_account_info(),
                mint_authority: ctx.accounts.item_mint.to_account_info(),
                system_program: ctx.accounts.system_program.to_account_info(),
                rent: ctx.accounts.rent.to_account_info(),
            },
            signer,
        );

        create_metadata_accounts_v3(
            metadata_ctx,
            token_data,
            true,  // is_mutable
            true,  // update_authority_is_signer
            None,  // collection_details
        )?;

        msg!("Minted NFT: {} Lv.{} to {:?}", item_type, item_level, ctx.accounts.owner.key());

        Ok(())
    }

    /// List an item NFT for sale on the marketplace
    pub fn list_item(
        ctx: Context<ListItem>,
        price: u64,
    ) -> Result<()> {
        require!(price > 0, ErrorCode::InvalidPrice);

        let listing = &mut ctx.accounts.listing;
        listing.seller = ctx.accounts.seller.key();
        listing.item_mint = ctx.accounts.item_mint.key();
        listing.price = price;
        listing.is_active = true;
        listing.listed_at = Clock::get()?.unix_timestamp;

        // Transfer NFT to escrow
        let cpi_accounts = Transfer {
            from: ctx.accounts.seller_token_account.to_account_info(),
            to: ctx.accounts.escrow_token_account.to_account_info(),
            authority: ctx.accounts.seller.to_account_info(),
        };

        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        token::transfer(cpi_ctx, 1)?;

        msg!("Listed item {:?} for {} lamports", ctx.accounts.item_mint.key(), price);

        Ok(())
    }

    /// Buy a listed item from the marketplace
    pub fn buy_item(
        ctx: Context<BuyItem>,
    ) -> Result<()> {
        require!(ctx.accounts.listing.is_active, ErrorCode::ListingNotActive);

        let listing_price = ctx.accounts.listing.price;
        let listing_seller = ctx.accounts.listing.seller;

        // Transfer SOL from buyer to seller
        let ix = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.buyer.key(),
            &listing_seller,
            listing_price,
        );

        anchor_lang::solana_program::program::invoke(
            &ix,
            &[
                ctx.accounts.buyer.to_account_info(),
                ctx.accounts.seller_account.to_account_info(),
            ],
        )?;

        // Transfer NFT from escrow to buyer
        let item_mint_key = ctx.accounts.item_mint.key();
        let bump = ctx.bumps.listing;
        let seeds = &[
            b"listing",
            listing_seller.as_ref(),
            item_mint_key.as_ref(),
            &[bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.escrow_token_account.to_account_info(),
            to: ctx.accounts.buyer_token_account.to_account_info(),
            authority: ctx.accounts.listing.to_account_info(),
        };

        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

        token::transfer(cpi_ctx, 1)?;

        // Mark listing as inactive
        ctx.accounts.listing.is_active = false;

        msg!("Item {:?} sold to {:?} for {} lamports",
            ctx.accounts.item_mint.key(),
            ctx.accounts.buyer.key(),
            listing_price
        );

        Ok(())
    }

    /// Cancel a listing and return NFT to seller
    pub fn cancel_listing(
        ctx: Context<CancelListing>,
    ) -> Result<()> {
        require!(ctx.accounts.listing.is_active, ErrorCode::ListingNotActive);
        require!(ctx.accounts.listing.seller == ctx.accounts.seller.key(), ErrorCode::NotListingSeller);

        // Transfer NFT back to seller
        let item_mint_key = ctx.accounts.item_mint.key();
        let seller_key = ctx.accounts.listing.seller;
        let bump = ctx.bumps.listing;

        let seeds = &[
            b"listing",
            seller_key.as_ref(),
            item_mint_key.as_ref(),
            &[bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.escrow_token_account.to_account_info(),
            to: ctx.accounts.seller_token_account.to_account_info(),
            authority: ctx.accounts.listing.to_account_info(),
        };

        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

        token::transfer(cpi_ctx, 1)?;

        // Mark listing as inactive
        ctx.accounts.listing.is_active = false;

        msg!("Listing cancelled for item {:?}", ctx.accounts.item_mint.key());

        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(item_type: String, item_level: u8, item_id: String)]
pub struct MintItemNFT<'info> {
    #[account(
        init,
        payer = owner,
        mint::decimals = 0, // NFT
        mint::authority = item_mint,
        seeds = [
            b"item_mint",
            owner.key().as_ref(),
            item_id.as_bytes()
        ],
        bump
    )]
    pub item_mint: Account<'info, Mint>,

    #[account(
        init_if_needed,
        payer = owner,
        associated_token::mint = item_mint,
        associated_token::authority = owner
    )]
    pub owner_token_account: Account<'info, TokenAccount>,

    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub metadata: UncheckedAccount<'info>,

    #[account(mut)]
    pub owner: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub token_metadata_program: Program<'info, Metaplex>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct ListItem<'info> {
    #[account(
        init,
        payer = seller,
        space = 8 + Listing::INIT_SPACE,
        seeds = [b"listing", seller.key().as_ref(), item_mint.key().as_ref()],
        bump
    )]
    pub listing: Account<'info, Listing>,

    pub item_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = item_mint,
        associated_token::authority = seller
    )]
    pub seller_token_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = seller,
        associated_token::mint = item_mint,
        associated_token::authority = listing
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub seller: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct BuyItem<'info> {
    #[account(
        mut,
        seeds = [b"listing", listing.seller.as_ref(), item_mint.key().as_ref()],
        bump
    )]
    pub listing: Account<'info, Listing>,

    pub item_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = item_mint,
        associated_token::authority = listing
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        associated_token::mint = item_mint,
        associated_token::authority = buyer
    )]
    pub buyer_token_account: Account<'info, TokenAccount>,

    /// CHECK: Seller account to receive payment
    #[account(mut)]
    pub seller_account: UncheckedAccount<'info>,

    #[account(mut)]
    pub buyer: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CancelListing<'info> {
    #[account(
        mut,
        seeds = [b"listing", listing.seller.as_ref(), item_mint.key().as_ref()],
        bump
    )]
    pub listing: Account<'info, Listing>,

    pub item_mint: Account<'info, Mint>,

    #[account(
        mut,
        associated_token::mint = item_mint,
        associated_token::authority = listing
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        associated_token::mint = item_mint,
        associated_token::authority = seller
    )]
    pub seller_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub seller: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

#[account]
#[derive(InitSpace)]
pub struct Listing {
    pub seller: Pubkey,
    pub item_mint: Pubkey,
    pub price: u64,
    pub is_active: bool,
    pub listed_at: i64,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Item type too long (max 32 characters)")]
    ItemTypeTooLong,
    #[msg("Item ID too long (max 64 characters)")]
    ItemIdTooLong,
    #[msg("Attributes too long (max 200 characters)")]
    AttributesTooLong,
    #[msg("Invalid price (must be > 0)")]
    InvalidPrice,
    #[msg("Listing is not active")]
    ListingNotActive,
    #[msg("You are not the seller of this listing")]
    NotListingSeller,
}

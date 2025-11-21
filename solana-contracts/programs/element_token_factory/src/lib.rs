use anchor_lang::prelude::*;
use anchor_lang::system_program::{transfer, Transfer as SystemTransfer};
use anchor_spl::token::{self, Mint, Token, TokenAccount, MintTo};
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::metadata::{
    create_metadata_accounts_v3,
    mpl_token_metadata::types::DataV2,
    CreateMetadataAccountsV3,
    Metadata as Metaplex,
};

declare_id!("DFEdDQp4Ybv1LRtM6EHu8Nxwt1Bvpo6maFJFBkGj5WTQ");

const REGISTRATION_FEE: u64 = 10 * 1_000_000_000; // 10 SOL
const LOCK_PERIOD_SECONDS: i64 = 1800; // 30 minutes

// Fixed initial supply for all elements (1M tokens with 6 decimals)
// Future: Different registration fees per element (e.g., LKO=10 SOL, LKAu=100 SOL)
const INITIAL_SUPPLY: u64 = 1_000_000 * 1_000_000; // 1M tokens

#[program]
pub mod element_token_factory {
    use super::*;

    /// Register a new element and create its SPL token
    /// Requires 10 SOL payment to protocol treasury
    /// Supports co-governor if registered in same slot
    pub fn register_element(
        ctx: Context<RegisterElement>,
        element_id: String,
        rarity: u8,
        uri: String,
    ) -> Result<()> {
        require!(element_id.len() <= 32, ErrorCode::ElementIdTooLong);
        require!(rarity <= 3, ErrorCode::InvalidRarity);

        let element_registry = &mut ctx.accounts.element_registry;
        let current_time = Clock::get()?.unix_timestamp;
        let current_slot = Clock::get()?.slot;

        // Check if element already exists
        let existing_element_idx = element_registry
            .elements
            .iter()
            .position(|e| e.element_id == element_id);

        if let Some(idx) = existing_element_idx {
            // Element exists - check for co-governor scenario
            let element = &mut element_registry.elements[idx];

            // Only allow co-governor if registered in SAME SLOT
            require!(
                element.registration_slot == current_slot,
                ErrorCode::ElementAlreadyRegistered
            );

            // Assign co-governor
            require!(element.co_governor.is_none(), ErrorCode::CoGovernorAlreadyAssigned);
            element.co_governor = Some(ctx.accounts.governor.key());

            msg!(
                "Co-governor assigned for {}: {:?}",
                element_id,
                ctx.accounts.governor.key()
            );
        } else {
            // New registration - collect 10 SOL fee
            transfer(
                CpiContext::new(
                    ctx.accounts.system_program.to_account_info(),
                    SystemTransfer {
                        from: ctx.accounts.governor.to_account_info(),
                        to: ctx.accounts.protocol_treasury.to_account_info(),
                    },
                ),
                REGISTRATION_FEE,
            )?;

            // Create element data
            let element_data = ElementData {
                element_id: element_id.clone(),
                mint: ctx.accounts.element_mint.key(),
                governor: ctx.accounts.governor.key(),
                co_governor: None,
                registered_at: current_time,
                registration_slot: current_slot,
                tradeable_at: current_time + LOCK_PERIOD_SECONDS,
                is_tradeable: false,
                rarity,
            };

            element_registry.elements.push(element_data);
            element_registry.element_count += 1;

            // Create token metadata
            let token_data: DataV2 = DataV2 {
                name: format!("LenKinVerse {}", element_id),
                symbol: element_id.clone(),
                uri,
                seller_fee_basis_points: 0,
                creators: None,
                collection: None,
                uses: None,
            };

            let element_mint_bump = ctx.bumps.element_mint;
            let element_mint_seeds = &[
                b"element_mint",
                element_id.as_bytes(),
                &[element_mint_bump],
            ];
            let signer = &[&element_mint_seeds[..]];

            let metadata_ctx = CpiContext::new_with_signer(
                ctx.accounts.token_metadata_program.to_account_info(),
                CreateMetadataAccountsV3 {
                    payer: ctx.accounts.governor.to_account_info(),
                    update_authority: ctx.accounts.element_mint.to_account_info(),
                    mint: ctx.accounts.element_mint.to_account_info(),
                    metadata: ctx.accounts.metadata.to_account_info(),
                    mint_authority: ctx.accounts.element_mint.to_account_info(),
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

            // Mint fixed initial supply to treasury PDA
            token::mint_to(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    MintTo {
                        mint: ctx.accounts.element_mint.to_account_info(),
                        to: ctx.accounts.treasury_token_account.to_account_info(),
                        authority: ctx.accounts.element_mint.to_account_info(),
                    },
                    signer,
                ),
                INITIAL_SUPPLY,
            )?;

            msg!(
                "Element {} registered by {:?} (fee: {} SOL, initial supply: 1M tokens)",
                element_id,
                ctx.accounts.governor.key(),
                REGISTRATION_FEE / 1_000_000_000
            );
        }

        Ok(())
    }

    // REMOVED: mint_element_tokens
    // Reason: In-game elements are game data, not minted per discovery
    // Minting happens only when governor bridges via treasury_bridge program

    /// Mark element as tradeable after 30-minute lock period
    /// Anyone can call this once the lock period expires
    pub fn mark_tradeable(
        ctx: Context<MarkTradeable>,
        element_id: String,
    ) -> Result<()> {
        let element_registry = &mut ctx.accounts.element_registry;
        let current_time = Clock::get()?.unix_timestamp;

        // Find element
        let element = element_registry
            .elements
            .iter_mut()
            .find(|e| e.element_id == element_id)
            .ok_or(ErrorCode::ElementNotFound)?;

        // Check if already tradeable
        require!(!element.is_tradeable, ErrorCode::AlreadyTradeable);

        // Check if lock period has passed
        require!(
            current_time >= element.tradeable_at,
            ErrorCode::StillLocked
        );

        // Mark as tradeable
        element.is_tradeable = true;

        msg!("Element {} is now tradeable!", element_id);

        Ok(())
    }

    /// Get element info (view function)
    pub fn get_element_info(
        ctx: Context<GetElementInfo>,
        element_id: String,
    ) -> Result<ElementData> {
        let element_registry = &ctx.accounts.element_registry;

        let element = element_registry
            .elements
            .iter()
            .find(|e| e.element_id == element_id)
            .ok_or(ErrorCode::ElementNotFound)?;

        Ok(element.clone())
    }
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct RegisterElement<'info> {
    #[account(
        init_if_needed,
        payer = governor,
        space = 8 + ElementRegistry::INIT_SPACE,
        seeds = [b"element_registry"],
        bump
    )]
    pub element_registry: Account<'info, ElementRegistry>,

    #[account(
        init,
        payer = governor,
        mint::decimals = 6,
        mint::authority = element_mint,
        seeds = [b"element_mint", element_id.as_bytes()],
        bump
    )]
    pub element_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = governor,
        token::mint = element_mint,
        token::authority = treasury_token_account,
        seeds = [b"element_treasury", element_id.as_bytes()],
        bump
    )]
    pub treasury_token_account: Account<'info, TokenAccount>,

    #[account(
        init,
        payer = governor,
        token::mint = element_mint,
        token::authority = governor_revenue_account,
        seeds = [b"governor_revenue", element_id.as_bytes()],
        bump
    )]
    pub governor_revenue_account: Account<'info, TokenAccount>,

    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(mut)]
    pub metadata: UncheckedAccount<'info>,

    /// CHECK: Protocol treasury receives registration fees
    #[account(
        mut,
        seeds = [b"protocol_treasury"],
        bump
    )]
    pub protocol_treasury: UncheckedAccount<'info>,

    #[account(mut)]
    pub governor: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub token_metadata_program: Program<'info, Metaplex>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

// REMOVED: MintElementTokens account struct
// Not needed since minting happens only via bridge, not per discovery

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct MarkTradeable<'info> {
    #[account(
        mut,
        seeds = [b"element_registry"],
        bump
    )]
    pub element_registry: Account<'info, ElementRegistry>,
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct GetElementInfo<'info> {
    #[account(
        seeds = [b"element_registry"],
        bump
    )]
    pub element_registry: Account<'info, ElementRegistry>,
}

#[account]
#[derive(InitSpace)]
pub struct ElementRegistry {
    pub element_count: u64,
    #[max_len(100)] // Support up to 100 elements
    pub elements: Vec<ElementData>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub struct ElementData {
    #[max_len(32)]
    pub element_id: String,
    pub mint: Pubkey,
    pub governor: Pubkey,
    pub co_governor: Option<Pubkey>,
    pub registered_at: i64,
    pub registration_slot: u64, // For same-slot co-governor detection
    pub tradeable_at: i64,
    pub is_tradeable: bool,
    pub rarity: u8,
    // Note: total_minted tracked via treasury_bridge when governor bridges
    // Note: Tax collected in-game (not on-chain)
}

#[error_code]
pub enum ErrorCode {
    #[msg("Element ID too long (max 32 characters)")]
    ElementIdTooLong,
    #[msg("Invalid rarity level (0-3)")]
    InvalidRarity,
    #[msg("Element already registered (not same slot)")]
    ElementAlreadyRegistered,
    #[msg("Element not found")]
    ElementNotFound,
    #[msg("Element is still locked (30 min period)")]
    StillLocked,
    #[msg("Element is already tradeable")]
    AlreadyTradeable,
    #[msg("Co-governor already assigned")]
    CoGovernorAlreadyAssigned,
}

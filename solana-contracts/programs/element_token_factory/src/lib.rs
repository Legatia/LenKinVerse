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
const TAX_RATE_BPS: u64 = 1000; // 10% (basis points)
const LOCK_PERIOD_SECONDS: i64 = 1800; // 30 minutes

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

            // Create treasury token account PDA for this element
            let (treasury_pda, _bump) = Pubkey::find_program_address(
                &[b"element_treasury", element_id.as_bytes()],
                ctx.program_id,
            );

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
                total_minted: 0,
                treasury_balance: 0,
                total_taxed: 0,
                treasury_token_account: treasury_pda,
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
                &[&[
                    b"element_mint",
                    element_id.as_bytes(),
                    &[ctx.bumps.element_mint],
                ]],
            );

            create_metadata_accounts_v3(
                metadata_ctx,
                token_data,
                true,  // is_mutable
                true,  // update_authority_is_signer
                None,  // collection_details
            )?;

            msg!(
                "Element {} registered by {:?} (fee: {} SOL)",
                element_id,
                ctx.accounts.governor.key(),
                REGISTRATION_FEE / 1_000_000_000
            );
        }

        Ok(())
    }

    /// Mint element tokens with 10% tax to governor treasury
    /// During lock period: 2x yield - 10% tax
    /// After tradeable: 1x yield - 10% tax
    pub fn mint_element_tokens(
        ctx: Context<MintElementTokens>,
        element_id: String,
        raw_amount: u64, // Amount before tax/compensation
    ) -> Result<()> {
        let element_registry = &mut ctx.accounts.element_registry;

        // Find element
        let element = element_registry
            .elements
            .iter_mut()
            .find(|e| e.element_id == element_id)
            .ok_or(ErrorCode::ElementNotFound)?;

        // Calculate tax (10%)
        let tax_amount = raw_amount
            .checked_mul(TAX_RATE_BPS)
            .unwrap()
            .checked_div(10000)
            .unwrap();

        // Calculate player amount based on tradeable status
        let player_amount = if element.is_tradeable {
            // After lock: 1x yield - 10% tax
            raw_amount.checked_sub(tax_amount).unwrap()
        } else {
            // During lock: 2x yield - 10% tax
            raw_amount
                .checked_mul(2)
                .unwrap()
                .checked_sub(tax_amount)
                .unwrap()
        };

        // Update total minted
        element.total_minted = element.total_minted.checked_add(player_amount).unwrap();
        element.total_taxed = element.total_taxed.checked_add(tax_amount).unwrap();
        element.treasury_balance = element.treasury_balance.checked_add(tax_amount).unwrap();

        // Mint tokens to player
        let mint_seeds = &[
            b"element_mint",
            element_id.as_bytes(),
            &[ctx.bumps.element_mint],
        ];
        let signer = &[&mint_seeds[..]];

        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.element_mint.to_account_info(),
                    to: ctx.accounts.player_token_account.to_account_info(),
                    authority: ctx.accounts.element_mint.to_account_info(),
                },
                signer,
            ),
            player_amount,
        )?;

        // Mint tax to governor treasury
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
            tax_amount,
        )?;

        msg!(
            "Minted {} tokens: {} to player, {} to treasury ({}% tax, {} status)",
            raw_amount,
            player_amount,
            tax_amount,
            TAX_RATE_BPS / 100,
            if element.is_tradeable { "tradeable" } else { "locked 2x" }
        );

        Ok(())
    }

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

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct MintElementTokens<'info> {
    #[account(
        mut,
        seeds = [b"element_registry"],
        bump
    )]
    pub element_registry: Account<'info, ElementRegistry>,

    #[account(
        mut,
        seeds = [b"element_mint", element_id.as_bytes()],
        bump
    )]
    pub element_mint: Account<'info, Mint>,

    #[account(
        init_if_needed,
        payer = player,
        associated_token::mint = element_mint,
        associated_token::authority = player
    )]
    pub player_token_account: Account<'info, TokenAccount>,

    /// Treasury token account for this element (receives 10% tax)
    #[account(
        init_if_needed,
        payer = player,
        seeds = [b"element_treasury", element_id.as_bytes()],
        bump,
        token::mint = element_mint,
        token::authority = treasury_token_account, // Self-owned
    )]
    pub treasury_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub player: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

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
    pub total_minted: u64,
    pub treasury_balance: u64,  // Tax collected
    pub total_taxed: u64,       // Cumulative tax
    pub treasury_token_account: Pubkey, // PDA for tax tokens
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

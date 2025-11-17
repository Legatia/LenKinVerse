use anchor_lang::prelude::*;

declare_id!("DdRY1fU4938imQBQSEkxLzZyZcD9hBbAJBT3YfWMqPe3");

const MAX_PRICE_AGE_SECONDS: i64 = 300; // 5 minutes

#[program]
pub mod price_oracle {
    use super::*;

    /// Initialize the price oracle
    /// Only called once by the protocol deployer
    pub fn initialize_oracle(
        ctx: Context<InitializeOracle>,
        initial_lko_per_sol: u64,
    ) -> Result<()> {
        let oracle = &mut ctx.accounts.oracle;
        oracle.authority = ctx.accounts.authority.key();
        oracle.lko_per_sol = initial_lko_per_sol;
        oracle.last_updated = Clock::get()?.unix_timestamp;
        oracle.update_count = 0;
        oracle.is_active = true;

        emit!(OracleInitialized {
            authority: oracle.authority,
            initial_price: initial_lko_per_sol,
            timestamp: oracle.last_updated,
        });

        Ok(())
    }

    /// Update the LKO/SOL price
    /// Only callable by the authority (backend)
    pub fn update_price(
        ctx: Context<UpdatePrice>,
        new_lko_per_sol: u64,
    ) -> Result<()> {
        require!(ctx.accounts.oracle.is_active, ErrorCode::OracleInactive);
        require!(new_lko_per_sol > 0, ErrorCode::InvalidPrice);

        let oracle = &mut ctx.accounts.oracle;
        let old_price = oracle.lko_per_sol;

        oracle.lko_per_sol = new_lko_per_sol;
        oracle.last_updated = Clock::get()?.unix_timestamp;
        oracle.update_count += 1;

        emit!(PriceUpdated {
            old_price,
            new_price: new_lko_per_sol,
            timestamp: oracle.last_updated,
            update_count: oracle.update_count,
        });

        Ok(())
    }

    /// Update element-specific price
    /// For elements that have DEX pools, we can track individual prices
    pub fn update_element_price(
        ctx: Context<UpdateElementPrice>,
        element_id: String,
        price_per_sol: u64,
    ) -> Result<()> {
        require!(element_id.len() <= 32, ErrorCode::ElementIdTooLong);
        require!(price_per_sol > 0, ErrorCode::InvalidPrice);

        let element_oracle = &mut ctx.accounts.element_oracle;
        element_oracle.element_id = element_id.clone();
        element_oracle.price_per_sol = price_per_sol;
        element_oracle.last_updated = Clock::get()?.unix_timestamp;
        element_oracle.update_count += 1;

        emit!(ElementPriceUpdated {
            element_id,
            price_per_sol,
            timestamp: element_oracle.last_updated,
        });

        Ok(())
    }

    /// Get current LKO/SOL price with staleness check
    pub fn get_price(ctx: Context<GetPrice>) -> Result<u64> {
        let oracle = &ctx.accounts.oracle;
        let current_time = Clock::get()?.unix_timestamp;
        let age = current_time - oracle.last_updated;

        require!(age <= MAX_PRICE_AGE_SECONDS, ErrorCode::PriceStale);
        require!(oracle.is_active, ErrorCode::OracleInactive);

        Ok(oracle.lko_per_sol)
    }

    /// Pause/unpause the oracle (emergency function)
    pub fn set_oracle_active(
        ctx: Context<SetOracleActive>,
        is_active: bool,
    ) -> Result<()> {
        let oracle = &mut ctx.accounts.oracle;
        oracle.is_active = is_active;

        emit!(OracleStatusChanged {
            is_active,
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }

    /// Transfer oracle authority to new keypair
    pub fn transfer_authority(
        ctx: Context<TransferAuthority>,
        new_authority: Pubkey,
    ) -> Result<()> {
        let oracle = &mut ctx.accounts.oracle;
        let old_authority = oracle.authority;
        oracle.authority = new_authority;

        emit!(AuthorityTransferred {
            old_authority,
            new_authority,
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }
}

// Accounts

#[derive(Accounts)]
pub struct InitializeOracle<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + PriceOracle::INIT_SPACE,
        seeds = [b"price_oracle"],
        bump
    )]
    pub oracle: Account<'info, PriceOracle>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdatePrice<'info> {
    #[account(
        mut,
        seeds = [b"price_oracle"],
        bump,
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub oracle: Account<'info, PriceOracle>,

    pub authority: Signer<'info>,
}

#[derive(Accounts)]
#[instruction(element_id: String)]
pub struct UpdateElementPrice<'info> {
    #[account(
        init_if_needed,
        payer = authority,
        space = 8 + ElementPriceOracle::INIT_SPACE,
        seeds = [b"element_price", element_id.as_bytes()],
        bump
    )]
    pub element_oracle: Account<'info, ElementPriceOracle>,

    #[account(
        seeds = [b"price_oracle"],
        bump,
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub oracle: Account<'info, PriceOracle>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct GetPrice<'info> {
    #[account(seeds = [b"price_oracle"], bump)]
    pub oracle: Account<'info, PriceOracle>,
}

#[derive(Accounts)]
pub struct SetOracleActive<'info> {
    #[account(
        mut,
        seeds = [b"price_oracle"],
        bump,
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub oracle: Account<'info, PriceOracle>,

    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct TransferAuthority<'info> {
    #[account(
        mut,
        seeds = [b"price_oracle"],
        bump,
        has_one = authority @ ErrorCode::Unauthorized
    )]
    pub oracle: Account<'info, PriceOracle>,

    pub authority: Signer<'info>,
}

// Data Structures

#[account]
#[derive(InitSpace)]
pub struct PriceOracle {
    pub authority: Pubkey,        // Backend keypair that updates prices
    pub lko_per_sol: u64,          // LKO tokens per 1 SOL (9 decimals)
    pub last_updated: i64,         // Unix timestamp of last update
    pub update_count: u64,         // Total number of updates
    pub is_active: bool,           // Emergency pause flag
}

#[account]
#[derive(InitSpace)]
pub struct ElementPriceOracle {
    #[max_len(32)]
    pub element_id: String,        // Element identifier (e.g., "Carbon_X")
    pub price_per_sol: u64,        // Element tokens per 1 SOL (9 decimals)
    pub last_updated: i64,         // Unix timestamp of last update
    pub update_count: u64,         // Total number of updates
}

// Events

#[event]
pub struct OracleInitialized {
    pub authority: Pubkey,
    pub initial_price: u64,
    pub timestamp: i64,
}

#[event]
pub struct PriceUpdated {
    pub old_price: u64,
    pub new_price: u64,
    pub timestamp: i64,
    pub update_count: u64,
}

#[event]
pub struct ElementPriceUpdated {
    pub element_id: String,
    pub price_per_sol: u64,
    pub timestamp: i64,
}

#[event]
pub struct OracleStatusChanged {
    pub is_active: bool,
    pub timestamp: i64,
}

#[event]
pub struct AuthorityTransferred {
    pub old_authority: Pubkey,
    pub new_authority: Pubkey,
    pub timestamp: i64,
}

// Errors

#[error_code]
pub enum ErrorCode {
    #[msg("Unauthorized: Only oracle authority can perform this action")]
    Unauthorized,

    #[msg("Invalid price: Price must be greater than 0")]
    InvalidPrice,

    #[msg("Oracle is inactive: Price updates are paused")]
    OracleInactive,

    #[msg("Price is stale: Last update was more than 5 minutes ago")]
    PriceStale,

    #[msg("Element ID too long: Maximum 32 characters")]
    ElementIdTooLong,
}

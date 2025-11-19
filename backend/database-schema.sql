-- LenKinVerse Database Schema
-- PostgreSQL 14+

-- Player balances (in-game DATA)
CREATE TABLE IF NOT EXISTS player_balances (
    player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_wallet TEXT UNIQUE,
    alsol_balance BIGINT DEFAULT 0, -- Lamports (9 decimals)
    lkc_balance BIGINT DEFAULT 0,
    weekly_lkc_alsol_used BIGINT DEFAULT 0,
    week_reset_at TIMESTAMP DEFAULT NOW() + INTERVAL '7 days',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Player inventories (in-game DATA)
CREATE TABLE IF NOT EXISTS player_inventory (
    id SERIAL PRIMARY KEY,
    player_wallet TEXT NOT NULL,
    element_id TEXT NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(player_wallet, element_id),
    CHECK (amount >= 0)
);

-- Element data (in-game DATA capacity tracking)
CREATE TABLE IF NOT EXISTS element_data (
    element_id TEXT PRIMARY KEY,
    wild_spawns BIGINT DEFAULT 250000,
    reaction_buffer BIGINT DEFAULT 250000,
    game_treasury BIGINT DEFAULT 0,
    total_player_inventories BIGINT DEFAULT 0,
    capacity BIGINT DEFAULT 500000,
    on_chain_mint TEXT, -- SPL mint address
    governor TEXT, -- Governor wallet
    co_governor TEXT, -- Co-governor wallet (optional)
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CHECK (wild_spawns + reaction_buffer + game_treasury + total_player_inventories <= capacity)
);

-- Bridge history (audit log)
CREATE TABLE IF NOT EXISTS bridge_history (
    id SERIAL PRIMARY KEY,
    element_id TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('to_chain', 'to_ingame')),
    amount BIGINT NOT NULL,
    player_or_governor TEXT NOT NULL,
    transaction_signature TEXT,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Transaction queue (for retry logic)
CREATE TABLE IF NOT EXISTS pending_transactions (
    id SERIAL PRIMARY KEY,
    player_wallet TEXT NOT NULL,
    instruction_type TEXT NOT NULL,
    params JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'confirmed', 'failed')),
    retry_count INT DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_player_inventory_wallet ON player_inventory(player_wallet);
CREATE INDEX IF NOT EXISTS idx_player_inventory_element ON player_inventory(element_id);
CREATE INDEX IF NOT EXISTS idx_bridge_history_element ON bridge_history(element_id);
CREATE INDEX IF NOT EXISTS idx_bridge_history_timestamp ON bridge_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_pending_transactions_status ON pending_transactions(status);

-- Update triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_player_balances_updated_at BEFORE UPDATE ON player_balances
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_player_inventory_updated_at BEFORE UPDATE ON player_inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_element_data_updated_at BEFORE UPDATE ON element_data
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pending_transactions_updated_at BEFORE UPDATE ON pending_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data (for testing)
INSERT INTO element_data (element_id, on_chain_mint, governor) VALUES
    ('lkC', 'Carbon1111111111111111111111111111111111', '7xKXtg3xR...abc'),
    ('lkO', 'Oxygen1111111111111111111111111111111111', '7xKXtg3xR...abc'),
    ('lkH', 'Hydrogen111111111111111111111111111111', '7xKXtg3xR...abc')
ON CONFLICT (element_id) DO NOTHING;

-- Grant permissions (adjust as needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

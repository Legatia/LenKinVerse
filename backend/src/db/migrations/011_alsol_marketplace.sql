-- alSOL Marketplace Migration
-- Allows players to list/buy/sell elements and compounds using alSOL

-- Marketplace listings table
CREATE TABLE IF NOT EXISTS marketplace_listings (
    id SERIAL PRIMARY KEY,
    seller_wallet VARCHAR(255) NOT NULL,
    item_type VARCHAR(20) NOT NULL CHECK (item_type IN ('element', 'compound')),
    item_id VARCHAR(50) NOT NULL,
    amount INTEGER NOT NULL CHECK (amount > 0),
    price_per_unit BIGINT NOT NULL CHECK (price_per_unit > 0), -- In lamports (alSOL)
    total_price BIGINT NOT NULL CHECK (total_price > 0), -- amount * price_per_unit
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'sold', 'cancelled')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    sold_at TIMESTAMP,
    buyer_wallet VARCHAR(255),

    -- Prevent duplicate active listings from same seller for same item
    UNIQUE(seller_wallet, item_type, item_id, status)
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_marketplace_status ON marketplace_listings(status);
CREATE INDEX IF NOT EXISTS idx_marketplace_item ON marketplace_listings(item_type, item_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_seller ON marketplace_listings(seller_wallet);
CREATE INDEX IF NOT EXISTS idx_marketplace_created ON marketplace_listings(created_at DESC);

-- Marketplace transaction history
CREATE TABLE IF NOT EXISTS marketplace_transactions (
    id SERIAL PRIMARY KEY,
    listing_id INTEGER NOT NULL REFERENCES marketplace_listings(id),
    seller_wallet VARCHAR(255) NOT NULL,
    buyer_wallet VARCHAR(255) NOT NULL,
    item_type VARCHAR(20) NOT NULL,
    item_id VARCHAR(50) NOT NULL,
    amount INTEGER NOT NULL,
    price_paid BIGINT NOT NULL, -- Total alSOL paid (in lamports)
    marketplace_fee BIGINT NOT NULL DEFAULT 0, -- 2.5% fee (in lamports)
    seller_received BIGINT NOT NULL, -- price_paid - marketplace_fee
    transaction_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Index for history queries
CREATE INDEX IF NOT EXISTS idx_marketplace_tx_buyer ON marketplace_transactions(buyer_wallet);
CREATE INDEX IF NOT EXISTS idx_marketplace_tx_seller ON marketplace_transactions(seller_wallet);
CREATE INDEX IF NOT EXISTS idx_marketplace_tx_date ON marketplace_transactions(transaction_date DESC);

-- Update trigger function for updated_at (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update trigger for updated_at
CREATE TRIGGER update_marketplace_listings_updated_at
    BEFORE UPDATE ON marketplace_listings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to get active listings with item details
CREATE OR REPLACE FUNCTION get_marketplace_listings(
    p_item_type VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    listing_id INTEGER,
    seller_wallet VARCHAR,
    item_type VARCHAR,
    item_id VARCHAR,
    item_name VARCHAR,
    amount INTEGER,
    price_per_unit BIGINT,
    total_price BIGINT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ml.id,
        ml.seller_wallet,
        ml.item_type,
        ml.item_id,
        CASE
            WHEN ml.item_type = 'element' THEN e.name
            WHEN ml.item_type = 'compound' THEN c.name
            ELSE ml.item_id
        END as item_name,
        ml.amount,
        ml.price_per_unit,
        ml.total_price,
        ml.created_at
    FROM marketplace_listings ml
    LEFT JOIN elements e ON ml.item_type = 'element' AND ml.item_id = e.id
    LEFT JOIN compounds c ON ml.item_type = 'compound' AND ml.item_id = c.id
    WHERE ml.status = 'active'
        AND (p_item_type IS NULL OR ml.item_type = p_item_type)
    ORDER BY ml.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate marketplace fee (2.5%)
CREATE OR REPLACE FUNCTION calculate_marketplace_fee(
    price BIGINT
) RETURNS BIGINT AS $$
BEGIN
    RETURN FLOOR(price * 0.025); -- 2.5% fee
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON TABLE marketplace_listings IS 'Active and historical marketplace listings for elements and compounds';
COMMENT ON TABLE marketplace_transactions IS 'Complete history of all marketplace transactions';
COMMENT ON COLUMN marketplace_listings.price_per_unit IS 'Price in lamports (9 decimals, divide by 1B for alSOL)';
COMMENT ON COLUMN marketplace_listings.total_price IS 'Total price = amount * price_per_unit (in lamports)';

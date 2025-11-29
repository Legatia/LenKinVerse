-- ============================================================================
-- Energy System Migration
-- ============================================================================
--
-- Implements time-based energy regeneration system for ReAgenyx
--
-- Mechanics:
-- - Max energy: 100⚡ per player
-- - Regeneration: 1⚡ per 3 minutes (20 energy/hour)
-- - Full recharge: 5 hours from empty
-- - Energy costs: 1⚡ (simple) to 5⚡ (nuclear reactions)
--
-- ============================================================================

-- Create player_energy table
CREATE TABLE IF NOT EXISTS player_energy (
    id SERIAL PRIMARY KEY,
    player_wallet VARCHAR(255) UNIQUE NOT NULL,
    current_energy INTEGER NOT NULL DEFAULT 100,
    max_energy INTEGER NOT NULL DEFAULT 100,
    last_regeneration_time TIMESTAMP NOT NULL DEFAULT NOW(),
    total_energy_spent BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create index for faster wallet lookups
CREATE INDEX idx_player_energy_wallet ON player_energy(player_wallet);

-- Add constraint: current_energy cannot be negative
ALTER TABLE player_energy ADD CONSTRAINT check_current_energy_positive
    CHECK (current_energy >= 0);

-- Add constraint: current_energy cannot exceed max_energy
ALTER TABLE player_energy ADD CONSTRAINT check_current_energy_max
    CHECK (current_energy <= max_energy);

-- ============================================================================
-- Helper function: Calculate regenerated energy based on time
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_regenerated_energy(
    last_regen_time TIMESTAMP,
    current_energy INTEGER,
    max_energy INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    minutes_elapsed INTEGER;
    energy_to_add INTEGER;
    new_energy INTEGER;
BEGIN
    -- Calculate minutes since last regeneration
    minutes_elapsed := EXTRACT(EPOCH FROM (NOW() - last_regen_time)) / 60;

    -- 1 energy per 3 minutes
    energy_to_add := FLOOR(minutes_elapsed / 3);

    -- Add to current energy, cap at max
    new_energy := LEAST(current_energy + energy_to_add, max_energy);

    RETURN new_energy;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Helper function: Get or create player energy record
-- ============================================================================
CREATE OR REPLACE FUNCTION get_or_create_player_energy(
    p_wallet VARCHAR(255)
)
RETURNS TABLE (
    player_wallet VARCHAR(255),
    current_energy INTEGER,
    max_energy INTEGER,
    last_regeneration_time TIMESTAMP,
    total_energy_spent BIGINT,
    regenerated_energy INTEGER
) AS $$
DECLARE
    v_current_energy INTEGER;
    v_last_regen_time TIMESTAMP;
    v_regenerated INTEGER;
    v_new_energy INTEGER;
BEGIN
    -- Try to get existing record
    SELECT pe.current_energy, pe.last_regeneration_time
    INTO v_current_energy, v_last_regen_time
    FROM player_energy pe
    WHERE pe.player_wallet = p_wallet;

    -- If player doesn't exist, create with full energy
    IF NOT FOUND THEN
        INSERT INTO player_energy (player_wallet, current_energy, max_energy)
        VALUES (p_wallet, 100, 100)
        RETURNING
            player_energy.player_wallet,
            player_energy.current_energy,
            player_energy.max_energy,
            player_energy.last_regeneration_time,
            player_energy.total_energy_spent,
            0 AS regenerated_energy
        INTO
            player_wallet,
            current_energy,
            max_energy,
            last_regeneration_time,
            total_energy_spent,
            regenerated_energy;
        RETURN NEXT;
        RETURN;
    END IF;

    -- Calculate regenerated energy
    v_regenerated := calculate_regenerated_energy(v_last_regen_time, v_current_energy, 100);
    v_new_energy := v_regenerated;

    -- Update if energy was regenerated
    IF v_regenerated > v_current_energy THEN
        UPDATE player_energy
        SET
            current_energy = v_new_energy,
            last_regeneration_time = NOW(),
            updated_at = NOW()
        WHERE player_energy.player_wallet = p_wallet;
    END IF;

    -- Return updated values
    RETURN QUERY
    SELECT
        pe.player_wallet,
        v_new_energy AS current_energy,
        pe.max_energy,
        pe.last_regeneration_time,
        pe.total_energy_spent,
        (v_regenerated - v_current_energy) AS regenerated_energy
    FROM player_energy pe
    WHERE pe.player_wallet = p_wallet;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Helper function: Consume energy for reactions
-- ============================================================================
CREATE OR REPLACE FUNCTION consume_energy(
    p_wallet VARCHAR(255),
    p_energy_cost INTEGER
)
RETURNS TABLE (
    success BOOLEAN,
    current_energy INTEGER,
    energy_consumed INTEGER,
    message TEXT
) AS $$
DECLARE
    v_current_energy INTEGER;
    v_max_energy INTEGER;
    v_last_regen_time TIMESTAMP;
    v_regenerated_energy INTEGER;
BEGIN
    -- Get current energy (with regeneration)
    SELECT * FROM get_or_create_player_energy(p_wallet)
    INTO
        p_wallet,
        v_current_energy,
        v_max_energy,
        v_last_regen_time,
        v_regenerated_energy,
        v_regenerated_energy;

    -- Check if player has enough energy
    IF v_current_energy < p_energy_cost THEN
        RETURN QUERY
        SELECT
            FALSE AS success,
            v_current_energy AS current_energy,
            0 AS energy_consumed,
            FORMAT('Insufficient energy: need %s⚡, have %s⚡', p_energy_cost, v_current_energy) AS message;
        RETURN;
    END IF;

    -- Consume energy
    UPDATE player_energy
    SET
        current_energy = current_energy - p_energy_cost,
        total_energy_spent = total_energy_spent + p_energy_cost,
        updated_at = NOW()
    WHERE player_energy.player_wallet = p_wallet;

    -- Return success
    RETURN QUERY
    SELECT
        TRUE AS success,
        (v_current_energy - p_energy_cost) AS current_energy,
        p_energy_cost AS energy_consumed,
        FORMAT('Consumed %s⚡, %s⚡ remaining', p_energy_cost, v_current_energy - p_energy_cost) AS message;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Comments
-- ============================================================================
COMMENT ON TABLE player_energy IS 'Tracks player energy for chemistry reactions';
COMMENT ON COLUMN player_energy.current_energy IS 'Current energy level (0-100)';
COMMENT ON COLUMN player_energy.max_energy IS 'Maximum energy capacity (default 100, upgradeable)';
COMMENT ON COLUMN player_energy.last_regeneration_time IS 'Last time energy was regenerated';
COMMENT ON COLUMN player_energy.total_energy_spent IS 'Lifetime energy spent (statistics)';

COMMENT ON FUNCTION calculate_regenerated_energy IS 'Calculates energy regenerated based on time elapsed';
COMMENT ON FUNCTION get_or_create_player_energy IS 'Gets player energy with auto-regeneration applied';
COMMENT ON FUNCTION consume_energy IS 'Consumes energy for a reaction, returns success/failure';

-- ============================================================================
-- Test Data (optional - for development only)
-- ============================================================================
-- Uncomment to add test data:
-- INSERT INTO player_energy (player_wallet, current_energy, max_energy)
-- VALUES
--     ('TestWallet123', 100, 100),
--     ('TestWallet456', 50, 100),
--     ('TestWallet789', 0, 100)
-- ON CONFLICT (player_wallet) DO NOTHING;

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- ReAgenyx Chemistry System Database Schema
-- Migration 008: Elements, Compounds, and Reactions
-- Created: 2025-11-21

-- ============================================================================
-- ELEMENTS TABLE
-- ============================================================================
-- Stores all base elements that players can collect or unlock

CREATE TABLE IF NOT EXISTS elements (
    id VARCHAR(10) PRIMARY KEY,  -- e.g., 'lkC', 'lkO', 'lkH', 'lkCa'
    name VARCHAR(50) NOT NULL,   -- e.g., 'Carbon', 'Oxygen'
    symbol VARCHAR(5) NOT NULL,  -- e.g., 'C', 'O', 'H', 'Ca'
    rarity VARCHAR(20) NOT NULL, -- 'common', 'uncommon', 'rare', 'legendary'
    unlock_method VARCHAR(20) NOT NULL, -- 'walking', 'nuclear', 'chemical'
    base_energy_cost INTEGER DEFAULT 0, -- Energy to obtain (0 for walking)
    unlock_formula TEXT,         -- Nuclear formula to unlock (if applicable)
    description TEXT,
    atomic_number INTEGER,       -- Real atomic number
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT rarity_check CHECK (rarity IN ('common', 'uncommon', 'rare', 'legendary')),
    CONSTRAINT unlock_check CHECK (unlock_method IN ('walking', 'nuclear', 'chemical', 'discovery'))
);

-- ============================================================================
-- COMPOUNDS TABLE
-- ============================================================================
-- Stores all compounds that can be created from elements/compounds

CREATE TABLE IF NOT EXISTS compounds (
    id VARCHAR(20) PRIMARY KEY,  -- e.g., 'H2O', 'CO2', 'CaCO3'
    name VARCHAR(100) NOT NULL,  -- e.g., 'Water', 'Carbon Dioxide'
    chemical_formula VARCHAR(50) NOT NULL, -- Display formula
    category VARCHAR(30) NOT NULL, -- 'basic', 'intermediate', 'advanced', 'construction', 'fuel'
    base_value INTEGER DEFAULT 0,  -- Base market value in alSOL
    rarity VARCHAR(20) NOT NULL,
    description TEXT,
    real_world_uses TEXT,        -- Educational: what it's used for
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT category_check CHECK (category IN ('basic', 'intermediate', 'advanced', 'construction', 'fuel', 'chemical'))
);

-- ============================================================================
-- REACTIONS TABLE
-- ============================================================================
-- Stores all possible chemical reactions in the game

CREATE TABLE IF NOT EXISTS reactions (
    id SERIAL PRIMARY KEY,
    reaction_name VARCHAR(100) NOT NULL,
    reaction_type VARCHAR(20) NOT NULL, -- 'physical', 'chemical', 'nuclear'
    energy_cost INTEGER NOT NULL,       -- Energy (⚡) required
    success_rate DECIMAL(4,3) NOT NULL, -- 0.000 to 1.000 (e.g., 0.850 = 85%)
    base_time_seconds INTEGER DEFAULT 0, -- Time to complete (instant for starter phase)
    inputs JSONB NOT NULL,              -- [{type: 'element', id: 'lkH', amount: 2}, ...]
    outputs JSONB NOT NULL,             -- [{type: 'compound', id: 'H2O', amount: 1}]
    unlocked_by_default BOOLEAN DEFAULT false,
    discovery_bonus BOOLEAN DEFAULT true, -- First discoverer gets bonus?
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT reaction_type_check CHECK (reaction_type IN ('physical', 'chemical', 'nuclear')),
    CONSTRAINT success_rate_check CHECK (success_rate >= 0.0 AND success_rate <= 1.0),
    CONSTRAINT energy_check CHECK (energy_cost >= 0)
);

-- ============================================================================
-- DISCOVERIES TABLE
-- ============================================================================
-- Tracks who discovered each reaction first (blockchain verified)

CREATE TABLE IF NOT EXISTS discoveries (
    id SERIAL PRIMARY KEY,
    reaction_id INTEGER NOT NULL REFERENCES reactions(id),
    compound_id VARCHAR(20) REFERENCES compounds(id), -- What was discovered
    discoverer_wallet VARCHAR(44) NOT NULL, -- Solana wallet address
    discovery_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    blockchain_tx VARCHAR(88),              -- Solana transaction signature
    tax_free_until TIMESTAMP,               -- Discovery bonus expires
    total_royalties_earned INTEGER DEFAULT 0, -- Total earned from 2% cut

    CONSTRAINT unique_discovery UNIQUE (reaction_id), -- Only one discoverer per reaction
    CONSTRAINT unique_compound UNIQUE (compound_id)   -- Only one discoverer per compound
);

-- ============================================================================
-- PLAYER INVENTORY (Elements & Compounds)
-- ============================================================================
-- Tracks what each player owns

CREATE TABLE IF NOT EXISTS player_inventory (
    id SERIAL PRIMARY KEY,
    player_wallet VARCHAR(44) NOT NULL,
    item_type VARCHAR(20) NOT NULL,        -- 'element' or 'compound'
    item_id VARCHAR(20) NOT NULL,          -- element.id or compound.id
    amount BIGINT DEFAULT 0,
    total_created BIGINT DEFAULT 0,        -- Lifetime creation count
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_inventory UNIQUE (player_wallet, item_type, item_id),
    CONSTRAINT item_type_check CHECK (item_type IN ('element', 'compound')),
    CONSTRAINT amount_check CHECK (amount >= 0)
);

-- ============================================================================
-- PLAYER UNLOCKS
-- ============================================================================
-- Tracks which elements/reactions each player has unlocked

CREATE TABLE IF NOT EXISTS player_unlocks (
    id SERIAL PRIMARY KEY,
    player_wallet VARCHAR(44) NOT NULL,
    unlock_type VARCHAR(20) NOT NULL,      -- 'element', 'compound', 'reaction'
    unlock_id VARCHAR(50) NOT NULL,        -- ID of what was unlocked
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    unlock_method VARCHAR(30),             -- How it was unlocked

    CONSTRAINT unique_unlock UNIQUE (player_wallet, unlock_type, unlock_id),
    CONSTRAINT unlock_type_check CHECK (unlock_type IN ('element', 'compound', 'reaction'))
);

-- ============================================================================
-- REACTION HISTORY
-- ============================================================================
-- Logs every reaction performed (for analytics)

CREATE TABLE IF NOT EXISTS reaction_history (
    id SERIAL PRIMARY KEY,
    player_wallet VARCHAR(44) NOT NULL,
    reaction_id INTEGER NOT NULL REFERENCES reactions(id),
    success BOOLEAN NOT NULL,
    energy_spent INTEGER NOT NULL,
    inputs_consumed JSONB NOT NULL,
    outputs_created JSONB,                 -- NULL if failed
    tax_paid INTEGER DEFAULT 0,            -- Tax paid (if discovered)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES for Performance
-- ============================================================================

-- Player inventory lookups
CREATE INDEX idx_inventory_player ON player_inventory(player_wallet);
CREATE INDEX idx_inventory_item ON player_inventory(item_type, item_id);

-- Player unlocks
CREATE INDEX idx_unlocks_player ON player_unlocks(player_wallet);
CREATE INDEX idx_unlocks_type ON player_unlocks(unlock_type, unlock_id);

-- Discoveries
CREATE INDEX idx_discoveries_wallet ON discoveries(discoverer_wallet);
CREATE INDEX idx_discoveries_compound ON discoveries(compound_id);

-- Reaction history
CREATE INDEX idx_history_player ON reaction_history(player_wallet);
CREATE INDEX idx_history_reaction ON reaction_history(reaction_id);
CREATE INDEX idx_history_date ON reaction_history(created_at DESC);

-- ============================================================================
-- COMMENTS for Documentation
-- ============================================================================

COMMENT ON TABLE elements IS 'Base elements that can be collected or unlocked';
COMMENT ON TABLE compounds IS 'Chemical compounds created from reactions';
COMMENT ON TABLE reactions IS 'All possible chemical reactions in the game';
COMMENT ON TABLE discoveries IS 'First discoverers of each compound (blockchain verified)';
COMMENT ON TABLE player_inventory IS 'Player-owned elements and compounds';
COMMENT ON TABLE player_unlocks IS 'Elements and reactions unlocked by each player';
COMMENT ON TABLE reaction_history IS 'Log of all reactions performed';

COMMENT ON COLUMN reactions.inputs IS 'JSON array: [{type: "element", id: "lkH", amount: 2}]';
COMMENT ON COLUMN reactions.outputs IS 'JSON array: [{type: "compound", id: "H2O", amount: 1}]';
COMMENT ON COLUMN discoveries.tax_free_until IS '72 hours from discovery - no tax period';

-- ============================================================================
-- INITIAL DATA: Starter Phase Elements
-- ============================================================================

INSERT INTO elements (id, name, symbol, rarity, unlock_method, base_energy_cost, atomic_number, description) VALUES
('lkC', 'Carbon', 'C', 'common', 'walking', 0, 6, 'Base element obtained from walking. Foundation of all organic chemistry.'),
('lkO', 'Oxygen', 'O', 'uncommon', 'nuclear', 5, 8, 'Unlocked via nuclear reaction. Essential for combustion and respiration.'),
('lkH', 'Hydrogen', 'H', 'uncommon', 'nuclear', 5, 1, 'Unlocked via nuclear reaction. Most abundant element in universe.'),
('lkCa', 'Calcium', 'Ca', 'rare', 'nuclear', 5, 20, 'Unlocked via nuclear reaction. Essential for construction materials.');

-- ============================================================================
-- INITIAL DATA: Starter Phase Compounds
-- ============================================================================

INSERT INTO compounds (id, name, chemical_formula, category, base_value, rarity, description, real_world_uses) VALUES
-- Basic Compounds
('H2O', 'Water', 'H₂O', 'basic', 10, 'common', 'Essential compound for life and many reactions', 'Drinking, cleaning, chemical reactions, cooling'),
('CO2', 'Carbon Dioxide', 'CO₂', 'basic', 15, 'common', 'Product of combustion and respiration', 'Fire extinguishers, carbonation, photosynthesis'),
('CaO', 'Calcium Oxide', 'CaO', 'intermediate', 30, 'uncommon', 'Quicklime - important industrial compound', 'Cement, steel production, water treatment'),

-- Intermediate Compounds
('CaOH2', 'Calcium Hydroxide', 'Ca(OH)₂', 'intermediate', 50, 'uncommon', 'Slaked lime - used in construction', 'Mortar, plaster, soil stabilization'),
('CH4', 'Methane', 'CH₄', 'fuel', 40, 'uncommon', 'Simplest hydrocarbon - natural gas', 'Fuel, heating, electricity generation'),
('H2CO3', 'Carbonic Acid', 'H₂CO₃', 'intermediate', 25, 'uncommon', 'Weak acid formed when CO₂ dissolves in water', 'Carbonated beverages, natural erosion'),

-- Advanced/Construction
('CaCO3', 'Calcium Carbonate', 'CaCO₃', 'construction', 100, 'rare', 'Primary construction material - limestone, marble, chalk', 'Buildings, cement, paper, medicine, agriculture'),
('C2H2', 'Acetylene', 'C₂H₂', 'fuel', 60, 'rare', 'High-energy fuel used for welding', 'Welding, cutting torches, chemical synthesis'),
('CaH2', 'Calcium Hydride', 'CaH₂', 'advanced', 45, 'uncommon', 'Hydrogen storage material', 'Desiccant, hydrogen generation, reducing agent'),
('HCOOH', 'Formic Acid', 'HCOOH', 'chemical', 35, 'uncommon', 'Simplest carboxylic acid', 'Preservative, antibacterial, leather production');

-- ============================================================================
-- INITIAL DATA: Starter Phase Reactions
-- ============================================================================

-- Basic Reactions (Building Blocks)
INSERT INTO reactions (reaction_name, reaction_type, energy_cost, success_rate, inputs, outputs, unlocked_by_default, discovery_bonus) VALUES

-- 1. Water Formation (Most Important!)
('Water Formation', 'chemical', 2, 0.850,
    '[{"type":"element","id":"lkH","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"compound","id":"H2O","amount":1}]',
    true, true),

-- 2. Carbon Dioxide Formation
('Carbon Dioxide Formation', 'chemical', 2, 0.800,
    '[{"type":"element","id":"lkC","amount":1},{"type":"element","id":"lkO","amount":2}]',
    '[{"type":"compound","id":"CO2","amount":1}]',
    true, true),

-- 3. Calcium Oxide Formation
('Calcium Oxide Formation', 'chemical', 2, 0.750,
    '[{"type":"element","id":"lkCa","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"compound","id":"CaO","amount":2}]',
    true, true),

-- Intermediate Reactions
-- 4. Calcium Hydroxide Formation
('Calcium Hydroxide Formation', 'chemical', 2, 0.900,
    '[{"type":"compound","id":"CaO","amount":1},{"type":"compound","id":"H2O","amount":1}]',
    '[{"type":"compound","id":"CaOH2","amount":1}]',
    true, true),

-- 5. Methane Formation
('Methane Formation', 'chemical', 2, 0.700,
    '[{"type":"element","id":"lkC","amount":1},{"type":"element","id":"lkH","amount":2}]',
    '[{"type":"compound","id":"CH4","amount":1}]',
    true, true),

-- 6. Carbonic Acid Formation
('Carbonic Acid Formation', 'chemical', 1, 0.950,
    '[{"type":"compound","id":"CO2","amount":1},{"type":"compound","id":"H2O","amount":1}]',
    '[{"type":"compound","id":"H2CO3","amount":1}]',
    true, true),

-- Advanced Reactions (Construction Goal!)
-- 7A. Calcium Carbonate from Calcium Hydroxide (PRIMARY PATH)
('Calcium Carbonate Formation A', 'chemical', 3, 0.850,
    '[{"type":"compound","id":"CaOH2","amount":1},{"type":"compound","id":"CO2","amount":1}]',
    '[{"type":"compound","id":"CaCO3","amount":1},{"type":"compound","id":"H2O","amount":1}]',
    true, true),

-- 7B. Calcium Carbonate from Calcium Oxide (ALTERNATE PATH)
('Calcium Carbonate Formation B', 'chemical', 2, 0.800,
    '[{"type":"compound","id":"CaO","amount":1},{"type":"compound","id":"CO2","amount":1}]',
    '[{"type":"compound","id":"CaCO3","amount":1}]',
    true, true),

-- 8. Acetylene Formation (Advanced Fuel)
('Acetylene Formation', 'chemical', 3, 0.600,
    '[{"type":"element","id":"lkC","amount":2},{"type":"element","id":"lkH","amount":1}]',
    '[{"type":"compound","id":"C2H2","amount":1}]',
    true, true),

-- 9. Calcium Hydride Formation
('Calcium Hydride Formation', 'chemical', 2, 0.700,
    '[{"type":"element","id":"lkCa","amount":1},{"type":"element","id":"lkH","amount":1}]',
    '[{"type":"compound","id":"CaH2","amount":1}]',
    true, true),

-- 10. Formic Acid Formation
('Formic Acid Formation', 'chemical', 3, 0.650,
    '[{"type":"element","id":"lkC","amount":1},{"type":"element","id":"lkH","amount":1},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"compound","id":"HCOOH","amount":1}]',
    true, true);

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================

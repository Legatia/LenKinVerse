-- ReAgenyx Nuclear Reactions Update
-- Migration 009: Nuclear element unlock formulas
-- Created: 2025-11-21
-- Pseudo-nuclear chemistry where protons/neutrons can transform

-- ============================================================================
-- ADD lkC14 (Carbon-14) ELEMENT
-- ============================================================================
-- Carbon-14 is needed for nuclear reactions

INSERT INTO elements (id, name, symbol, rarity, unlock_method, base_energy_cost, atomic_number, description) VALUES
('lkC14', 'Carbon-14', 'C-14', 'rare', 'nuclear', 5, 6, 'Radioactive isotope of carbon. Essential for nuclear transmutation reactions.');

-- ============================================================================
-- ADD COAL COMPOUND (if not exists)
-- ============================================================================
-- Coal is a physical transformation of carbon

INSERT INTO compounds (id, name, chemical_formula, category, base_value, rarity, description, real_world_uses) VALUES
('Coal', 'Coal', 'C(solid)', 'basic', 20, 'uncommon', 'Compressed carbon - fuel source', 'Fuel, heating, energy generation'),
('CO', 'Carbon Monoxide', 'CO', 'intermediate', 15, 'uncommon', 'Toxic gas - byproduct of incomplete combustion', 'Industrial chemistry, warning of incomplete combustion'),
('O2', 'Oxygen Gas', 'O₂', 'basic', 25, 'uncommon', 'Breathable oxygen - essential for life', 'Respiration, combustion, medical use'),
('lkO18', 'Oxygen-18', 'O-18', 'intermediate', 40, 'rare', 'Heavy oxygen isotope - used in research', 'Medical imaging, climate research, water tracing')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- UPDATE OLD NUCLEAR REACTION (lkC + lkC14 → lkO)
-- ============================================================================
-- This replaces any old placeholder nuclear reactions

-- Delete old nuclear reactions if they exist
DELETE FROM reactions WHERE reaction_type = 'nuclear';

-- ============================================================================
-- NUCLEAR REACTION 1: Oxygen Unlock
-- ============================================================================
-- lkC + lkC14 → lkO (10% success)
-- Failure outcomes: Common and rare (from previous design)

INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Oxygen Synthesis (Nuclear)',
    'nuclear',
    5,
    0.100,  -- 10% success
    '[{"type":"element","id":"lkC","amount":1},{"type":"element","id":"lkC14","amount":1}]',
    '[{"type":"element","id":"lkO","amount":1}]',
    true,
    true
);

-- Store the reaction ID for failure outcomes
DO $$
DECLARE
    oxygen_reaction_id INTEGER;
BEGIN
    SELECT id INTO oxygen_reaction_id FROM reactions WHERE reaction_name = 'Oxygen Synthesis (Nuclear)';

    -- Note: Failure outcomes will be handled in application logic
    -- 90% failure: Return common materials (lkC)
    -- Small chance: Return rare materials (lkC14)
END $$;

-- ============================================================================
-- NUCLEAR REACTION 2: Hydrogen Unlock
-- ============================================================================
-- lkC14 + lkO + Coal → 0.5 O2 + lkH (10% success)
-- Failure (90%): → CO (Carbon Monoxide)
-- Rare failure (5% of total): → lkO18 + lkC

INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Hydrogen Synthesis (Nuclear)',
    'nuclear',
    5,
    0.100,  -- 10% success
    '[{"type":"element","id":"lkC14","amount":1},{"type":"element","id":"lkO","amount":1},{"type":"compound","id":"Coal","amount":1}]',
    '[{"type":"compound","id":"O2","amount":0.5},{"type":"element","id":"lkH","amount":1}]',
    false,  -- Must unlock lkO first
    true
);

-- Failure outcome 1 (85% of attempts = 90% × 94.4%): CO
INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Hydrogen Synthesis Failure - Common',
    'nuclear',
    5,
    0.850,  -- 85% of attempts result in CO
    '[{"type":"element","id":"lkC14","amount":1},{"type":"element","id":"lkO","amount":1},{"type":"compound","id":"Coal","amount":1}]',
    '[{"type":"compound","id":"CO","amount":1}]',
    false,
    false
);

-- Failure outcome 2 (5% of attempts): lkO18 + lkC
INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Hydrogen Synthesis Failure - Rare',
    'nuclear',
    5,
    0.050,  -- 5% of attempts
    '[{"type":"element","id":"lkC14","amount":1},{"type":"element","id":"lkO","amount":1},{"type":"compound","id":"Coal","amount":1}]',
    '[{"type":"element","id":"lkO18","amount":1},{"type":"element","id":"lkC","amount":1}]',
    false,
    false
);

-- ============================================================================
-- NUCLEAR REACTION 3: Calcium Unlock
-- ============================================================================
-- 2 lkC14 + lkO → lkCa (15% success)
-- Failure (85%): Multiple outcomes
--   - 65% (85% × 76.5%): → 2 lkC + lkO
--   - 17% (85% × 20%): → 3 lkO
--   - 8.5% (85% × 10%): → 2 lkC + lkO + 2 lkH

INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Calcium Synthesis (Nuclear)',
    'nuclear',
    5,
    0.150,  -- 15% success
    '[{"type":"element","id":"lkC14","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"element","id":"lkCa","amount":1}]',
    false,  -- Must unlock lkO first
    true
);

-- Failure outcome 1 (65% of attempts): 2 lkC + lkO (most common)
INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Calcium Synthesis Failure - Common',
    'nuclear',
    5,
    0.650,  -- 65% of attempts
    '[{"type":"element","id":"lkC14","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"element","id":"lkC","amount":2},{"type":"element","id":"lkO","amount":1}]',
    false,
    false
);

-- Failure outcome 2 (17% of attempts): 3 lkO (oxygen multiplication!)
INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Calcium Synthesis Failure - Oxygen Burst',
    'nuclear',
    5,
    0.170,  -- 17% of attempts (20% of failures)
    '[{"type":"element","id":"lkC14","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"element","id":"lkO","amount":3}]',
    false,
    false
);

-- Failure outcome 3 (8.5% of attempts): 2 lkC + lkO + 2 lkH (hydrogen bonus!)
INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Calcium Synthesis Failure - Hydrogen Bonus',
    'nuclear',
    5,
    0.085,  -- 8.5% of attempts (10% of failures)
    '[{"type":"element","id":"lkC14","amount":2},{"type":"element","id":"lkO","amount":1}]',
    '[{"type":"element","id":"lkC","amount":2},{"type":"element","id":"lkO","amount":1},{"type":"element","id":"lkH","amount":2}]',
    false,
    false
);

-- ============================================================================
-- PHYSICAL REACTION: Coal Formation
-- ============================================================================
-- Players need a way to get Coal for hydrogen synthesis
-- 5 lkC → Coal (Physical compression)

INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Coal Formation',
    'physical',
    1,
    0.950,  -- 95% success
    '[{"type":"element","id":"lkC","amount":5}]',
    '[{"type":"compound","id":"Coal","amount":1}]',
    true,
    true
);

-- ============================================================================
-- NUCLEAR REACTION: Carbon-14 Creation
-- ============================================================================
-- Players need lkC14 for nuclear reactions
-- This is the "special" reaction mentioned in previous design
-- lkC + [catalyst/energy] → lkC14 (Low success rate)

INSERT INTO reactions (
    reaction_name,
    reaction_type,
    energy_cost,
    success_rate,
    inputs,
    outputs,
    unlocked_by_default,
    discovery_bonus
) VALUES
(
    'Carbon-14 Synthesis (Nuclear)',
    'nuclear',
    5,
    0.100,  -- 10% success - difficult to obtain
    '[{"type":"element","id":"lkC","amount":1}]',
    '[{"type":"element","id":"lkC14","amount":1}]',
    true,
    true
);

-- ============================================================================
-- ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE reactions IS 'All chemical and nuclear reactions. Nuclear reactions have multiple possible outcomes based on success/failure rates.';

-- ============================================================================
-- SUMMARY OF NUCLEAR REACTIONS
-- ============================================================================

-- Players progression:
-- 1. Walk → Get lkC
-- 2. lkC (10% success) → lkC14 (Carbon-14 synthesis)
-- 3. lkC + lkC14 (10% success) → lkO (Oxygen unlock!)
-- 4. 5 lkC (95% success) → Coal (Make fuel)
-- 5. lkC14 + lkO + Coal (10% success) → O2 + lkH (Hydrogen unlock!)
--    - 85% failure → CO (Carbon monoxide byproduct)
--    - 5% failure → lkO18 + lkC (Rare isotope!)
-- 6. 2 lkC14 + lkO (15% success) → lkCa (Calcium unlock!)
--    - 65% failure → 2 lkC + lkO (Get materials back)
--    - 17% failure → 3 lkO (Oxygen multiplication!)
--    - 8.5% failure → 2 lkC + lkO + 2 lkH (Bonus hydrogen!)

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify elements
-- SELECT * FROM elements WHERE id LIKE 'lk%' ORDER BY rarity, name;

-- Verify nuclear reactions
-- SELECT id, reaction_name, success_rate, inputs, outputs FROM reactions WHERE reaction_type = 'nuclear' ORDER BY id;

-- Count reactions by type
-- SELECT reaction_type, COUNT(*) FROM reactions GROUP BY reaction_type;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================

# 🚀 ReAgenyx Chemistry System - Quick Start Guide

**Get your chemistry system running in 5 minutes!**

---

## ✅ Prerequisites

- ✅ PostgreSQL database running
- ✅ Node.js backend installed
- ✅ Godot 4.3+ installed
- ✅ Backend migrations applied (008 & 009)

---

## 🔥 5-Minute Setup

### Step 1: Apply Energy Migration (30 seconds)

```bash
cd backend
psql -U tobiasd -d reagenyx -f src/db/migrations/010_energy_system.sql
```

**Expected output:**
```
CREATE TABLE
CREATE INDEX
ALTER TABLE
CREATE FUNCTION
...
```

### Step 2: Start Backend (10 seconds)

```bash
npm run dev
```

**Expected output:**
```
✅ ReAgenyx Backend started successfully
✅ Database connected: reagenyx
✅ API server listening on port 3000
```

### Step 3: Add Test Data (20 seconds)

```bash
psql -U tobiasd -d reagenyx << 'EOF'
INSERT INTO player_inventory (player_wallet, item_type, item_id, amount, total_created)
VALUES
  ('TestWallet123', 'element', 'lkH', 100, 100),
  ('TestWallet123', 'element', 'lkO', 100, 100),
  ('TestWallet123', 'element', 'lkC', 500, 500),
  ('TestWallet123', 'element', 'lkCa', 50, 50)
ON CONFLICT (player_wallet, item_type, item_id)
DO UPDATE SET amount = EXCLUDED.amount;
EOF
```

### Step 4: Test API (30 seconds)

```bash
# Test energy endpoint
curl http://localhost:3000/api/player/energy/TestWallet123

# Test reaction
curl -X POST http://localhost:3000/api/chemistry/react \
  -H "Content-Type: application/json" \
  -d '{"player_wallet": "TestWallet123", "reaction_id": 1}'
```

**Expected:** Energy: 100⚡, Reaction: Success or Failure

### Step 5: Add to Godot (2 minutes)

**Edit `project.godot`:**
```ini
[autoload]
ChemistryAPIManager="*res://autoload/chemistry_api_manager.gd"
```

**In any scene:**
```gdscript
func _ready():
    # Set test wallet
    ChemistryAPIManager.player_wallet = "TestWallet123"

    # Open chemistry lab
    var lab = load("res://scenes/ui/chemistry_lab.tscn").instantiate()
    add_child(lab)
```

### Step 6: Run & Test! (1 minute)

1. Run your Godot project
2. You should see:
   - Energy bar: 100⚡ / 100⚡
   - 20 available reactions
   - Inventory with materials
3. Click a reaction → See result popup!

---

## 🎮 Quick Test Reactions

### Water Formation (easiest)
- **ID:** 1
- **Cost:** 2⚡
- **Inputs:** 2 lkH + 1 lkO
- **Success Rate:** 85%
- **Output:** 1 H₂O

### Carbon Dioxide
- **ID:** 2
- **Cost:** 2⚡
- **Inputs:** 1 lkC + 2 lkO
- **Success Rate:** 80%
- **Output:** 1 CO₂

### Oxygen Synthesis (nuclear)
- **ID:** 12
- **Cost:** 5⚡
- **Inputs:** 1 lkC + 1 lkC14
- **Success Rate:** 10%
- **Output:** 1 lkO (if success)

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check if port 3000 is in use
lsof -i :3000

# Kill process if needed
kill -9 <PID>
```

### "No reactions loaded"
**Cause:** Database migrations not applied
```bash
psql -U tobiasd -d reagenyx -f src/db/migrations/008_chemistry_system.sql
psql -U tobiasd -d reagenyx -f src/db/migrations/009_nuclear_reactions.sql
```

### "Insufficient energy"
```bash
# Restore energy to 100
curl -X POST http://localhost:3000/api/player/energy/restore \
  -H "Content-Type: application/json" \
  -d '{"player_wallet": "TestWallet123", "energy_amount": 100}'
```

### Godot: "ChemistryAPIManager not found"
**Solution:** Add to project.godot autoload section (see Step 5)

---

## 📚 Next Steps

1. Read full docs: `docs/GODOT_CHEMISTRY_UI.md`
2. Customize UI colors
3. Add sound effects
4. Create tutorial
5. Test on mobile device

---

## 🎉 You're Ready!

Your chemistry system is now fully functional!

Players can:
- ✅ View their energy
- ✅ Browse 20 reactions
- ✅ Perform chemistry reactions
- ✅ See success/failure results
- ✅ Discover new compounds
- ✅ Track their inventory

**Have fun experimenting! 🧪⚡**

# 🧪 ReAgenyx Chemistry API Documentation

Complete API reference for the chemistry system.

---

## 🌐 Base URL

```
http://localhost:3000/api/chemistry
```

---

## 📚 Endpoints Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/elements` | List all elements |
| GET | `/elements/:id` | Get single element |
| GET | `/compounds` | List all compounds |
| GET | `/compounds/:id` | Get compound with discovery info |
| GET | `/reactions` | List all reactions (optional filter) |
| GET | `/reactions/:id` | Get single reaction |
| GET | `/inventory/:wallet` | Get player inventory |
| POST | `/react` | Perform a reaction |
| GET | `/unlocks/:wallet` | Get player unlocks |
| GET | `/history/:wallet` | Get reaction history |

---

## 📖 Detailed API Reference

### 1. GET /elements

List all elements in the game.

**Response:**
```json
{
  "success": true,
  "count": 5,
  "data": [
    {
      "id": "lkC",
      "name": "Carbon",
      "symbol": "C",
      "rarity": "common",
      "unlock_method": "walking",
      "base_energy_cost": 0,
      "atomic_number": 6,
      "description": "Base element obtained from walking. Foundation of all organic chemistry.",
      "created_at": "2025-11-22T11:21:20.858Z"
    }
  ]
}
```

---

### 2. GET /elements/:id

Get a single element by ID.

**Example:**
```bash
curl http://localhost:3000/api/chemistry/elements/lkC
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "lkC",
    "name": "Carbon",
    "symbol": "C",
    "rarity": "common",
    "unlock_method": "walking",
    "base_energy_cost": 0,
    "atomic_number": 6,
    "description": "Base element obtained from walking."
  }
}
```

---

### 3. GET /compounds

List all compounds in the game.

**Response:**
```json
{
  "success": true,
  "count": 14,
  "data": [
    {
      "id": "H2O",
      "name": "Water",
      "chemical_formula": "H₂O",
      "category": "basic",
      "base_value": 10,
      "rarity": "common",
      "description": "Essential compound for life and many reactions",
      "real_world_uses": "Drinking, cleaning, chemical reactions, cooling",
      "created_at": "2025-11-22T11:21:20.861Z"
    }
  ]
}
```

---

### 4. GET /compounds/:id

Get a compound with discovery information.

**Example:**
```bash
curl http://localhost:3000/api/chemistry/compounds/H2O
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "H2O",
    "name": "Water",
    "chemical_formula": "H₂O",
    "category": "basic",
    "base_value": 10,
    "rarity": "common",
    "description": "Essential compound for life",
    "real_world_uses": "Drinking, cleaning, reactions",
    "discovery": {
      "id": 1,
      "reaction_id": 1,
      "compound_id": "H2O",
      "discoverer_wallet": "TestWallet123",
      "discovery_date": "2025-11-25T08:24:22.439Z",
      "blockchain_tx": null,
      "tax_free_until": "2025-11-28T08:24:22.439Z",
      "total_royalties_earned": 0
    }
  }
}
```

---

### 5. GET /reactions

List all reactions. Optional filter by type.

**Query Parameters:**
- `type` (optional): Filter by reaction type (`chemical`, `nuclear`, `physical`)

**Example:**
```bash
# All reactions
curl http://localhost:3000/api/chemistry/reactions

# Nuclear reactions only
curl "http://localhost:3000/api/chemistry/reactions?type=nuclear"
```

**Response:**
```json
{
  "success": true,
  "count": 9,
  "filter": { "type": "nuclear" },
  "data": [
    {
      "id": 12,
      "reaction_name": "Oxygen Synthesis (Nuclear)",
      "reaction_type": "nuclear",
      "energy_cost": 5,
      "success_rate": "0.100",
      "inputs": [
        { "type": "element", "id": "lkC", "amount": 1 },
        { "type": "element", "id": "lkC14", "amount": 1 }
      ],
      "outputs": [
        { "type": "element", "id": "lkO", "amount": 1 }
      ],
      "unlocked_by_default": true,
      "discovery_bonus": true
    }
  ]
}
```

---

### 6. GET /reactions/:id

Get a single reaction by ID.

**Example:**
```bash
curl http://localhost:3000/api/chemistry/reactions/1
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "reaction_name": "Water Formation",
    "reaction_type": "chemical",
    "energy_cost": 2,
    "success_rate": "0.850",
    "inputs": [
      { "type": "element", "id": "lkH", "amount": 2 },
      { "type": "element", "id": "lkO", "amount": 1 }
    ],
    "outputs": [
      { "type": "compound", "id": "H2O", "amount": 1 }
    ]
  }
}
```

---

### 7. GET /inventory/:wallet

Get a player's full inventory (elements + compounds).

**Example:**
```bash
curl http://localhost:3000/api/chemistry/inventory/TestWallet123
```

**Response:**
```json
{
  "success": true,
  "wallet": "TestWallet123",
  "total_items": 5,
  "data": {
    "elements": [
      {
        "id": 1,
        "player_wallet": "TestWallet123",
        "item_type": "element",
        "item_id": "lkC",
        "amount": "98",
        "total_created": "100",
        "last_updated": "2025-11-25T08:19:55.276Z"
      },
      {
        "item_id": "lkH",
        "amount": "46",
        "total_created": "50"
      }
    ],
    "compounds": [
      {
        "item_id": "H2O",
        "amount": "1",
        "total_created": "1"
      }
    ]
  }
}
```

---

### 8. POST /react

Perform a chemical, nuclear, or physical reaction.

**Request Body:**
```json
{
  "player_wallet": "TestWallet123",
  "reaction_id": 1
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/chemistry/react \
  -H "Content-Type: application/json" \
  -d '{"player_wallet": "TestWallet123", "reaction_id": 1}'
```

**Success Response (Reaction Succeeded):**
```json
{
  "success": true,
  "data": {
    "success": true,
    "reaction_id": 1,
    "reaction_name": "Water Formation",
    "energy_spent": 2,
    "inputs_consumed": [
      { "id": "lkH", "type": "element", "amount": 2 },
      { "id": "lkO", "type": "element", "amount": 1 }
    ],
    "outputs_created": [
      { "id": "H2O", "type": "compound", "amount": 1 }
    ],
    "discovery": {
      "first_discovery": true,
      "compound_id": "H2O",
      "tax_free_until": "2025-11-28T08:24:22.447Z"
    }
  }
}
```

**Success Response (Reaction Failed):**
```json
{
  "success": true,
  "data": {
    "success": false,
    "reaction_id": 1,
    "reaction_name": "Water Formation",
    "energy_spent": 2,
    "inputs_consumed": [
      { "id": "lkH", "type": "element", "amount": 2 },
      { "id": "lkO", "type": "element", "amount": 1 }
    ]
  }
}
```

**Error Response (Insufficient Materials):**
```json
{
  "success": false,
  "message": "Insufficient lkH: need 2, have 0"
}
```

---

### 9. GET /unlocks/:wallet

Get player's unlocked elements, compounds, and reactions.

**Query Parameters:**
- `type` (optional): Filter by unlock type (`element`, `compound`, `reaction`)

**Example:**
```bash
curl "http://localhost:3000/api/chemistry/unlocks/TestWallet123?type=compound"
```

**Response:**
```json
{
  "success": true,
  "wallet": "TestWallet123",
  "total_unlocks": 1,
  "filter": { "type": "compound" },
  "data": {
    "elements": [],
    "compounds": [
      {
        "id": 1,
        "player_wallet": "TestWallet123",
        "unlock_type": "compound",
        "unlock_id": "H2O",
        "unlocked_at": "2025-11-25T08:24:22.437Z",
        "unlock_method": "reaction"
      }
    ],
    "reactions": []
  }
}
```

---

### 10. GET /history/:wallet

Get player's reaction history with success rate stats.

**Query Parameters:**
- `limit` (optional): Number of entries to return (default: 50)

**Example:**
```bash
curl "http://localhost:3000/api/chemistry/history/TestWallet123?limit=10"
```

**Response:**
```json
{
  "success": true,
  "wallet": "TestWallet123",
  "total_attempts": 4,
  "successful_reactions": 1,
  "success_rate": "25.0%",
  "data": [
    {
      "id": 4,
      "player_wallet": "TestWallet123",
      "reaction_id": 1,
      "success": true,
      "energy_spent": 2,
      "inputs_consumed": [
        { "id": "lkH", "type": "element", "amount": 2 },
        { "id": "lkO", "type": "element", "amount": 1 }
      ],
      "outputs_created": [
        { "id": "H2O", "type": "compound", "amount": 1 }
      ],
      "tax_paid": 0,
      "created_at": "2025-11-25T08:24:22.431Z",
      "reaction_name": "Water Formation",
      "reaction_type": "chemical"
    }
  ]
}
```

---

## 🎮 Usage Examples

### Complete Gameplay Flow

#### 1. Check Available Elements
```bash
curl http://localhost:3000/api/chemistry/elements
```

#### 2. Check Player Inventory
```bash
curl http://localhost:3000/api/chemistry/inventory/YOUR_WALLET
```

#### 3. Find Available Reactions
```bash
# Nuclear reactions (element unlocking)
curl "http://localhost:3000/api/chemistry/reactions?type=nuclear"

# Chemical reactions (compounds)
curl "http://localhost:3000/api/chemistry/reactions?type=chemical"
```

#### 4. Perform a Reaction
```bash
# Oxygen Synthesis: lkC + lkC14 → lkO (10% success)
curl -X POST http://localhost:3000/api/chemistry/react \
  -H "Content-Type: application/json" \
  -d '{
    "player_wallet": "YOUR_WALLET",
    "reaction_id": 12
  }'
```

#### 5. Check Discovery Status
```bash
curl http://localhost:3000/api/chemistry/compounds/H2O
```

#### 6. View Reaction History
```bash
curl http://localhost:3000/api/chemistry/history/YOUR_WALLET
```

---

## 🔬 Nuclear Reactions (Element Unlocking)

### Carbon-14 Synthesis
```
lkC → lkC14 (10% success)
Energy: 5⚡
```

### Oxygen Unlock
```
lkC + lkC14 → lkO (10% success)
Energy: 5⚡
```

### Hydrogen Unlock
```
lkC14 + lkO + Coal → 0.5 O2 + lkH (10% success)
Energy: 5⚡

Failure outcomes:
- 85% → CO (Carbon Monoxide)
- 5% → lkO18 + lkC (Rare isotope!)
```

### Calcium Unlock
```
2 lkC14 + lkO → lkCa (15% success)
Energy: 5⚡

Failure outcomes:
- 65% → 2 lkC + lkO (Materials back)
- 17% → 3 lkO (Oxygen burst!)
- 8.5% → 2 lkC + lkO + 2 lkH (Bonus hydrogen!)
```

### Coal Formation
```
5 lkC → Coal (95% success)
Energy: 1⚡
Type: Physical
```

---

## ⚗️ Chemical Reactions (Compounds)

### Water Formation (ESSENTIAL!)
```
2 lkH + lkO → H2O (85% success)
Energy: 2⚡
```

### Carbon Dioxide
```
lkC + 2 lkO → CO2 (80% success)
Energy: 2⚡
```

### Calcium Oxide
```
2 lkCa + lkO → 2 CaO (75% success)
Energy: 2⚡
```

### Calcium Carbonate (GOAL!)
```
Ca(OH)2 + CO2 → CaCO3 + H2O (85% success)
Energy: 3⚡
```

---

## 🎯 Discovery System

### First Global Discovery
When a player creates a compound for the first time globally:
- ✅ Recorded in `discoveries` table
- ✅ 72-hour tax-free period
- ✅ Blockchain NFT minting (TODO)
- ✅ Discoverer gets 2% royalty from future creators

### Discovery Response
```json
{
  "discovery": {
    "first_discovery": true,
    "compound_id": "H2O",
    "tax_free_until": "2025-11-28T08:24:22.447Z"
  }
}
```

---

## 📊 Success Rates

| Reaction Type | Success Rate | Energy Cost |
|---------------|--------------|-------------|
| Physical (Coal) | 95% | 1⚡ |
| Chemical (Simple) | 80-90% | 2⚡ |
| Chemical (Complex) | 60-85% | 3⚡ |
| Nuclear (Element Unlock) | 10-15% | 5⚡ |

---

## 🔐 Error Handling

### Common Errors

**Insufficient Materials:**
```json
{
  "success": false,
  "message": "Insufficient lkH: need 2, have 0"
}
```

**Invalid Reaction ID:**
```json
{
  "success": false,
  "message": "Reaction 999 not found"
}
```

**Missing Parameters:**
```json
{
  "success": false,
  "message": "player_wallet is required"
}
```

---

## 🚀 Integration with Godot

### Example Godot HTTP Request

```gdscript
func perform_reaction(reaction_id: int):
    var url = "http://localhost:3000/api/chemistry/react"
    var headers = ["Content-Type: application/json"]
    var body = JSON.stringify({
        "player_wallet": wallet_address,
        "reaction_id": reaction_id
    })

    $HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_http_request_completed(result, response_code, headers, body):
    var json = JSON.parse_string(body.get_string_from_utf8())

    if json.data.success:
        print("Reaction succeeded!")
        if json.data.discovery:
            print("FIRST DISCOVERY: " + json.data.discovery.compound_id)
    else:
        print("Reaction failed - materials consumed")
```

---

## 📈 Testing

### Test Data Setup
```bash
# Add test inventory
psql -U tobiasd -d reagenyx -c "
INSERT INTO player_inventory (player_wallet, item_type, item_id, amount, total_created)
VALUES
  ('TestWallet', 'element', 'lkC', 100, 100),
  ('TestWallet', 'element', 'lkH', 50, 50),
  ('TestWallet', 'element', 'lkO', 50, 50)
ON CONFLICT (player_wallet, item_type, item_id)
DO UPDATE SET amount = EXCLUDED.amount;
"
```

### Test Successful Reaction
```bash
# Water Formation (85% success rate - try a few times)
curl -X POST http://localhost:3000/api/chemistry/react \
  -H "Content-Type: application/json" \
  -d '{"player_wallet": "TestWallet", "reaction_id": 1}'
```

---

## ✅ API Status

All endpoints are **LIVE** and tested:
- ✅ GET /elements
- ✅ GET /compounds
- ✅ GET /reactions
- ✅ GET /inventory/:wallet
- ✅ POST /react (with discovery system!)
- ✅ GET /unlocks/:wallet
- ✅ GET /history/:wallet

**Server Status:** Running on port 3000
**Database:** reagenyx (PostgreSQL)
**Backend:** Node.js + Express + TypeScript

---

## 🔮 Next Steps

1. **Energy System** - Implement energy (⚡) management
2. **Player Balance Integration** - Connect with alSOL system
3. **Blockchain NFT Minting** - Mint discovery NFTs on Solana
4. **Tax System** - Implement 10% creation tax + 2% royalties
5. **Godot Integration** - Connect mobile app to chemistry API
6. **Tutorial System** - Guide players through first reactions

---

**ReAgenyx Chemistry API v1.0** 🧪
*Walk. Discover. Own.*

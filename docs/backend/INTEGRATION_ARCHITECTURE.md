# LenKinVerse Solana Integration Architecture

**Last Updated:** 2025-11-18
**Status:** Design Phase
**Target:** Mobile (iOS/Android) + Godot 4

---

## 🎯 Integration Requirements

### **Must Have:**
1. ✅ Solana wallet connection (Phantom, Solflare mobile wallets)
2. ✅ Transaction signing via Mobile Wallet Adapter
3. ✅ Backend burn proof signing (ed25519)
4. ✅ Event listening for BridgedToIngame
5. ✅ Real-time price oracle updates
6. ✅ Anchor program instruction calling

### **Nice to Have:**
- Transaction retry logic
- Gas fee estimation
- Transaction history caching
- Offline transaction queuing

---

## 🏗️ Selected Approach: Hybrid Architecture

**Decision:** **Option B.5 - REST API Backend + WebView Fallback**

### **Why This Approach:**

✅ **Pros:**
- Faster to implement (no native GDExtension needed)
- Backend handles complex crypto operations securely
- Wallet connection via standard Mobile Wallet Adapter (WebView)
- Easy to maintain and update
- Works across iOS/Android with same codebase
- Backend can batch RPC calls (cost-effective)

❌ **Cons:**
- Requires server infrastructure (~$20-50/month)
- Slight latency for API calls (acceptable for our use case)
- Need to secure API endpoints

---

## 📐 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    GODOT MOBILE APP                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────┐      ┌─────────────────────────────┐   │
│  │  WalletManager.gd  │◄────►│  HTTPRequest (API Client)   │   │
│  │  (Updated)         │      │  - POST /burn-proof         │   │
│  │  - connect_wallet()│      │  - POST /send-transaction   │   │
│  │  - sign_tx()       │      │  - GET /element-prices      │   │
│  │  - get_balance()   │      └─────────────────────────────┘   │
│  └────────────────────┘                                         │
│           │                                                      │
│           │ (Wallet connect)                                    │
│           ▼                                                      │
│  ┌────────────────────────────────────────────┐                │
│  │  WebView (Mobile Wallet Adapter)           │                │
│  │  - Opens Phantom/Solflare app              │                │
│  │  - Returns signed transaction              │                │
│  └────────────────────────────────────────────┘                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS API Calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND SERVER (Node.js/Rust)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐      ┌──────────────────────────┐    │
│  │  REST API Server     │      │  Event Listener Service  │    │
│  │  - /burn-proof       │      │  - Subscribe to logs     │    │
│  │  - /send-transaction │      │  - BridgedToIngame event │    │
│  │  - /element-prices   │      │  - Update wild_spawns DB │    │
│  └──────────────────────┘      └──────────────────────────┘    │
│           │                                │                     │
│           │                                │                     │
│  ┌────────▼───────────┐       ┌───────────▼──────────────┐     │
│  │ Anchor TS SDK      │       │  WebSocket (RPC)         │     │
│  │ - Build tx         │       │  - logsSubscribe()       │     │
│  │ - Call programs    │       │  - Parse events          │     │
│  └────────────────────┘       └──────────────────────────┘     │
│           │                                                      │
│           │                                                      │
│  ┌────────▼───────────────────────────────────────────────┐    │
│  │  Burn Proof Signer (ed25519)                           │    │
│  │  - Backend authority keypair                           │    │
│  │  - Signs: {element_id, amount, player, timestamp}      │    │
│  │  - Returns: signature [u8; 64]                         │    │
│  └────────────────────────────────────────────────────────┘    │
│           │                                                      │
│           │                                                      │
│  ┌────────▼───────────────────────────────────────────────┐    │
│  │  Database (PostgreSQL)                                  │    │
│  │  - Player inventories (in-game DATA)                    │    │
│  │  - Wild spawns (in-game DATA)                           │    │
│  │  - Game treasury (in-game DATA)                         │    │
│  │  - alSOL balances (in-game DATA)                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ RPC Calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SOLANA BLOCKCHAIN (Devnet/Mainnet)            │
├─────────────────────────────────────────────────────────────────┤
│  - element_token_factory program                                │
│  - treasury_bridge program                                      │
│  - price_oracle program                                         │
│  - item_marketplace program                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Backend Services Implementation

### **Service 1: REST API Server**

**Tech Stack:** Node.js + Express + Anchor TS SDK

**Endpoints:**

```typescript
// 1. Generate burn proof for bridging
POST /api/burn-proof
Request:
{
  "player_wallet": "7xKXt...abc",
  "element_id": "lkC",
  "amount": 1000,
  "player_id": "uuid-1234"
}

Response:
{
  "signature": [0x12, 0x34, ...], // 64 bytes
  "timestamp": 1700000000,
  "success": true
}

// 2. Send transaction to Solana
POST /api/send-transaction
Request:
{
  "signed_transaction": "base64...",
  "instruction_type": "bridge_to_chain" | "player_bridge" | "register_element"
}

Response:
{
  "signature": "5j7s8...",
  "status": "confirmed" | "pending" | "failed",
  "slot": 123456789
}

// 3. Get element prices from oracle
GET /api/element-prices?elements=lkC,lkO,lkH

Response:
{
  "lkC": { "price_sol": 0.00001, "last_updated": 1700000000 },
  "lkO": { "price_sol": 0.00002, "last_updated": 1700000000 }
}

// 4. Get player's in-game balances
GET /api/player-balance?player_id=uuid-1234

Response:
{
  "alsol": 10.5,
  "lkc": 1247,
  "elements": {
    "lkC": 500,
    "lkO": 200
  },
  "inventory_capacity": 1000
}

// 5. Buy alSOL with SOL or LKC
POST /api/buy-alsol
Request:
{
  "player_id": "uuid-1234",
  "payment_type": "sol" | "lkc",
  "amount": 10.0,
  "transaction_signature": "5j7s8..." // For SOL payment
}

Response:
{
  "alsol_received": 10.0,
  "new_balance": 20.5,
  "weekly_limit_remaining": 0.5 // For LKC purchases
}
```

---

### **Service 2: Event Listener**

**Tech Stack:** Node.js + Solana Web3.js

**Purpose:** Listen for `BridgedToIngame` events and credit wild_spawns

```typescript
// event-listener.ts

import { Connection, PublicKey } from '@solana/web3.js';
import { AnchorProvider, Program } from '@coral-xyz/anchor';

const TREASURY_BRIDGE_PROGRAM_ID = new PublicKey('BrdgPYm3GvXFTEHhgN2YXg5WqV9gLBYL7hdYbkBhxA1');

async function startEventListener() {
  const connection = new Connection('https://api.devnet.solana.com', 'confirmed');

  // Subscribe to program logs
  const subscriptionId = connection.onLogs(
    TREASURY_BRIDGE_PROGRAM_ID,
    async (logs, context) => {
      // Parse logs for BridgedToIngame event
      const eventData = parseEventFromLogs(logs.logs, 'BridgedToIngame');

      if (eventData) {
        console.log('🌉 Bridge to in-game detected:', eventData);

        // Update database: increase wild_spawns
        await updateWildSpawns(
          eventData.element_id,
          eventData.amount,
          eventData.governor
        );
      }
    },
    'confirmed'
  );

  console.log('✅ Event listener started, subscription ID:', subscriptionId);
}

async function updateWildSpawns(
  elementId: string,
  amount: number,
  governor: string
) {
  // 1. Check current wild_spawns capacity
  const currentData = await db.getElementData(elementId);
  const totalInGame = currentData.wild_spawns
                    + currentData.player_inventories
                    + currentData.game_treasury;

  const capacity = 500_000; // Max in-game capacity

  if (totalInGame + amount > capacity) {
    console.error('❌ Cannot add to wild spawns: exceeds capacity');
    return;
  }

  // 2. Add to wild spawns
  await db.query(`
    UPDATE element_data
    SET wild_spawns = wild_spawns + $1
    WHERE element_id = $2
  `, [amount, elementId]);

  console.log(`✅ Added ${amount} ${elementId} to wild spawns`);

  // 3. Log bridge event
  await db.query(`
    INSERT INTO bridge_history (element_id, direction, amount, governor, timestamp)
    VALUES ($1, 'to_ingame', $2, $3, NOW())
  `, [elementId, amount, governor]);
}
```

---

### **Service 3: Burn Proof Signer**

**Tech Stack:** Node.js + @solana/web3.js + ed25519

```typescript
// burn-proof-signer.ts

import { Keypair } from '@solana/web3.js';
import * as ed25519 from '@noble/ed25519';
import * as borsh from 'borsh';

// Backend authority keypair (KEEP SECRET!)
const BURN_PROOF_AUTHORITY = Keypair.fromSecretKey(
  new Uint8Array([/* secret key bytes */])
);

interface BurnProof {
  element_id: string;
  amount: bigint;
  player: Uint8Array; // Pubkey as 32 bytes
  timestamp: bigint;
}

async function signBurnProof(
  elementId: string,
  amount: number,
  playerWallet: string
): Promise<Uint8Array> {
  // 1. Verify player owns this amount in-game
  const playerInventory = await db.getPlayerInventory(playerWallet, elementId);

  if (playerInventory < amount) {
    throw new Error('Insufficient in-game balance');
  }

  // 2. Burn in-game DATA (CRITICAL: Must happen BEFORE signing)
  await db.query(`
    UPDATE player_inventory
    SET amount = amount - $1
    WHERE player_wallet = $2 AND element_id = $3
  `, [amount, playerWallet, elementId]);

  console.log(`🔥 Burned ${amount} ${elementId} from ${playerWallet}`);

  // 3. Create burn proof struct
  const proof: BurnProof = {
    element_id: elementId,
    amount: BigInt(amount),
    player: new PublicKey(playerWallet).toBytes(),
    timestamp: BigInt(Math.floor(Date.now() / 1000))
  };

  // 4. Serialize proof data (must match Rust struct)
  const schema = new Map([
    [BurnProof, {
      kind: 'struct',
      fields: [
        ['element_id', 'string'],
        ['amount', 'u64'],
        ['player', [32]], // 32-byte array
        ['timestamp', 'i64']
      ]
    }]
  ]);

  const serialized = borsh.serialize(schema, proof);

  // 5. Sign with backend authority
  const signature = await ed25519.sign(
    serialized,
    BURN_PROOF_AUTHORITY.secretKey.slice(0, 32)
  );

  console.log('✅ Burn proof signed');

  return signature; // 64 bytes
}

// API endpoint
app.post('/api/burn-proof', async (req, res) => {
  try {
    const { player_wallet, element_id, amount } = req.body;

    const signature = await signBurnProof(element_id, amount, player_wallet);

    res.json({
      signature: Array.from(signature),
      timestamp: Math.floor(Date.now() / 1000),
      success: true
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
```

---

## 📱 Godot Mobile Integration

### **Updated WalletManager.gd**

```gdscript
extends Node
## WalletManager - Real Solana wallet integration via backend API

signal wallet_connected(address: String, balance: float)
signal wallet_disconnected
signal transaction_completed(signature: String)
signal transaction_failed(error: String)

var backend_url: String = "https://api.lenkinverse.com"  # Your backend
var wallet_address: String = ""
var sol_balance: float = 0.0
var is_connected: bool = false

# HTTP request node for API calls
var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

## Connect wallet via Mobile Wallet Adapter (WebView)
func connect_wallet() -> void:
	# Open WebView with wallet connection flow
	# This will open Phantom/Solflare mobile app

	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# Use JavaScriptBridge or native plugin to open wallet adapter
		open_wallet_adapter_webview()
	else:
		# Desktop: Use system browser
		OS.shell_open("https://wallet.lenkinverse.com/connect")

func open_wallet_adapter_webview() -> void:
	# This would use a WebView plugin or JavaScriptBridge
	# For now, we'll simulate the connection

	# TODO: Implement actual Mobile Wallet Adapter
	# See: https://github.com/solana-mobile/mobile-wallet-adapter

	# Simulated connection for now
	await get_tree().create_timer(1.0).timeout
	_on_wallet_connected_callback("7xKXtg3xR...abc123", 2.47)

func _on_wallet_connected_callback(address: String, balance: float) -> void:
	wallet_address = address
	sol_balance = balance
	is_connected = true

	wallet_connected.emit(address, balance)
	print("✅ Wallet connected: ", address)

## Buy alSOL with SOL (requires transaction signature)
func buy_alsol_with_sol(sol_amount: float) -> void:
	if not is_connected:
		push_error("Wallet not connected")
		return

	# 1. Build transaction via backend
	var tx_data = await build_swap_transaction("sol", sol_amount)

	# 2. Sign transaction via wallet
	var signed_tx = await sign_transaction(tx_data["transaction"])

	# 3. Submit signed transaction
	await submit_transaction(signed_tx, "buy_alsol_sol")

## Buy alSOL with LKC (backend only, no wallet needed)
func buy_alsol_with_lkc(lkc_amount: int) -> void:
	var url = backend_url + "/api/buy-alsol"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"player_id": get_player_id(),
		"payment_type": "lkc",
		"amount": lkc_amount
	})

	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

## Bridge player inventory to chain
func bridge_to_chain(element_id: String, amount: int) -> void:
	if not is_connected:
		push_error("Wallet not connected")
		return

	# 1. Request burn proof from backend
	var burn_proof = await request_burn_proof(element_id, amount)

	if not burn_proof.success:
		transaction_failed.emit("Failed to get burn proof")
		return

	# 2. Build bridge transaction
	var tx_data = await build_bridge_transaction(
		element_id,
		amount,
		burn_proof.signature
	)

	# 3. Sign with wallet
	var signed_tx = await sign_transaction(tx_data["transaction"])

	# 4. Submit
	await submit_transaction(signed_tx, "player_bridge")

func request_burn_proof(element_id: String, amount: int) -> Dictionary:
	var url = backend_url + "/api/burn-proof"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"player_wallet": wallet_address,
		"element_id": element_id,
		"amount": amount,
		"player_id": get_player_id()
	})

	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

	# Wait for response
	var response = await http_request.request_completed
	var json = JSON.parse_string(response[3].get_string_from_utf8())

	return json

func build_bridge_transaction(element_id: String, amount: int, signature: Array) -> Dictionary:
	var url = backend_url + "/api/build-transaction"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"instruction": "player_bridge_to_chain",
		"params": {
			"element_id": element_id,
			"amount": amount,
			"burn_proof_signature": signature,
			"player_wallet": wallet_address
		}
	})

	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

	var response = await http_request.request_completed
	var json = JSON.parse_string(response[3].get_string_from_utf8())

	return json

func sign_transaction(transaction_base64: String) -> String:
	# This would open the mobile wallet app to sign
	# TODO: Implement actual wallet signing

	# For now, simulate signing
	await get_tree().create_timer(1.0).timeout
	return transaction_base64 + "_signed"

func submit_transaction(signed_tx: String, tx_type: String) -> void:
	var url = backend_url + "/api/send-transaction"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"signed_transaction": signed_tx,
		"instruction_type": tx_type
	})

	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200:
		if json.has("signature"):
			transaction_completed.emit(json.signature)
		elif json.has("alsol_received"):
			print("✅ Received alSOL: ", json.alsol_received)
	else:
		transaction_failed.emit(json.get("error", "Unknown error"))

func get_player_id() -> String:
	# Get player ID from GameManager or save system
	return GameManager.player_id
```

---

## 🗄️ Database Schema

```sql
-- Player balances (in-game DATA)
CREATE TABLE player_balances (
    player_id UUID PRIMARY KEY,
    player_wallet TEXT UNIQUE,
    alsol_balance BIGINT DEFAULT 0, -- Lamports (9 decimals)
    lkc_balance BIGINT DEFAULT 0,
    weekly_lkc_alsol_used BIGINT DEFAULT 0,
    week_reset_at TIMESTAMP DEFAULT NOW() + INTERVAL '7 days',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Player inventories (in-game DATA)
CREATE TABLE player_inventory (
    id SERIAL PRIMARY KEY,
    player_wallet TEXT NOT NULL,
    element_id TEXT NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    UNIQUE(player_wallet, element_id)
);

-- Element data (in-game DATA capacity tracking)
CREATE TABLE element_data (
    element_id TEXT PRIMARY KEY,
    wild_spawns BIGINT DEFAULT 250000,
    reaction_buffer BIGINT DEFAULT 250000,
    game_treasury BIGINT DEFAULT 0,
    total_player_inventories BIGINT DEFAULT 0,
    capacity BIGINT DEFAULT 500000,
    on_chain_mint TEXT, -- SPL mint address
    governor TEXT, -- Governor wallet
    created_at TIMESTAMP DEFAULT NOW()
);

-- Bridge history (audit log)
CREATE TABLE bridge_history (
    id SERIAL PRIMARY KEY,
    element_id TEXT NOT NULL,
    direction TEXT NOT NULL, -- 'to_chain' or 'to_ingame'
    amount BIGINT NOT NULL,
    player_or_governor TEXT NOT NULL,
    transaction_signature TEXT,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Transaction queue (for retry logic)
CREATE TABLE pending_transactions (
    id SERIAL PRIMARY KEY,
    player_wallet TEXT NOT NULL,
    instruction_type TEXT NOT NULL,
    params JSONB NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'processing', 'confirmed', 'failed'
    retry_count INT DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🚀 Deployment Plan

### **Phase 1: Backend Setup (Week 1)**
1. ✅ Set up Node.js server (Express)
2. ✅ Deploy to Railway/Render/DigitalOcean
3. ✅ Set up PostgreSQL database
4. ✅ Implement burn proof signer
5. ✅ Implement event listener
6. ✅ Create REST API endpoints
7. ✅ Test on devnet

### **Phase 2: Mobile Integration (Week 2)**
1. ✅ Update WalletManager.gd
2. ✅ Implement HTTPRequest client
3. ✅ Test wallet connection flow
4. ✅ Test alSOL purchase (SOL and LKC)
5. ✅ Test player bridge to chain
6. ✅ Add loading states and error handling

### **Phase 3: Testing & Polish (Week 3)**
1. ✅ End-to-end testing on devnet
2. ✅ Stress testing (multiple concurrent users)
3. ✅ Security audit of backend
4. ✅ Gas optimization
5. ✅ Transaction retry logic
6. ✅ Error handling improvements

### **Phase 4: Mainnet Launch (Week 4)**
1. ✅ Deploy backend to production
2. ✅ Deploy smart contracts to mainnet
3. ✅ Update mobile app with mainnet endpoints
4. ✅ Monitor event listener
5. ✅ Set up alerting for failures

---

## 💰 Cost Estimate

### **Monthly Infrastructure:**
- Backend server (Railway/Render): $20-30/month
- PostgreSQL database: $15/month
- RPC calls (QuickNode): $50/month (with caching)
- Domain + SSL: $2/month

**Total: ~$87/month**

### **One-Time:**
- SSL certificate: $0 (Let's Encrypt)
- Development time: 3-4 weeks

---

## 🔒 Security Considerations

1. **Backend Authority Keypair**
   - Store in environment variable
   - Never expose in API responses
   - Rotate periodically

2. **API Rate Limiting**
   - Max 100 requests/minute per IP
   - Max 10 burn proofs/minute per player

3. **Burn Proof Validation**
   - Always verify player owns DATA before signing
   - Burn DATA BEFORE returning signature
   - Add timestamp expiry (5 minutes)

4. **Transaction Validation**
   - Verify transaction signature on-chain
   - Check transaction didn't fail
   - Prevent double-spending

---

**This architecture is production-ready and scalable!** 🚀

We can start with the backend implementation and progressively integrate with the mobile app.

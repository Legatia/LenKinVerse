# LenKinVerse Backend

Backend services for LenKinVerse - Handles burn proof signing, event listening, and API endpoints for Godot mobile app.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Services                              │
├─────────────────────────────────────────────────────────────────┤
│  1. REST API Server (Express)                                   │
│     - /api/burn-proof - Generate burn proof signatures          │
│     - /api/player-balance - Get player balances                 │
│     - /api/buy-alsol - Purchase alSOL                           │
│     - /api/send-transaction - Submit transactions               │
│     - /api/element-prices - Get price oracle data               │
│                                                                  │
│  2. Event Listener (WebSocket)                                  │
│     - Listens for BridgedToIngame events                        │
│     - Updates wild_spawns in database                           │
│     - Logs bridge history                                       │
│                                                                  │
│  3. Burn Proof Signer (ed25519)                                 │
│     - Signs burn proofs for bridge operations                   │
│     - CRITICAL: Burns in-game DATA before signing               │
│                                                                  │
│  4. Database (PostgreSQL)                                       │
│     - Player inventories                                        │
│     - Wild spawns                                               │
│     - alSOL balances                                            │
│     - Bridge history                                            │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- PostgreSQL 14+
- Solana CLI (for generating keypair)

### Installation

```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Generate backend authority keypair
solana-keygen new --outfile backend-authority.json
# Copy the secret key array to .env as BURN_PROOF_AUTHORITY_SECRET_KEY

# Create database
createdb lenkinverse

# Run database migrations
psql -d lenkinverse -f database-schema.sql

# Start development server
npm run dev
```

### Running Services

```bash
# Start API server + event listener
npm run dev

# Start only event listener
npm run event-listener

# Build for production
npm run build

# Start production server
npm start
```

## 📚 API Endpoints

### POST /api/burn-proof

Generate burn proof for player bridging

**Request:**
```json
{
  "player_wallet": "7xKXtg3xR...abc",
  "element_id": "lkC",
  "amount": 1000,
  "player_id": "uuid-1234"
}
```

**Response:**
```json
{
  "signature": [0x12, 0x34, ...],
  "timestamp": 1700000000,
  "success": true
}
```

### GET /api/player-balance?player_id=uuid-1234

Get player's in-game balances

**Response:**
```json
{
  "alsol": 10.5,
  "lkc": 1247,
  "elements": {
    "lkC": 500,
    "lkO": 200
  },
  "inventory_capacity": 1000
}
```

### POST /api/buy-alsol

Buy alSOL with SOL or LKC

**Request (SOL):**
```json
{
  "player_id": "uuid-1234",
  "payment_type": "sol",
  "amount": 10.0,
  "transaction_signature": "5j7s8..."
}
```

**Request (LKC):**
```json
{
  "player_id": "uuid-1234",
  "payment_type": "lkc",
  "amount": 1000000
}
```

**Response:**
```json
{
  "alsol_received": 10.0,
  "new_balance": 20.5,
  "weekly_limit_remaining": 0.5,
  "success": true
}
```

## 🔒 Security

### Burn Proof Authority

The burn proof authority keypair is used to sign burn proofs. **Keep it secret!**

**Generate keypair:**
```bash
solana-keygen new --outfile backend-authority.json
```

**Get secret key array:**
```bash
cat backend-authority.json | jq .
```

Copy the full secret key array (64 bytes) to `.env`:
```
BURN_PROOF_AUTHORITY_SECRET_KEY=[1,2,3,...,64]
```

### Critical Security Rules

1. **Always burn DATA before signing**
   - The `signBurnProof` function MUST burn in-game DATA before returning signature
   - This prevents double-spending

2. **Rate limiting**
   - Max 100 requests/minute per IP
   - Max 10 burn proofs/minute per player

3. **Environment variables**
   - Never commit `.env` file
   - Rotate backend authority keypair periodically
   - Use strong database passwords

## 📊 Database Schema

See `database-schema.sql` for full schema.

**Key Tables:**
- `player_balances` - alSOL and LKC balances
- `player_inventory` - Element inventories
- `element_data` - Wild spawns and capacity tracking
- `bridge_history` - Audit log of all bridge operations
- `pending_transactions` - Transaction retry queue

## 🧪 Testing

```bash
# Run all tests
npm test

# Test burn proof signing
curl -X POST http://localhost:3000/api/burn-proof \
  -H "Content-Type: application/json" \
  -d '{
    "player_wallet": "7xKXtg3xR...abc",
    "element_id": "lkC",
    "amount": 100,
    "player_id": "uuid-1234"
  }'

# Check health
curl http://localhost:3000/health
```

## 🚀 Deployment

### Option 1: Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Create project
railway init

# Add PostgreSQL
railway add

# Deploy
railway up
```

### Option 2: Render

1. Create new Web Service
2. Connect GitHub repo
3. Build command: `npm install && npm run build`
4. Start command: `npm start`
5. Add PostgreSQL database
6. Set environment variables

### Option 3: DigitalOcean App Platform

1. Create new app
2. Connect GitHub repo
3. Add PostgreSQL database
4. Configure environment variables
5. Deploy

## 📈 Monitoring

The backend uses Winston for logging.

**Log files:**
- `logs/combined.log` - All logs
- `logs/error.log` - Errors only

**Log levels:**
- `error` - Errors
- `warn` - Warnings (e.g., DATA burns)
- `info` - General info
- `debug` - Debug information

**Set log level:**
```bash
LOG_LEVEL=debug npm run dev
```

## 🔧 Troubleshooting

### Database Connection Failed

```bash
# Check PostgreSQL is running
pg_isready

# Check connection string
psql -d $DATABASE_URL

# Recreate database
dropdb lenkinverse
createdb lenkinverse
psql -d lenkinverse -f database-schema.sql
```

### Event Listener Not Working

```bash
# Check RPC connection
curl $SOLANA_RPC_URL -X POST -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "getHealth"
}
'

# Check program ID
echo $TREASURY_BRIDGE_PROGRAM_ID

# Check WebSocket endpoint
# Make sure SOLANA_WS_URL is set
```

### Burn Proof Signature Invalid

```bash
# Verify backend authority matches on-chain
# The public key must be registered as burn_proof_authority in program

# Get public key
solana-keygen pubkey backend-authority.json

# Compare with on-chain authority
# (Query the treasury_bridge program state)
```

## 📝 Development Notes

### TODO

- [ ] Implement actual ed25519 signature verification
- [ ] Add transaction retry logic
- [ ] Implement proper Anchor event decoding
- [ ] Add rate limiting middleware
- [ ] Add API authentication
- [ ] Add WebSocket support for real-time updates
- [ ] Add Prometheus metrics
- [ ] Add health check for database and RPC
- [ ] Add integration tests
- [ ] Add Docker support

### Known Issues

- Event listener uses simplified log parsing (needs proper Anchor event decoding)
- No rate limiting implemented yet
- No API authentication yet
- Mock transaction submission (needs real Solana integration)

## 📄 License

MIT

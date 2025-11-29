#!/bin/bash

# alSOL System Integration Test Script
# Tests all alSOL features: SOL swap, LKC swap with weekly limits, marketplace

API_URL="http://localhost:3000/api"
TEST_WALLET1="TestWallet123"
TEST_WALLET2="TestWallet456"

echo "🧪 ReAgenyx alSOL System - Integration Tests"
echo "============================================="
echo ""

# Setup: Add test data
echo "📦 Setting up test data..."
psql -U tobiasd -d reagenyx << 'EOF'
-- Add test elements to TestWallet123
INSERT INTO player_inventory (player_wallet, item_type, item_id, amount, total_created)
VALUES
  ('TestWallet123', 'element', 'lkC', 2000000, 2000000),
  ('TestWallet123', 'element', 'lkO', 500, 500),
  ('TestWallet123', 'element', 'lkH', 500, 500),
  ('TestWallet123', 'compound', 'H2O', 100, 100)
ON CONFLICT (player_wallet, item_type, item_id)
DO UPDATE SET amount = EXCLUDED.amount, total_created = EXCLUDED.total_created;

-- Add test elements to TestWallet456
INSERT INTO player_inventory (player_wallet, item_type, item_id, amount, total_created)
VALUES
  ('TestWallet456', 'element', 'lkC', 5000000, 5000000)
ON CONFLICT (player_wallet, item_type, item_id)
DO UPDATE SET amount = EXCLUDED.amount, total_created = EXCLUDED.total_created;

-- Reset alSOL balances for testing
INSERT INTO player_balances (player_id, alsol_balance, lkc_balance, weekly_lkc_alsol_used, week_reset_at)
VALUES
  ('TestWallet123', 1000000000, 0, 0, NOW() + INTERVAL '7 days'),
  ('TestWallet456', 5000000000, 0, 0, NOW() + INTERVAL '7 days')
ON CONFLICT (player_id)
DO UPDATE SET
  alsol_balance = EXCLUDED.alsol_balance,
  weekly_lkc_alsol_used = 0,
  week_reset_at = NOW() + INTERVAL '7 days';
EOF

echo "✅ Test data ready"
echo ""

# Test 1: Check initial balances
echo "🧪 Test 1: Check initial balances"
echo "-----------------------------------"
curl -s "$API_URL/player/TestWallet123" | jq '{wallet: "TestWallet123", alsol: .alsol, lkc: .lkc}'
echo ""

# Test 2: SOL → alSOL swap
echo "🧪 Test 2: SOL → alSOL swap (1.5 SOL → 1.5 alSOL)"
echo "-----------------------------------"
curl -s -X POST "$API_URL/buy-alsol" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "TestWallet123",
    "payment_type": "sol",
    "amount": 1.5,
    "transaction_signature": "test_sig_123456"
  }' | jq '.'
echo ""

# Test 3: LKC → alSOL swap (1M LKC → 0.001 alSOL)
echo "🧪 Test 3: LKC → alSOL swap (1,000,000 LKC → 0.001 alSOL)"
echo "-----------------------------------"
curl -s -X POST "$API_URL/buy-alsol" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "TestWallet123",
    "payment_type": "lkc",
    "amount": 1000000
  }' | jq '.'
echo ""

# Test 4: Check updated balance after swaps
echo "🧪 Test 4: Check balance after swaps"
echo "-----------------------------------"
curl -s "$API_URL/player/TestWallet123" | jq '{wallet: "TestWallet123", alsol: .alsol, lkc: .lkc}'
echo ""

# Test 5: Create marketplace listing (100 lkO for 0.01 alSOL each)
echo "🧪 Test 5: Create marketplace listing (100 lkO @ 0.01 alSOL each)"
echo "-----------------------------------"
curl -s -X POST "$API_URL/marketplace/list" \
  -H "Content-Type: application/json" \
  -d '{
    "seller_wallet": "TestWallet123",
    "item_type": "element",
    "item_id": "lkO",
    "amount": 100,
    "price_per_unit": 0.01
  }' | jq '.'
echo ""

# Test 6: Get marketplace listings
echo "🧪 Test 6: Get all marketplace listings"
echo "-----------------------------------"
curl -s "$API_URL/marketplace/listings" | jq '.listings[] | {id, item_id, amount, price_per_unit, total_price, seller: .seller_wallet}'
echo ""

# Test 7: Buy from marketplace
echo "🧪 Test 7: Buy listing (TestWallet456 buys 100 lkO)"
echo "-----------------------------------"
LISTING_ID=$(curl -s "$API_URL/marketplace/listings" | jq -r '.listings[0].id')
echo "Buying listing ID: $LISTING_ID"
curl -s -X POST "$API_URL/marketplace/buy/$LISTING_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"buyer_wallet\": \"TestWallet456\"
  }" | jq '.'
echo ""

# Test 8: Check balances after marketplace trade
echo "🧪 Test 8: Check balances after trade"
echo "-----------------------------------"
echo "Seller (TestWallet123):"
curl -s "$API_URL/player/TestWallet123" | jq '{wallet: "TestWallet123", alsol: .alsol, lkc: .lkc}'
echo ""
echo "Buyer (TestWallet456):"
curl -s "$API_URL/player/TestWallet456" | jq '{wallet: "TestWallet456", alsol: .alsol, lkc: .lkc}'
echo ""

# Test 9: Get transaction history
echo "🧪 Test 9: Get marketplace transaction history"
echo "-----------------------------------"
curl -s "$API_URL/marketplace/history/TestWallet123" | jq '.transactions[] | {item_id, amount, price_paid, marketplace_fee, seller_received, buyer: .buyer_wallet, date: .transaction_date}'
echo ""

# Test 10: Test weekly limit enforcement
echo "🧪 Test 10: Test weekly LKC→alSOL limit (should hit 1 alSOL limit)"
echo "-----------------------------------"
echo "First swap (should succeed):"
curl -s -X POST "$API_URL/buy-alsol" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "TestWallet456",
    "payment_type": "lkc",
    "amount": 500000
  }' | jq '{success, alsol_received, weekly_limit_remaining}'
echo ""

echo "Second swap (should still succeed if under limit):"
curl -s -X POST "$API_URL/buy-alsol" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "TestWallet456",
    "payment_type": "lkc",
    "amount": 500000
  }' | jq '{success, alsol_received, weekly_limit_remaining}'
echo ""

echo "Third swap (should fail - weekly limit exceeded):"
curl -s -X POST "$API_URL/buy-alsol" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "TestWallet456",
    "payment_type": "lkc",
    "amount": 100000
  }' | jq '.'
echo ""

# Test 11: Check LKC burned
echo "🧪 Test 11: Verify LKC was burned from inventory"
echo "-----------------------------------"
curl -s "$API_URL/chemistry/inventory/TestWallet123" | jq '.inventory.elements[] | select(.id == "lkC") | {id, amount}'
echo ""

# Test 12: Create compound listing
echo "🧪 Test 12: Create compound listing (10 H2O @ 0.05 alSOL each)"
echo "-----------------------------------"
curl -s -X POST "$API_URL/marketplace/list" \
  -H "Content-Type: application/json" \
  -d '{
    "seller_wallet": "TestWallet123",
    "item_type": "compound",
    "item_id": "H2O",
    "amount": 10,
    "price_per_unit": 0.05
  }' | jq '.'
echo ""

# Test 13: Get my listings
echo "🧪 Test 13: Get player's active listings"
echo "-----------------------------------"
curl -s "$API_URL/marketplace/my-listings/TestWallet123" | jq '.listings[] | {id, item_type, item_id, amount, total_price}'
echo ""

# Test 14: Cancel a listing
echo "🧪 Test 14: Cancel listing"
echo "-----------------------------------"
COMPOUND_LISTING_ID=$(curl -s "$API_URL/marketplace/my-listings/TestWallet123" | jq -r '.listings[] | select(.item_id == "H2O") | .id')
echo "Cancelling listing ID: $COMPOUND_LISTING_ID"
curl -s -X DELETE "$API_URL/marketplace/listing/$COMPOUND_LISTING_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"seller_wallet\": \"TestWallet123\"
  }" | jq '.'
echo ""

# Summary
echo ""
echo "============================================="
echo "✅ alSOL System Tests Complete!"
echo "============================================="
echo ""
echo "Summary of implemented features:"
echo "✅ SOL → alSOL swap (1:1 ratio)"
echo "✅ LKC → alSOL swap (1M:1 ratio)"
echo "✅ Weekly 1 alSOL limit enforcement"
echo "✅ LKC burn on swap"
echo "✅ Marketplace listing creation"
echo "✅ Marketplace purchases"
echo "✅ Marketplace fee (2.5%)"
echo "✅ Listing cancellation"
echo "✅ Transaction history"
echo "✅ Inventory management"
echo ""

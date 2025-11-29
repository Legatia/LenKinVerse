import { pool } from './queries';
import { logger } from '../utils/logger';

export interface MarketplaceListing {
  id: number;
  seller_wallet: string;
  item_type: 'element' | 'compound';
  item_id: string;
  item_name?: string;
  amount: number;
  price_per_unit: number; // In alSOL (not lamports)
  total_price: number; // In alSOL
  created_at: Date;
  status: 'active' | 'sold' | 'cancelled';
}

export interface MarketplaceTransaction {
  id: number;
  listing_id: number;
  seller_wallet: string;
  buyer_wallet: string;
  item_type: string;
  item_id: string;
  amount: number;
  price_paid: number; // In alSOL
  marketplace_fee: number; // In alSOL
  seller_received: number; // In alSOL
  transaction_date: Date;
}

/**
 * Create a new marketplace listing
 */
export async function createMarketplaceListing(
  sellerWallet: string,
  itemType: 'element' | 'compound',
  itemId: string,
  amount: number,
  pricePerUnit: number // In alSOL
): Promise<MarketplaceListing> {
  const pricePerUnitLamports = Math.floor(pricePerUnit * 1_000_000_000);
  const totalPriceLamports = pricePerUnitLamports * amount;

  // Check if seller has enough items
  const inventoryResult = await pool.query(
    `SELECT amount FROM player_inventory
     WHERE player_wallet = $1 AND item_type = $2 AND item_id = $3`,
    [sellerWallet, itemType, itemId]
  );

  if (inventoryResult.rows.length === 0 || parseInt(inventoryResult.rows[0].amount) < amount) {
    throw new Error(`Insufficient ${itemType} balance. Need ${amount} ${itemId}.`);
  }

  // Start transaction
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Lock items in inventory (deduct from available amount)
    await client.query(
      `UPDATE player_inventory
       SET amount = amount - $1,
           updated_at = NOW()
       WHERE player_wallet = $2 AND item_type = $3 AND item_id = $4`,
      [amount, sellerWallet, itemType, itemId]
    );

    // Create listing
    const result = await client.query(
      `INSERT INTO marketplace_listings
       (seller_wallet, item_type, item_id, amount, price_per_unit, total_price, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'active')
       RETURNING *`,
      [sellerWallet, itemType, itemId, amount, pricePerUnitLamports, totalPriceLamports]
    );

    await client.query('COMMIT');

    logger.info(
      `📦 Listed ${amount} ${itemId} (${itemType}) for ${pricePerUnit} alSOL each by ${sellerWallet}`
    );

    const listing = result.rows[0];
    return {
      id: listing.id,
      seller_wallet: listing.seller_wallet,
      item_type: listing.item_type,
      item_id: listing.item_id,
      amount: listing.amount,
      price_per_unit: parseInt(listing.price_per_unit) / 1_000_000_000,
      total_price: parseInt(listing.total_price) / 1_000_000_000,
      created_at: listing.created_at,
      status: listing.status,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Get all active marketplace listings
 */
export async function getMarketplaceListings(
  itemType?: 'element' | 'compound',
  limit: number = 100,
  offset: number = 0
): Promise<MarketplaceListing[]> {
  const result = await pool.query(
    `SELECT * FROM get_marketplace_listings($1, $2, $3)`,
    [itemType || null, limit, offset]
  );

  return result.rows.map((row) => ({
    id: row.listing_id,
    seller_wallet: row.seller_wallet,
    item_type: row.item_type,
    item_id: row.item_id,
    item_name: row.item_name,
    amount: row.amount,
    price_per_unit: parseInt(row.price_per_unit) / 1_000_000_000,
    total_price: parseInt(row.total_price) / 1_000_000_000,
    created_at: row.created_at,
    status: 'active',
  }));
}

/**
 * Buy an item from marketplace listing
 */
export async function buyMarketplaceListing(
  buyerWallet: string,
  listingId: number
): Promise<MarketplaceTransaction> {
  const MARKETPLACE_FEE_PERCENT = 0.025; // 2.5%

  // Get listing details
  const listingResult = await pool.query(
    `SELECT * FROM marketplace_listings WHERE id = $1 AND status = 'active'`,
    [listingId]
  );

  if (listingResult.rows.length === 0) {
    throw new Error(`Listing ${listingId} not found or no longer active`);
  }

  const listing = listingResult.rows[0];

  // Prevent buying your own listing
  if (listing.seller_wallet === buyerWallet) {
    throw new Error('Cannot buy your own listing');
  }

  const totalPriceLamports = parseInt(listing.total_price);
  const marketplaceFee = Math.floor(totalPriceLamports * MARKETPLACE_FEE_PERCENT);
  const sellerReceives = totalPriceLamports - marketplaceFee;

  // Check buyer's alSOL balance
  const balanceResult = await pool.query(
    `SELECT alsol_balance FROM player_balances WHERE player_id = $1`,
    [buyerWallet]
  );

  const buyerBalance =
    balanceResult.rows.length > 0 ? parseInt(balanceResult.rows[0].alsol_balance) : 0;

  if (buyerBalance < totalPriceLamports) {
    const needed = totalPriceLamports / 1_000_000_000;
    const has = buyerBalance / 1_000_000_000;
    throw new Error(`Insufficient alSOL. Need ${needed} alSOL, have ${has} alSOL.`);
  }

  // Start transaction
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Deduct alSOL from buyer
    await client.query(
      `UPDATE player_balances
       SET alsol_balance = alsol_balance - $1
       WHERE player_id = $2`,
      [totalPriceLamports, buyerWallet]
    );

    // Credit seller (minus marketplace fee)
    await client.query(
      `INSERT INTO player_balances (player_id, alsol_balance)
       VALUES ($1, $2)
       ON CONFLICT (player_id)
       DO UPDATE SET alsol_balance = player_balances.alsol_balance + $2`,
      [listing.seller_wallet, sellerReceives]
    );

    // Transfer items to buyer
    await client.query(
      `INSERT INTO player_inventory (player_wallet, item_type, item_id, amount)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (player_wallet, item_type, item_id)
       DO UPDATE SET amount = player_inventory.amount + $4, updated_at = NOW()`,
      [buyerWallet, listing.item_type, listing.item_id, listing.amount]
    );

    // Mark listing as sold
    await client.query(
      `UPDATE marketplace_listings
       SET status = 'sold', sold_at = NOW(), buyer_wallet = $1, updated_at = NOW()
       WHERE id = $2`,
      [buyerWallet, listingId]
    );

    // Record transaction
    const txResult = await client.query(
      `INSERT INTO marketplace_transactions
       (listing_id, seller_wallet, buyer_wallet, item_type, item_id, amount, price_paid, marketplace_fee, seller_received)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        listingId,
        listing.seller_wallet,
        buyerWallet,
        listing.item_type,
        listing.item_id,
        listing.amount,
        totalPriceLamports,
        marketplaceFee,
        sellerReceives,
      ]
    );

    await client.query('COMMIT');

    logger.info(
      `💰 ${buyerWallet} bought ${listing.amount} ${listing.item_id} from ${listing.seller_wallet} for ${totalPriceLamports / 1_000_000_000} alSOL`
    );

    const tx = txResult.rows[0];
    return {
      id: tx.id,
      listing_id: tx.listing_id,
      seller_wallet: tx.seller_wallet,
      buyer_wallet: tx.buyer_wallet,
      item_type: tx.item_type,
      item_id: tx.item_id,
      amount: tx.amount,
      price_paid: parseInt(tx.price_paid) / 1_000_000_000,
      marketplace_fee: parseInt(tx.marketplace_fee) / 1_000_000_000,
      seller_received: parseInt(tx.seller_received) / 1_000_000_000,
      transaction_date: tx.transaction_date,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Cancel a marketplace listing
 */
export async function cancelMarketplaceListing(
  sellerWallet: string,
  listingId: number
): Promise<void> {
  // Get listing
  const listingResult = await pool.query(
    `SELECT * FROM marketplace_listings WHERE id = $1 AND status = 'active'`,
    [listingId]
  );

  if (listingResult.rows.length === 0) {
    throw new Error(`Listing ${listingId} not found or no longer active`);
  }

  const listing = listingResult.rows[0];

  // Verify ownership
  if (listing.seller_wallet !== sellerWallet) {
    throw new Error('You can only cancel your own listings');
  }

  // Start transaction
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Return items to seller's inventory
    await client.query(
      `UPDATE player_inventory
       SET amount = amount + $1, updated_at = NOW()
       WHERE player_wallet = $2 AND item_type = $3 AND item_id = $4`,
      [listing.amount, sellerWallet, listing.item_type, listing.item_id]
    );

    // Mark listing as cancelled
    await client.query(
      `UPDATE marketplace_listings
       SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1`,
      [listingId]
    );

    await client.query('COMMIT');

    logger.info(`❌ Cancelled listing ${listingId} by ${sellerWallet}`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Get player's active listings
 */
export async function getPlayerListings(playerWallet: string): Promise<MarketplaceListing[]> {
  const result = await pool.query(
    `SELECT
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
      ml.created_at,
      ml.status
    FROM marketplace_listings ml
    LEFT JOIN elements e ON ml.item_type = 'element' AND ml.item_id = e.id
    LEFT JOIN compounds c ON ml.item_type = 'compound' AND ml.item_id = c.id
    WHERE ml.seller_wallet = $1 AND ml.status = 'active'
    ORDER BY ml.created_at DESC`,
    [playerWallet]
  );

  return result.rows.map((row) => ({
    id: row.id,
    seller_wallet: row.seller_wallet,
    item_type: row.item_type,
    item_id: row.item_id,
    item_name: row.item_name,
    amount: row.amount,
    price_per_unit: parseInt(row.price_per_unit) / 1_000_000_000,
    total_price: parseInt(row.total_price) / 1_000_000_000,
    created_at: row.created_at,
    status: row.status,
  }));
}

/**
 * Get player's marketplace transaction history
 */
export async function getPlayerTransactionHistory(
  playerWallet: string,
  limit: number = 50
): Promise<MarketplaceTransaction[]> {
  const result = await pool.query(
    `SELECT * FROM marketplace_transactions
     WHERE seller_wallet = $1 OR buyer_wallet = $1
     ORDER BY transaction_date DESC
     LIMIT $2`,
    [playerWallet, limit]
  );

  return result.rows.map((row) => ({
    id: row.id,
    listing_id: row.listing_id,
    seller_wallet: row.seller_wallet,
    buyer_wallet: row.buyer_wallet,
    item_type: row.item_type,
    item_id: row.item_id,
    amount: row.amount,
    price_paid: parseInt(row.price_paid) / 1_000_000_000,
    marketplace_fee: parseInt(row.marketplace_fee) / 1_000_000_000,
    seller_received: parseInt(row.seller_received) / 1_000_000_000,
    transaction_date: row.transaction_date,
  }));
}

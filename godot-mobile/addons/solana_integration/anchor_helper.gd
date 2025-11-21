extends Node
## Anchor Program Helper - Build transactions for LenKinVerse Anchor programs

# Program IDs (replace with actual deployed addresses)
const MARKETPLACE_PROGRAM_ID = "MKTPLCExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
const ELEMENT_NFT_PROGRAM_ID = "ELEMENTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
const REGISTRY_PROGRAM_ID = "REGISTRYxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# SPL Token Program ID
const TOKEN_PROGRAM_ID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"

# System Program ID
const SYSTEM_PROGRAM_ID = "11111111111111111111111111111111"

# Associated Token Program ID
const ASSOCIATED_TOKEN_PROGRAM_ID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"

## === MARKETPLACE PROGRAM ===

## Build swap_sol_for_alsol instruction
func build_swap_sol_for_alsol(
	user_pubkey: String,
	sol_amount_lamports: int,
	alsol_mint: String,
	marketplace_authority: String
) -> Dictionary:
	"""
	Swap SOL for alSOL at 1:1 ratio
	"""
	var instruction_data = _serialize_instruction("swap_sol_for_alsol", {
		"amount": sol_amount_lamports
	})

	return {
		"program_id": MARKETPLACE_PROGRAM_ID,
		"accounts": [
			{"pubkey": user_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": _get_associated_token_address(user_pubkey, alsol_mint), "is_signer": false, "is_writable": true},
			{"pubkey": alsol_mint, "is_signer": false, "is_writable": true},
			{"pubkey": marketplace_authority, "is_signer": false, "is_writable": false},
			{"pubkey": SYSTEM_PROGRAM_ID, "is_signer": false, "is_writable": false},
			{"pubkey": TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
		],
		"data": instruction_data
	}

## Build swap_lkc_for_alsol instruction
func build_swap_lkc_for_alsol(
	user_pubkey: String,
	lkc_amount: int,
	lkc_mint: String,
	alsol_mint: String,
	swap_history_pda: String,
	marketplace_authority: String
) -> Dictionary:
	"""
	Swap LKC for alSOL with weekly limit enforcement
	"""
	var instruction_data = _serialize_instruction("swap_lkc_for_alsol", {
		"lkc_amount": lkc_amount
	})

	return {
		"program_id": MARKETPLACE_PROGRAM_ID,
		"accounts": [
			{"pubkey": user_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": _get_associated_token_address(user_pubkey, lkc_mint), "is_signer": false, "is_writable": true},
			{"pubkey": _get_associated_token_address(user_pubkey, alsol_mint), "is_signer": false, "is_writable": true},
			{"pubkey": lkc_mint, "is_signer": false, "is_writable": true},
			{"pubkey": alsol_mint, "is_signer": false, "is_writable": true},
			{"pubkey": swap_history_pda, "is_signer": false, "is_writable": true},
			{"pubkey": marketplace_authority, "is_signer": false, "is_writable": false},
			{"pubkey": SYSTEM_PROGRAM_ID, "is_signer": false, "is_writable": false},
			{"pubkey": TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
		],
		"data": instruction_data
	}

## Build create_listing instruction
func build_create_listing(
	seller_pubkey: String,
	element_nft_mint: String,
	price_lamports: int,
	listing_pda: String
) -> Dictionary:
	"""
	Create marketplace listing for element NFT
	"""
	var instruction_data = _serialize_instruction("create_listing", {
		"price": price_lamports,
		"amount": 1
	})

	return {
		"program_id": MARKETPLACE_PROGRAM_ID,
		"accounts": [
			{"pubkey": seller_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": element_nft_mint, "is_signer": false, "is_writable": false},
			{"pubkey": _get_associated_token_address(seller_pubkey, element_nft_mint), "is_signer": false, "is_writable": true},
			{"pubkey": listing_pda, "is_signer": false, "is_writable": true},
			{"pubkey": SYSTEM_PROGRAM_ID, "is_signer": false, "is_writable": false},
			{"pubkey": TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
		],
		"data": instruction_data
	}

## Build buy_listing instruction
func build_buy_listing(
	buyer_pubkey: String,
	seller_pubkey: String,
	element_nft_mint: String,
	listing_pda: String,
	alsol_mint: String,
	marketplace_authority: String
) -> Dictionary:
	"""
	Purchase element NFT from marketplace
	"""
	var instruction_data = _serialize_instruction("buy_listing", {})

	return {
		"program_id": MARKETPLACE_PROGRAM_ID,
		"accounts": [
			{"pubkey": buyer_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": seller_pubkey, "is_signer": false, "is_writable": true},
			{"pubkey": element_nft_mint, "is_signer": false, "is_writable": false},
			{"pubkey": _get_associated_token_address(buyer_pubkey, element_nft_mint), "is_signer": false, "is_writable": true},
			{"pubkey": _get_associated_token_address(seller_pubkey, element_nft_mint), "is_signer": false, "is_writable": true},
			{"pubkey": _get_associated_token_address(buyer_pubkey, alsol_mint), "is_signer": false, "is_writable": true},
			{"pubkey": _get_associated_token_address(seller_pubkey, alsol_mint), "is_signer": false, "is_writable": true},
			{"pubkey": listing_pda, "is_signer": false, "is_writable": true},
			{"pubkey": marketplace_authority, "is_signer": false, "is_writable": false},
			{"pubkey": TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
		],
		"data": instruction_data
	}

## === ELEMENT NFT PROGRAM ===

## Build mint_element instruction
func build_mint_element(
	owner_pubkey: String,
	mint_pubkey: String,
	element_account_pda: String,
	metadata_account: String,
	element_data: Dictionary
) -> Dictionary:
	"""
	Mint element NFT

	element_data structure:
	{
		"element_id": "lkC",
		"element_name": "Lennard-Kinsium Carbon",
		"symbol": "lkC",
		"rarity": 0,  # 0=Common, 1=Uncommon, 2=Rare, 3=Legendary
		"amount": 10,
		"generation_method": "walk_mining",
		"decay_time": null,  # Optional for isotopes
		"volume": null  # Optional for isotopes (0.0-1.0)
	}
	"""
	var instruction_data = _serialize_instruction("mint_element", element_data)

	return {
		"program_id": ELEMENT_NFT_PROGRAM_ID,
		"accounts": [
			{"pubkey": owner_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": mint_pubkey, "is_signer": true, "is_writable": true},
			{"pubkey": _get_associated_token_address(owner_pubkey, mint_pubkey), "is_signer": false, "is_writable": true},
			{"pubkey": element_account_pda, "is_signer": false, "is_writable": true},
			{"pubkey": metadata_account, "is_signer": false, "is_writable": true},
			{"pubkey": SYSTEM_PROGRAM_ID, "is_signer": false, "is_writable": false},
			{"pubkey": TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
			{"pubkey": ASSOCIATED_TOKEN_PROGRAM_ID, "is_signer": false, "is_writable": false},
		],
		"data": instruction_data
	}

## Build update_amount instruction
func build_update_amount(
	owner_pubkey: String,
	element_account_pda: String,
	new_amount: int
) -> Dictionary:
	"""
	Update element amount
	"""
	var instruction_data = _serialize_instruction("update_amount", {
		"new_amount": new_amount
	})

	return {
		"program_id": ELEMENT_NFT_PROGRAM_ID,
		"accounts": [
			{"pubkey": owner_pubkey, "is_signer": true, "is_writable": false},
			{"pubkey": element_account_pda, "is_signer": false, "is_writable": true},
		],
		"data": instruction_data
	}

## Build update_volume instruction (for isotopes)
func build_update_volume(
	owner_pubkey: String,
	element_account_pda: String,
	new_volume: float
) -> Dictionary:
	"""
	Update isotope volume (0.0-1.0)
	"""
	var instruction_data = _serialize_instruction("update_volume", {
		"new_volume": new_volume
	})

	return {
		"program_id": ELEMENT_NFT_PROGRAM_ID,
		"accounts": [
			{"pubkey": owner_pubkey, "is_signer": true, "is_writable": false},
			{"pubkey": element_account_pda, "is_signer": false, "is_writable": true},
		],
		"data": instruction_data
	}

## === HELPER FUNCTIONS ===

## Derive PDA for swap history
func derive_swap_history_pda(user_pubkey: String, program_id: String = MARKETPLACE_PROGRAM_ID) -> String:
	# In real implementation, use proper PDA derivation
	# For now, return placeholder
	return "SwapHistoryPDA_" + user_pubkey.substr(0, 8)

## Derive PDA for element account
func derive_element_account_pda(mint_pubkey: String, program_id: String = ELEMENT_NFT_PROGRAM_ID) -> String:
	# In real implementation, use proper PDA derivation with seeds ["element", mint]
	return "ElementAccountPDA_" + mint_pubkey.substr(0, 8)

## Derive PDA for listing
func derive_listing_pda(mint_pubkey: String, program_id: String = MARKETPLACE_PROGRAM_ID) -> String:
	# In real implementation, use proper PDA derivation with seeds ["listing", mint]
	return "ListingPDA_" + mint_pubkey.substr(0, 8)

## Get associated token address
func _get_associated_token_address(owner: String, mint: String) -> String:
	# In real implementation, derive ATA properly using owner + mint + ATA program
	# For now, return placeholder
	return "ATA_" + owner.substr(0, 4) + "_" + mint.substr(0, 4)

## Serialize Anchor instruction
func _serialize_instruction(instruction_name: String, params: Dictionary) -> String:
	"""
	Serialize Anchor instruction to base64

	Anchor instruction format:
	- First 8 bytes: discriminator (SHA256 hash of "global:instruction_name")
	- Remaining bytes: Borsh-serialized parameters
	"""
	# Calculate discriminator
	var discriminator = _calculate_anchor_discriminator(instruction_name)

	# Serialize parameters using Borsh format
	var serialized_params = _borsh_serialize(params)

	# Combine discriminator + params
	var instruction_bytes = discriminator + serialized_params

	# Return base64
	return Marshalls.raw_to_base64(instruction_bytes)

## Calculate Anchor discriminator (first 8 bytes of SHA256)
func _calculate_anchor_discriminator(instruction_name: String) -> PackedByteArray:
	var preimage = "global:" + instruction_name
	var hash = preimage.sha256_text()

	# Take first 8 bytes (16 hex chars)
	var discriminator = PackedByteArray()
	for i in range(8):
		var hex_byte = hash.substr(i * 2, 2)
		discriminator.append(hex_byte.hex_to_int())

	return discriminator

## Borsh serialize parameters
func _borsh_serialize(params: Dictionary) -> PackedByteArray:
	"""
	Simplified Borsh serialization

	Real implementation should use proper Borsh serialization library
	For now, this is a placeholder that handles basic types
	"""
	var buffer = PackedByteArray()

	for key in params.keys():
		var value = params[key]

		if value is int:
			# u64 (8 bytes, little endian)
			for i in range(8):
				buffer.append((value >> (i * 8)) & 0xFF)

		elif value is float:
			# f32 (4 bytes)
			var bytes = var_to_bytes(value)
			buffer.append_array(bytes.slice(0, 4))

		elif value is String:
			# String: length (u32) + UTF-8 bytes
			var string_bytes = value.to_utf8_buffer()
			var length = string_bytes.size()

			# Length as u32 (4 bytes, little endian)
			for i in range(4):
				buffer.append((length >> (i * 8)) & 0xFF)

			# String data
			buffer.append_array(string_bytes)

		elif value is bool:
			# bool (1 byte)
			buffer.append(1 if value else 0)

		elif value == null:
			# Option::None (1 byte = 0)
			buffer.append(0)

	return buffer

## Create complete transaction
func create_transaction(
	instructions: Array,
	recent_blockhash: String,
	fee_payer: String
) -> Dictionary:
	"""
	Create complete Solana transaction
	"""
	return {
		"instructions": instructions,
		"recent_blockhash": recent_blockhash,
		"fee_payer": fee_payer
	}

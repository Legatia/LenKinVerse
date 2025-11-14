extends Node2D
## Solana Planet scene - room-based gameplay for Solana blockchain
##
## This scene is specifically for the Solana ecosystem and integrates with:
## - Solana smart contracts (marketplace, element-nft, registry)
## - Solana Mobile Wallet Adapter (via WalletManager)
## - alSOL token economy (1:1 SOL-backed in-game currency)
##
## Players can:
## - Collect raw materials through movement
## - Analyze materials with Alchemy Gloves
## - Perform reactions to create compounds
## - Mint discoveries as NFTs on Solana
## - Trade elements on decentralized marketplace
## - Swap SOL/LKC for alSOL currency
##
## Smart Contracts:
## - Marketplace: MKTPLCExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
## - Element NFT: ELeMNFTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
## - Registry: (TBD)
##
## See: SOLANA_PLANET_TODO.md for integration status

func _ready() -> void:
	# Show tutorial overlay if needed
	if TutorialManager.should_show_tutorial():
		call_deferred("show_tutorial")

func show_tutorial() -> void:
	var tutorial_scene = load("res://scenes/ui/tutorial_overlay.tscn")
	if tutorial_scene:
		var tutorial_instance = tutorial_scene.instantiate()
		get_tree().root.add_child(tutorial_instance)
	else:
		push_error("Failed to load tutorial overlay scene")

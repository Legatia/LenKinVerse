# Solana Mobile Wallet Adapter - GDExtension Plugin Specification

This document specifies the requirements for implementing a Solana Mobile Wallet Adapter plugin for Godot 4.4+ as a GDExtension.

## Overview

The Solana Mobile Wallet Adapter plugin enables LenKinVerse to connect to Solana mobile wallets (Phantom, Solflare, etc.) and perform blockchain operations directly from the Godot game engine.

## Plugin Architecture

### Technology Stack
- **Godot:** GDExtension (C++) with platform-specific implementations
- **iOS:** Swift with Solana Mobile Swift SDK
- **Android:** Kotlin/Java with Solana Mobile Android SDK

### Plugin Name
`SolanaWallet` (singleton accessible in GDScript)

## API Specification

### Signals

```gdscript
# Emitted when wallet connection succeeds
signal wallet_connected(address: String, public_key: String)

# Emitted when wallet connection fails
signal wallet_connection_failed(error: String)

# Emitted when transaction is signed
signal transaction_signed(signature: String)

# Emitted when transaction signing fails
signal transaction_failed(error: String)

# Emitted when disconnected
signal wallet_disconnected()
```

### Properties

```gdscript
# Current connection state
var is_connected: bool = false

# Wallet address (Base58)
var wallet_address: String = ""

# Public key (Base58)
var public_key: String = ""

# Network cluster (mainnet-beta, devnet, testnet)
var cluster: String = "mainnet-beta"
```

### Methods

#### authorize()
```gdscript
func authorize(config: Dictionary = {}) -> void
```

Opens the wallet selector and requests authorization.

**Parameters:**
- `config` (Dictionary, optional):
  - `cluster` (String): "mainnet-beta", "devnet", or "testnet"
  - `app_name` (String): Display name for the app
  - `app_icon` (String): URL or base64 icon

**Returns:** void (async via signals)

**Signals:**
- `wallet_connected(address, public_key)` on success
- `wallet_connection_failed(error)` on failure

**Example:**
```gdscript
SolanaWallet.authorize({
    "cluster": "mainnet-beta",
    "app_name": "LenKinVerse",
    "app_icon": "res://icon.png"
})
```

---

#### disconnect()
```gdscript
func disconnect() -> void
```

Disconnects from the currently connected wallet.

**Returns:** void

**Signals:**
- `wallet_disconnected()` when disconnected

---

#### sign_transaction()
```gdscript
func sign_transaction(transaction: Dictionary) -> void
```

Signs a Solana transaction.

**Parameters:**
- `transaction` (Dictionary):
  - `instructions` (Array): Array of transaction instructions
  - `recent_blockhash` (String): Recent blockhash
  - `fee_payer` (String, optional): Fee payer address

**Transaction Instruction Format:**
```gdscript
{
    "program_id": "11111111111111111111111111111111",  # Base58
    "accounts": [
        {"pubkey": "...", "is_signer": true, "is_writable": true},
        {"pubkey": "...", "is_signer": false, "is_writable": false}
    ],
    "data": "base64_encoded_data"
}
```

**Returns:** void (async via signals)

**Signals:**
- `transaction_signed(signature)` on success
- `transaction_failed(error)` on failure

---

#### sign_message()
```gdscript
func sign_message(message: String) -> void
```

Signs an arbitrary message for verification.

**Parameters:**
- `message` (String): Message to sign

**Returns:** void (async via signals)

**Signals:**
- `transaction_signed(signature)` on success (signature is base64)
- `transaction_failed(error)` on failure

---

#### get_balance()
```gdscript
func get_balance(address: String = "") -> float
```

Gets SOL balance for an address.

**Parameters:**
- `address` (String, optional): Address to check (defaults to connected wallet)

**Returns:** float (balance in SOL, async)

**Note:** This method should be async. Consider using a callback or signal.

---

#### send_transaction()
```gdscript
func send_transaction(signed_transaction: String) -> void
```

Broadcasts a signed transaction to the network.

**Parameters:**
- `signed_transaction` (String): Base64-encoded signed transaction

**Returns:** void (async via signals)

**Signals:**
- `transaction_signed(signature)` on confirmation
- `transaction_failed(error)` on failure

---

## Platform Implementation Details

### iOS Implementation

**Requirements:**
- Xcode 14+
- iOS 14.0+
- Swift 5.7+
- Solana Mobile Swift SDK

**Dependencies:**
```swift
dependencies: [
    .package(url: "https://github.com/solana-mobile/mobile-wallet-adapter-swift.git", from: "1.0.0")
]
```

**Key Classes:**
- `MobileWalletAdapter`: Main adapter class
- `SolanaWalletPlugin`: GDExtension bridge class

**Files to Create:**
```
ios/
├── SolanaWalletPlugin.swift
├── SolanaWalletBridge.h
├── SolanaWalletBridge.mm (Objective-C++ bridge)
└── Info.plist (with URL scheme configuration)
```

**URL Scheme Configuration:**
Add to Info.plist:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>solana-wallet</string>
</array>
```

---

### Android Implementation

**Requirements:**
- Android Studio Arctic Fox+
- Android API 23+ (Android 6.0)
- Kotlin 1.7+
- Solana Mobile Android SDK

**Dependencies (build.gradle):**
```gradle
dependencies {
    implementation 'com.solanamobile:mobile-wallet-adapter-clientlib-ktx:1.0.0'
}
```

**Key Classes:**
- `MobileWalletAdapter`: Main adapter class
- `SolanaWalletPlugin`: GDExtension JNI bridge class

**Files to Create:**
```
android/
├── src/
│   └── com/
│       └── lenkinverse/
│           └── solana/
│               ├── SolanaWalletPlugin.kt
│               └── SolanaWalletJNI.cpp
└── AndroidManifest.xml
```

**Manifest Permissions:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

---

## GDExtension Setup

### Plugin Structure
```
addons/
└── solana_wallet/
    ├── bin/
    │   ├── libsolana_wallet.ios.debug.framework
    │   ├── libsolana_wallet.ios.release.framework
    │   ├── libsolana_wallet.android.debug.so
    │   └── libsolana_wallet.android.release.so
    ├── solana_wallet.gdextension
    └── plugin.cfg
```

### solana_wallet.gdextension
```ini
[configuration]
entry_symbol = "solana_wallet_init"
compatibility_minimum = 4.4

[libraries]
ios.debug = "res://addons/solana_wallet/bin/libsolana_wallet.ios.debug.framework"
ios.release = "res://addons/solana_wallet/bin/libsolana_wallet.ios.release.framework"
android.debug = "res://addons/solana_wallet/bin/libsolana_wallet.android.debug.so"
android.release = "res://addons/solana_wallet/bin/libsolana_wallet.android.release.so"
```

### plugin.cfg
```ini
[plugin]
name="Solana Wallet"
description="Solana Mobile Wallet Adapter for Godot"
author="LenKinVerse Team"
version="1.0.0"
script="solana_wallet_plugin.gd"
```

---

## Usage Example

```gdscript
extends Node

func _ready():
    # Connect signals
    SolanaWallet.wallet_connected.connect(_on_wallet_connected)
    SolanaWallet.wallet_connection_failed.connect(_on_connection_failed)
    SolanaWallet.transaction_signed.connect(_on_transaction_signed)
    SolanaWallet.transaction_failed.connect(_on_transaction_failed)

func connect_wallet():
    SolanaWallet.authorize({
        "cluster": "mainnet-beta",
        "app_name": "LenKinVerse",
        "app_icon": "res://icon.png"
    })

func _on_wallet_connected(address: String, public_key: String):
    print("Connected: ", address)
    print("Public Key: ", public_key)

func _on_connection_failed(error: String):
    print("Connection failed: ", error)

func send_sol(to_address: String, amount_lamports: int):
    var transaction = {
        "instructions": [
            {
                "program_id": "11111111111111111111111111111111",
                "accounts": [
                    {
                        "pubkey": SolanaWallet.wallet_address,
                        "is_signer": true,
                        "is_writable": true
                    },
                    {
                        "pubkey": to_address,
                        "is_signer": false,
                        "is_writable": true
                    }
                ],
                "data": encode_transfer(amount_lamports)
            }
        ],
        "recent_blockhash": await get_recent_blockhash()
    }

    SolanaWallet.sign_transaction(transaction)

func _on_transaction_signed(signature: String):
    print("Transaction signature: ", signature)

func _on_transaction_failed(error: String):
    print("Transaction failed: ", error)
```

---

## Testing

### Test Cases

1. **Connection Test**
   - Authorize wallet successfully
   - Handle authorization cancellation
   - Reconnect after disconnection

2. **Transaction Test**
   - Sign simple transfer
   - Sign complex transaction with multiple instructions
   - Handle transaction rejection

3. **Message Signing Test**
   - Sign arbitrary message
   - Verify signature

4. **Network Test**
   - Connect to mainnet-beta
   - Connect to devnet
   - Switch networks

### Mock Implementation

For development without native plugins, WalletManager currently provides a mock implementation. The native plugin should be drop-in compatible with the existing mock interface.

---

## Security Considerations

1. **Never store private keys** - Always use wallet apps for signing
2. **Validate all inputs** - Sanitize addresses and transaction data
3. **Use HTTPS** - All RPC calls must use secure connections
4. **Rate limiting** - Implement request throttling
5. **Error handling** - Never expose sensitive error details to UI

---

## References

- [Solana Mobile Developer Docs](https://docs.solanamobile.com/)
- [Solana Mobile Swift SDK](https://github.com/solana-mobile/mobile-wallet-adapter-swift)
- [Solana Mobile Android SDK](https://github.com/solana-mobile/mobile-wallet-adapter)
- [Godot GDExtension Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)
- [Solana RPC API](https://docs.solana.com/api/http)

---

## Support

For questions or issues:
- GitHub Issues: [repository]/issues
- Discord: [server link]
- Email: dev@lenkinverse.com

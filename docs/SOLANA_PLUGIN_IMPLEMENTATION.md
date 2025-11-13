# Solana Plugin Implementation Guide

Step-by-step guide for implementing the Solana Mobile Wallet Adapter GDExtension plugin.

## Prerequisites

### Development Environment
- **Godot 4.4+** source code
- **CMake 3.22+**
- **iOS:** Xcode 14+, macOS
- **Android:** Android Studio, NDK r25+

### Knowledge Required
- C++ for GDExtension core
- Swift for iOS implementation
- Kotlin/Java for Android implementation
- Solana blockchain basics

---

## Phase 1: GDExtension Core Setup

### Step 1: Create Plugin Directory Structure

```bash
mkdir -p addons/solana_wallet/src
mkdir -p addons/solana_wallet/bin
mkdir -p addons/solana_wallet/ios
mkdir -p addons/solana_wallet/android
```

### Step 2: Create Base GDExtension Class

**File: `addons/solana_wallet/src/solana_wallet.h`**

```cpp
#ifndef SOLANA_WALLET_H
#define SOLANA_WALLET_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class SolanaWallet : public Node {
    GDCLASS(SolanaWallet, Node)

private:
    bool is_connected;
    String wallet_address;
    String public_key;
    String cluster;

protected:
    static void _bind_methods();

public:
    SolanaWallet();
    ~SolanaWallet();

    // Signals
    void emit_wallet_connected(const String &address, const String &pub_key);
    void emit_wallet_connection_failed(const String &error);
    void emit_transaction_signed(const String &signature);
    void emit_transaction_failed(const String &error);
    void emit_wallet_disconnected();

    // Methods
    void authorize(const Dictionary &config);
    void disconnect();
    void sign_transaction(const Dictionary &transaction);
    void sign_message(const String &message);
    double get_balance(const String &address);
    void send_transaction(const String &signed_transaction);

    // Getters
    bool get_is_connected() const { return is_connected; }
    String get_wallet_address() const { return wallet_address; }
    String get_public_key() const { return public_key; }
    String get_cluster() const { return cluster; }

    // Platform-specific implementations (defined in platform files)
    void platform_authorize(const Dictionary &config);
    void platform_disconnect();
    void platform_sign_transaction(const Dictionary &transaction);
    void platform_sign_message(const String &message);
    double platform_get_balance(const String &address);
    void platform_send_transaction(const String &signed_transaction);
};

#endif // SOLANA_WALLET_H
```

**File: `addons/solana_wallet/src/solana_wallet.cpp`**

```cpp
#include "solana_wallet.h"

SolanaWallet::SolanaWallet() {
    is_connected = false;
    cluster = "mainnet-beta";
}

SolanaWallet::~SolanaWallet() {
}

void SolanaWallet::_bind_methods() {
    // Bind signals
    ADD_SIGNAL(MethodInfo("wallet_connected",
        PropertyInfo(Variant::STRING, "address"),
        PropertyInfo(Variant::STRING, "public_key")));
    ADD_SIGNAL(MethodInfo("wallet_connection_failed",
        PropertyInfo(Variant::STRING, "error")));
    ADD_SIGNAL(MethodInfo("transaction_signed",
        PropertyInfo(Variant::STRING, "signature")));
    ADD_SIGNAL(MethodInfo("transaction_failed",
        PropertyInfo(Variant::STRING, "error")));
    ADD_SIGNAL(MethodInfo("wallet_disconnected"));

    // Bind methods
    ClassDB::bind_method(D_METHOD("authorize", "config"), &SolanaWallet::authorize, DEFVAL(Dictionary()));
    ClassDB::bind_method(D_METHOD("disconnect"), &SolanaWallet::disconnect);
    ClassDB::bind_method(D_METHOD("sign_transaction", "transaction"), &SolanaWallet::sign_transaction);
    ClassDB::bind_method(D_METHOD("sign_message", "message"), &SolanaWallet::sign_message);
    ClassDB::bind_method(D_METHOD("get_balance", "address"), &SolanaWallet::get_balance, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("send_transaction", "signed_transaction"), &SolanaWallet::send_transaction);

    // Bind properties
    ClassDB::bind_method(D_METHOD("get_is_connected"), &SolanaWallet::get_is_connected);
    ClassDB::bind_method(D_METHOD("get_wallet_address"), &SolanaWallet::get_wallet_address);
    ClassDB::bind_method(D_METHOD("get_public_key"), &SolanaWallet::get_public_key);
    ClassDB::bind_method(D_METHOD("get_cluster"), &SolanaWallet::get_cluster);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_connected"), "", "get_is_connected");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "wallet_address"), "", "get_wallet_address");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "public_key"), "", "get_public_key");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "cluster"), "", "get_cluster");
}

// Signal emitters
void SolanaWallet::emit_wallet_connected(const String &address, const String &pub_key) {
    is_connected = true;
    wallet_address = address;
    public_key = pub_key;
    emit_signal("wallet_connected", address, pub_key);
}

void SolanaWallet::emit_wallet_connection_failed(const String &error) {
    emit_signal("wallet_connection_failed", error);
}

void SolanaWallet::emit_transaction_signed(const String &signature) {
    emit_signal("transaction_signed", signature);
}

void SolanaWallet::emit_transaction_failed(const String &error) {
    emit_signal("transaction_failed", error);
}

void SolanaWallet::emit_wallet_disconnected() {
    is_connected = false;
    wallet_address = "";
    public_key = "";
    emit_signal("wallet_disconnected");
}

// Public API methods (delegate to platform implementations)
void SolanaWallet::authorize(const Dictionary &config) {
    platform_authorize(config);
}

void SolanaWallet::disconnect() {
    platform_disconnect();
}

void SolanaWallet::sign_transaction(const Dictionary &transaction) {
    platform_sign_transaction(transaction);
}

void SolanaWallet::sign_message(const String &message) {
    platform_sign_message(message);
}

double SolanaWallet::get_balance(const String &address) {
    return platform_get_balance(address);
}

void SolanaWallet::send_transaction(const String &signed_transaction) {
    platform_send_transaction(signed_transaction);
}
```

### Step 3: Create GDExtension Entry Point

**File: `addons/solana_wallet/src/register_types.cpp`**

```cpp
#include "register_types.h"
#include "solana_wallet.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_solana_wallet_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<SolanaWallet>();
    Engine::get_singleton()->register_singleton("SolanaWallet", memnew(SolanaWallet));
}

void uninitialize_solana_wallet_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    Engine::get_singleton()->unregister_singleton("SolanaWallet");
}

extern "C" {
    GDExtensionBool GDE_EXPORT solana_wallet_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_solana_wallet_module);
        init_obj.register_terminator(uninitialize_solana_wallet_module);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}
```

---

## Phase 2: iOS Implementation

### Step 4: Setup Swift Bridge

**File: `addons/solana_wallet/ios/SolanaWalletPlugin.swift`**

```swift
import Foundation
import MobileWalletAdapter

@objc public class SolanaWalletPlugin: NSObject {
    private var walletAdapter: MobileWalletAdapter?
    private var connectedAddress: String?
    private var connectedPublicKey: String?

    @objc public static let shared = SolanaWalletPlugin()

    private override init() {
        super.init()
    }

    @objc public func authorize(config: [String: Any], callback: @escaping (Bool, String?, String?, String?) -> Void) {
        let cluster = config["cluster"] as? String ?? "mainnet-beta"
        let appName = config["app_name"] as? String ?? "LenKinVerse"

        let adapter = MobileWalletAdapter(
            identityUri: URL(string: "https://lenkinverse.com")!,
            iconUri: URL(string: "https://lenkinverse.com/icon.png")!,
            identityName: appName,
            cluster: .init(cluster)
        )

        self.walletAdapter = adapter

        adapter.authorize { result in
            switch result {
            case .success(let authorization):
                self.connectedAddress = authorization.address
                self.connectedPublicKey = authorization.publicKey.base58EncodedString
                callback(true, authorization.address, authorization.publicKey.base58EncodedString, nil)

            case .failure(let error):
                callback(false, nil, nil, error.localizedDescription)
            }
        }
    }

    @objc public func disconnect() {
        walletAdapter?.disconnect()
        connectedAddress = nil
        connectedPublicKey = nil
    }

    @objc public func signTransaction(transaction: [String: Any], callback: @escaping (Bool, String?, String?) -> Void) {
        guard let adapter = walletAdapter else {
            callback(false, nil, "Not connected to wallet")
            return
        }

        // Convert Dictionary to Solana transaction
        guard let serializedTx = serializeTransaction(transaction) else {
            callback(false, nil, "Invalid transaction format")
            return
        }

        adapter.signTransactions(transactions: [serializedTx]) { result in
            switch result {
            case .success(let signedTransactions):
                if let firstSignature = signedTransactions.first {
                    callback(true, firstSignature.base64EncodedString(), nil)
                } else {
                    callback(false, nil, "No signature returned")
                }

            case .failure(let error):
                callback(false, nil, error.localizedDescription)
            }
        }
    }

    @objc public func signMessage(message: String, callback: @escaping (Bool, String?, String?) -> Void) {
        guard let adapter = walletAdapter else {
            callback(false, nil, "Not connected to wallet")
            return
        }

        guard let messageData = message.data(using: .utf8) else {
            callback(false, nil, "Invalid message encoding")
            return
        }

        adapter.signMessages(messages: [messageData]) { result in
            switch result {
            case .success(let signedMessages):
                if let firstSignature = signedMessages.first {
                    callback(true, firstSignature.base64EncodedString(), nil)
                } else {
                    callback(false, nil, "No signature returned")
                }

            case .failure(let error):
                callback(false, nil, error.localizedDescription)
            }
        }
    }

    // Helper function to serialize transaction
    private func serializeTransaction(_ transaction: [String: Any]) -> Data? {
        // Implementation: Convert Dictionary to Solana Transaction
        // This requires parsing instructions and building the transaction
        return nil
    }
}
```

**File: `addons/solana_wallet/ios/SolanaWalletBridge.mm`**

```objc
#import "SolanaWalletBridge.h"
#import "SolanaWalletPlugin-Swift.h"
#include "../src/solana_wallet.h"

void solana_wallet_ios_authorize(SolanaWallet* instance, const Dictionary& config) {
    // Convert Godot Dictionary to NSDictionary
    NSMutableDictionary* configDict = [[NSMutableDictionary alloc] init];

    Array keys = config.keys();
    for (int i = 0; i < keys.size(); i++) {
        Variant key = keys[i];
        Variant value = config[key];

        NSString* keyStr = [NSString stringWithUTF8String:((String)key).utf8().get_data()];
        NSString* valueStr = [NSString stringWithUTF8String:((String)value).utf8().get_data()];

        [configDict setObject:valueStr forKey:keyStr];
    }

    [[SolanaWalletPlugin shared] authorizeWithConfig:configDict callback:^(BOOL success, NSString* address, NSString* publicKey, NSString* error) {
        if (success) {
            instance->call_deferred("emit_wallet_connected",
                String(address.UTF8String),
                String(publicKey.UTF8String));
        } else {
            instance->call_deferred("emit_wallet_connection_failed",
                String(error.UTF8String));
        }
    }];
}

// Implement other platform functions...
```

**File: `addons/solana_wallet/src/solana_wallet_ios.cpp`**

```cpp
#include "solana_wallet.h"

#if defined(__APPLE__) && TARGET_OS_IOS

// Forward declarations for Objective-C++ bridge
extern void solana_wallet_ios_authorize(SolanaWallet* instance, const Dictionary& config);
extern void solana_wallet_ios_disconnect();
extern void solana_wallet_ios_sign_transaction(SolanaWallet* instance, const Dictionary& transaction);
extern void solana_wallet_ios_sign_message(SolanaWallet* instance, const String& message);

void SolanaWallet::platform_authorize(const Dictionary &config) {
    solana_wallet_ios_authorize(this, config);
}

void SolanaWallet::platform_disconnect() {
    solana_wallet_ios_disconnect();
}

void SolanaWallet::platform_sign_transaction(const Dictionary &transaction) {
    solana_wallet_ios_sign_transaction(this, transaction);
}

void SolanaWallet::platform_sign_message(const String &message) {
    solana_wallet_ios_sign_message(this, message);
}

double SolanaWallet::platform_get_balance(const String &address) {
    // Make RPC call to get balance
    return 0.0;
}

void SolanaWallet::platform_send_transaction(const String &signed_transaction) {
    // Broadcast transaction to network
}

#endif
```

---

## Phase 3: Android Implementation

### Step 5: Setup Kotlin/Java Bridge

**File: `addons/solana_wallet/android/src/com/lenkinverse/solana/SolanaWalletPlugin.kt`**

```kotlin
package com.lenkinverse.solana

import android.content.Context
import android.net.Uri
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.protocol.MobileWalletAdapterClient

class SolanaWalletPlugin(private val context: Context) {

    private var walletAdapter: MobileWalletAdapter? = null
    private var connectedAddress: String? = null
    private var connectedPublicKey: String? = null

    fun authorize(
        config: Map<String, String>,
        callback: (success: Boolean, address: String?, publicKey: String?, error: String?) -> Unit
    ) {
        val cluster = config["cluster"] ?: "mainnet-beta"
        val appName = config["app_name"] ?: "LenKinVerse"

        val adapter = MobileWalletAdapter(
            identityUri = Uri.parse("https://lenkinverse.com"),
            iconUri = Uri.parse("https://lenkinverse.com/icon.png"),
            identityName = appName
        )

        walletAdapter = adapter

        adapter.authorize(
            onSuccess = { result ->
                connectedAddress = result.publicKey.toBase58()
                connectedPublicKey = result.publicKey.toBase58()
                callback(true, connectedAddress, connectedPublicKey, null)
            },
            onFailure = { error ->
                callback(false, null, null, error.message)
            }
        )
    }

    fun disconnect() {
        walletAdapter?.disconnect()
        connectedAddress = null
        connectedPublicKey = null
    }

    fun signTransaction(
        transaction: Map<String, Any>,
        callback: (success: Boolean, signature: String?, error: String?) -> Unit
    ) {
        val adapter = walletAdapter ?: run {
            callback(false, null, "Not connected to wallet")
            return
        }

        // Convert Map to Solana transaction
        val serializedTx = serializeTransaction(transaction) ?: run {
            callback(false, null, "Invalid transaction format")
            return
        }

        adapter.signTransactions(
            transactions = listOf(serializedTx),
            onSuccess = { signatures ->
                val signature = signatures.firstOrNull()?.toBase64()
                callback(true, signature, null)
            },
            onFailure = { error ->
                callback(false, null, error.message)
            }
        )
    }

    fun signMessage(
        message: String,
        callback: (success: Boolean, signature: String?, error: String?) -> Unit
    ) {
        val adapter = walletAdapter ?: run {
            callback(false, null, "Not connected to wallet")
            return
        }

        adapter.signMessages(
            messages = listOf(message.toByteArray()),
            onSuccess = { signatures ->
                val signature = signatures.firstOrNull()?.toBase64()
                callback(true, signature, null)
            },
            onFailure = { error ->
                callback(false, null, error.message)
            }
        )
    }

    private fun serializeTransaction(transaction: Map<String, Any>): ByteArray? {
        // Implementation: Convert Map to Solana Transaction
        return null
    }

    companion object {
        @JvmStatic
        private external fun nativeOnWalletConnected(address: String, publicKey: String)

        @JvmStatic
        private external fun nativeOnConnectionFailed(error: String)

        @JvmStatic
        private external fun nativeOnTransactionSigned(signature: String)

        @JvmStatic
        private external fun nativeOnTransactionFailed(error: String)
    }
}
```

**File: `addons/solana_wallet/android/jni/solana_wallet_jni.cpp`**

```cpp
#include <jni.h>
#include "../../src/solana_wallet.h"
#include <godot_cpp/variant/utility_functions.hpp>

static SolanaWallet* g_solana_wallet_instance = nullptr;

extern "C" {

JNIEXPORT void JNICALL
Java_com_lenkinverse_solana_SolanaWalletPlugin_nativeOnWalletConnected(
    JNIEnv* env,
    jclass clazz,
    jstring address,
    jstring public_key) {

    if (g_solana_wallet_instance) {
        const char* address_str = env->GetStringUTFChars(address, nullptr);
        const char* public_key_str = env->GetStringUTFChars(public_key, nullptr);

        g_solana_wallet_instance->call_deferred("emit_wallet_connected",
            String(address_str),
            String(public_key_str));

        env->ReleaseStringUTFChars(address, address_str);
        env->ReleaseStringUTFChars(public_key, public_key_str);
    }
}

JNIEXPORT void JNICALL
Java_com_lenkinverse_solana_SolanaWalletPlugin_nativeOnConnectionFailed(
    JNIEnv* env,
    jclass clazz,
    jstring error) {

    if (g_solana_wallet_instance) {
        const char* error_str = env->GetStringUTFChars(error, nullptr);

        g_solana_wallet_instance->call_deferred("emit_wallet_connection_failed",
            String(error_str));

        env->ReleaseStringUTFChars(error, error_str);
    }
}

// Implement other JNI callbacks...

}
```

---

## Phase 4: Build System

### Step 6: Create SConstruct

**File: `addons/solana_wallet/SConstruct`**

```python
#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# iOS-specific sources
if env["platform"] == "ios":
    sources += Glob("src/*_ios.cpp")
    sources += Glob("ios/*.mm")
    env.Append(LINKFLAGS=["-framework", "Foundation"])

# Android-specific sources
if env["platform"] == "android":
    sources += Glob("src/*_android.cpp")
    sources += Glob("android/jni/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/libsolana_wallet.{}.{}.framework/libsolana_wallet.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "bin/libsolana_wallet{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
```

---

## Testing

### Unit Tests

Create test suite in `addons/solana_wallet/test/`

### Integration Tests

Test with actual wallet apps on real devices.

---

## Documentation

Update `SOLANA_PLUGIN_SPEC.md` with any API changes during implementation.

---

## Deployment

1. Build for all platforms (iOS, Android)
2. Package as Godot plugin
3. Test with LenKinVerse game
4. Publish to Godot Asset Library (optional)

---

## Next Steps

After Solana plugin:
1. Implement HealthKit/Google Fit plugin
2. Backend API for marketplace
3. Production testing

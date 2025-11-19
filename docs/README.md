# 📚 LenKinVerse Documentation

Complete documentation for the LenKinVerse walk-to-earn mobile game.

---

## 🎮 Game Design

### Core Mechanics
- **[Elements & Reactions](ELEMENTS_AND_REACTIONS.md)** - Complete chemistry system guide
  - 10 elements across 4 rarity tiers
  - 4 reaction types (Physical, Chemical, Nuclear)
  - Discovery system & tax mechanics

- **[Element → NFT Flow](ELEMENT_TOKEN_FLOW.md)** - How in-game items become blockchain assets
  - Database vs blockchain philosophy
  - Bridging mechanism
  - Burn proof validation

---

## 📱 Mobile App

### Health Integration
- **[Health API Setup](health/HEALTH_API_SETUP.md)** - iOS HealthKit & Android Health Connect
  - Native plugin installation
  - Privacy compliance (iOS 18 / Android 15)
  - Permission handling
  - Testing guide

- **[Health → Game Data Formula](health/HEALTH_TO_GAME_DATA_FORMULA.md)** - Movement reward calculations
  - Steps + distance → chunks
  - Efficiency detection (anti-cheat)
  - Reward rates and balancing

- **[Health Plugin Summary](health/HEALTH_PLUGIN_SUMMARY.md)** - Quick reference
  - What was built
  - Platform compatibility
  - Integration status

### UI Customization
- **[UI Customization Guide](mobile/UI_CUSTOMIZATION_GUIDE.md)** - Update button icons and visual assets
  - AssetManager system
  - Icon sizing best practices
  - Scene editing
  - Troubleshooting

- **[Godot UI Update Guide](mobile/GODOT_UI_UPDATE_GUIDE.md)** - Scene file updates
  - Profile UI changes
  - Marketplace UI structure
  - Testing in editor

- **[alSOL Marketplace Update](mobile/ALSOL_MARKETPLACE_UPDATE.md)** - Marketplace implementation
  - Swap system (SOL/LKC → alSOL)
  - Listing flow
  - Code changes summary

---

## 🔧 Backend

### Architecture
- **[Integration Architecture](backend/INTEGRATION_ARCHITECTURE.md)** - System design overview
  - Component interaction
  - Database vs blockchain
  - API endpoints

- **[Integration Complete](backend/INTEGRATION_COMPLETE.md)** - Backend implementation details
  - PostgreSQL schema (12 tables)
  - REST API endpoints (20+)
  - alSOL swap logic
  - Element bridging

- **[Implementation Fixes](backend/IMPLEMENTATION_FIXES.md)** - Bug fixes and improvements
  - Discovery tracking
  - Tax system
  - Database optimizations

---

## ⛓️ Smart Contracts

### Solana Programs
See [solana-contracts/README.md](../solana-contracts/README.md) for:
- Element NFT Program
- Marketplace Program
- Registry Program
- Burn Proof Program

**Contract Docs:**
- [ALSOL Architecture](../solana-contracts/ALSOL_ARCHITECTURE.md)
- [Deployment Ready](../solana-contracts/DEPLOYMENT_READY.md)
- [OnChain Requirements](../solana-program/ONCHAIN_REQUIREMENTS.md)

---

## 🚀 Quick Links

### For Players:
1. Download app (coming soon)
2. Connect Solana wallet
3. Start walking!

### For Developers:

**Setup:**
- [Mobile App Setup](../godot-mobile/README.md)
- [Backend Setup](../backend/README.md)
- [Contract Deployment](../solana-contracts/README.md)

**Building:**
- [Health Plugin Quick Start](../godot-mobile/plugins/PLUGIN_QUICK_START.md)
- [Build Plugins Script](../godot-mobile/plugins/build_plugins.sh)

---

## 📊 Documentation Map

```
docs/
├── README.md                    ← You are here
├── ELEMENTS_AND_REACTIONS.md   ← Game mechanics
├── ELEMENT_TOKEN_FLOW.md        ← DATA → NFT bridge
│
├── health/                      ← Health tracking
│   ├── HEALTH_API_SETUP.md
│   ├── HEALTH_PLUGIN_SUMMARY.md
│   └── HEALTH_TO_GAME_DATA_FORMULA.md
│
├── mobile/                      ← Mobile app UI
│   ├── UI_CUSTOMIZATION_GUIDE.md
│   ├── GODOT_UI_UPDATE_GUIDE.md
│   └── ALSOL_MARKETPLACE_UPDATE.md
│
└── backend/                     ← Backend API
    ├── INTEGRATION_ARCHITECTURE.md
    ├── INTEGRATION_COMPLETE.md
    └── IMPLEMENTATION_FIXES.md
```

---

## 🔍 Find What You Need

### I want to...

**Understand the game:**
→ [Elements & Reactions](ELEMENTS_AND_REACTIONS.md)

**Set up health tracking:**
→ [Health API Setup](health/HEALTH_API_SETUP.md)

**Customize the UI:**
→ [UI Customization Guide](mobile/UI_CUSTOMIZATION_GUIDE.md)

**Deploy the backend:**
→ [Integration Complete](backend/INTEGRATION_COMPLETE.md)

**Deploy smart contracts:**
→ [Solana Contracts](../solana-contracts/README.md)

**Understand movement rewards:**
→ [Health → Game Data](health/HEALTH_TO_GAME_DATA_FORMULA.md)

---

## 📝 Contributing to Docs

Found an error or want to improve the documentation?

1. Edit the relevant `.md` file
2. Follow markdown best practices
3. Test links locally
4. Submit a pull request

**Style Guide:**
- Use emojis sparingly (section headers only)
- Include code examples
- Add diagrams for complex flows
- Keep language clear and concise

---

## 📞 Support

**Questions?**
- Discord: https://discord.gg/lenkinverse
- GitHub Issues: https://github.com/yourusername/LenKinVerse/issues

**Docs Website:** https://docs.lenkinverse.com (coming soon)

---

**Last Updated:** November 2025

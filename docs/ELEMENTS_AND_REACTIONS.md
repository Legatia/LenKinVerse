# 🧪 Elements & Reactions Guide

**LenKinVerse Chemistry System**

---

## 🎨 Rarity System

| Rarity | Color | Description | Examples |
|--------|-------|-------------|----------|
| **0 - Common** | Gray (#9CA3AF) | Basic elements found everywhere | lkC, lkO, lkH, lkN, lkSi |
| **1 - Uncommon** | Green (#10B981) | Simple compounds from reactions | CO2, H2O |
| **2 - Rare** | Blue (#3B82F6) | Processed materials, advanced techniques | Coal, lkC14 |
| **3 - Legendary** | Purple (#8B5CF6) | Extremely rare or special materials | Carbon_X |

---

## 📦 Base Elements (Common - Rarity 0)

### **lkC (Carbon)**
- **Source:** Walking! (raw lkC from movement → analyze with gloves)
- **Rarity:** 0 (Common)
- **Used in:**
  - Coal formation (physical)
  - CO2 formation (chemical)
  - Nuclear fusion (nuclear)

### **lkO (Oxygen)**
- **Source:** Nuclear fusion from lkC
- **Rarity:** 0 (Common)
- **Used in:**
  - CO2 formation (chemical)
  - H2O formation (chemical)

### **lkH (Hydrogen)**
- **Source:** Not yet implemented
- **Rarity:** 0 (Common)
- **Used in:**
  - H2O formation (chemical)

### **lkN (Nitrogen)**
- **Source:** Not yet implemented
- **Rarity:** 0 (Common)
- **Used in:** Future reactions

### **lkSi (Silicon)**
- **Source:** Not yet implemented
- **Rarity:** 0 (Common)
- **Used in:** Future reactions

---

## 🧪 Compounds (Uncommon - Rarity 1)

### **CO2 (Carbon Dioxide)**
- **Rarity:** 1 (Uncommon)
- **Recipe:** lkC (1) + lkO (2) → CO2 (1)
- **Type:** Chemical reaction
- **Cost:** 6 ⚡ charge (3 units × 2 charge)
- **Description:** Combine Carbon and Oxygen

### **H2O (Water)**
- **Rarity:** 1 (Uncommon)
- **Recipe:** lkH (2) + lkO (1) → H2O (1)
- **Type:** Chemical reaction
- **Cost:** 6 ⚡ charge (3 units × 2 charge)
- **Description:** Combine Hydrogen and Oxygen

---

## 🔷 Processed Materials (Rare - Rarity 2)

### **Coal**
- **Rarity:** 2 (Rare)
- **Recipe:** lkC (5) → Coal (1)
- **Type:** Physical reaction (compression)
- **Cost:** 5 ⚡ charge (5 units × 1 charge)
- **Description:** Compress 5 Carbon into Coal

### **lkC14 (Carbon-14 Isotope)**
- **Rarity:** 2 (Rare)
- **Source:** Special discovery (not in standard reactions)
- **Used as:** Nuclear catalyst (enables fusion reactions)
- **Volume:** Each unit has volume, consumed 0.5 per nuclear reaction
- **Description:** Radioactive isotope used as catalyst

---

## ✨ Legendary Materials (Legendary - Rarity 3)

### **Carbon_X (Undefined Material)**
- **Rarity:** 3 (Legendary)
- **Source:** **0.1% chance** when nuclear fusion **fails**
- **Recipe:** Failed nuclear reaction → Carbon_X (1)
- **Discovery chance:** 0.001 (0.1%)
- **Description:** Mysterious material discovered during nuclear failures

---

## ⚡ Reaction Types

### 1️⃣ **Physical Reactions**
- **Charge Cost:** 1 ⚡ per unit
- **Examples:** Compression, crushing
- **Current Reactions:**
  - **Coal Formation:** lkC (5) → Coal (1)

### 2️⃣ **Chemical Reactions**
- **Charge Cost:** 2 ⚡ per unit
- **Examples:** Combustion, synthesis
- **Current Reactions:**
  - **CO2 Formation:** lkC (1) + lkO (2) → CO2 (1)
  - **H2O Formation:** lkH (2) + lkO (1) → H2O (1)

### 3️⃣ **Nuclear Reactions**
- **Charge Cost:** 5 ⚡ per unit
- **Requires:** Isotope catalyst (lkC14)
- **Catalyst Consumption:** 0.5 volume per reaction
- **Success Rate:** 10%
- **Current Reactions:**
  - **Carbon Fusion:** lkC (1) + [lkC14 catalyst] → lkO (2)
    - **Success (10%):** Get lkO (2)
    - **Failure (90%):** Get lkC (1) back + 0.1% chance for Carbon_X

---

## 📊 Complete Reaction Database

### Physical Reactions (1 ⚡/unit):

| Name | Input | Output | Charge | Description |
|------|-------|--------|--------|-------------|
| **Coal Formation** | lkC × 5 | Coal × 1 | 5 ⚡ | Compress Carbon |

### Chemical Reactions (2 ⚡/unit):

| Name | Input | Output | Charge | Description |
|------|-------|--------|--------|-------------|
| **Carbon Dioxide** | lkC × 1 + lkO × 2 | CO2 × 1 | 6 ⚡ | Combustion |
| **Water** | lkH × 2 + lkO × 1 | H2O × 1 | 6 ⚡ | Synthesis |

### Nuclear Reactions (5 ⚡/unit):

| Name | Input | Catalyst | Output | Success | Charge |
|------|-------|----------|--------|---------|--------|
| **Carbon Fusion** | lkC × 1 | lkC14 (0.5v) | lkO × 2 | 10% | 5 ⚡ |
| **Carbon Fusion (Fail)** | lkC × 1 | lkC14 (0.5v) | lkC × 1 + 0.1% Carbon_X | 90% | 5 ⚡ |

---

## 🎯 Gameplay Loop

### Step 1: Collect Raw Carbon
```
Walk in real world
    ↓
Get raw lkC chunks (~15 per 50m)
    ↓
Analyze with Gloves (85% success rate)
    ↓
Get clean lkC
```

### Step 2: Choose Your Path

#### **Path A: Make Coal (Easy)**
```
lkC × 5 → Coal × 1
Cost: 5 ⚡ charge
Use: Rare material for trading
```

#### **Path B: Get Oxygen (Hard)**
```
lkC × 1 + lkC14 catalyst → lkO × 2
Cost: 5 ⚡ charge + 0.5 catalyst volume
Success: 10% chance
Reward: Oxygen for making CO2 or H2O
```

#### **Path C: Hunt for Carbon_X (Legendary)**
```
Try carbon fusion repeatedly
Fail 90% of the time
Each failure: 0.1% chance for Carbon_X
Expected attempts: ~1,000 failures for 1 Carbon_X
```

### Step 3: Make Compounds
```
Option 1: CO2
lkC × 1 + lkO × 2 → CO2 × 1
Cost: 6 ⚡

Option 2: H2O
lkH × 2 + lkO × 1 → H2O × 1
Cost: 6 ⚡
```

---

## 💎 Discovery & Tax System

### First-Time Discovery:
- **You discover a new element** → No tax!
- **You get full amount**
- **You get discovery credit** on blockchain
- **72-hour lock period** starts (tradeable after 72h)
- **During lock:** Other creators get 2× compensation

### After Discovery (Not First):
- **Element already discovered** → 10% tax
- **Tax goes to treasury**
- **Original discoverer benefits**
- **If still locked:** You get 2× amount (minus tax)
- **If tradeable:** You get 1× amount (minus tax)

### Example:
```
Coal Formation (5 lkC → 1 Coal)

Scenario 1: You're the first to discover Coal
→ You get: 1 Coal (full)
→ Tax: None
→ Tradeable after 72h

Scenario 2: Someone else discovered Coal (still locked)
→ You get: 2 Coal - 10% tax = 1.8 Coal (2× compensation)
→ Tax: 0.2 Coal to treasury

Scenario 3: Coal is tradeable
→ You get: 1 Coal - 10% tax = 0.9 Coal
→ Tax: 0.1 Coal to treasury
```

---

## 🔬 Element Acquisition Methods

### Currently Implemented:

| Element | How to Get | Difficulty |
|---------|-----------|------------|
| **lkC** | Walk + analyze | ⭐ Easy |
| **Coal** | Physical: lkC × 5 | ⭐⭐ Medium |
| **lkO** | Nuclear: lkC fusion (10% success) | ⭐⭐⭐⭐ Hard |
| **CO2** | Chemical: lkC + lkO × 2 | ⭐⭐⭐ Medium |
| **Carbon_X** | Nuclear failure (0.1% chance) | ⭐⭐⭐⭐⭐ Legendary |

### Not Yet Implemented:

| Element | Planned Source |
|---------|----------------|
| **lkH** | Future: Electrolysis or collection |
| **lkN** | Future: Air processing |
| **lkSi** | Future: Earth materials |
| **lkC14** | Future: Special discovery mechanism |
| **H2O** | Chemical: lkH × 2 + lkO (needs lkH source) |

---

## ⚡ Charge Economy

### Gloves Charge Sources:
- Recharges over time
- Max capacity depends on gloves level
- Current charge shown in HUD

### Charge Costs:
```
Physical reactions: 1 ⚡ per input unit
    Coal (5 lkC): 5 ⚡

Chemical reactions: 2 ⚡ per input unit
    CO2 (3 units): 6 ⚡
    H2O (3 units): 6 ⚡

Nuclear reactions: 5 ⚡ per input unit
    Fusion (1 lkC): 5 ⚡
```

### Strategy Tips:
- **Save charge for nuclear attempts** (high risk, high reward)
- **Do physical reactions** when charge is low (cheap)
- **Chemical reactions** are mid-tier (moderate cost for useful compounds)

---

## 🎲 RNG Elements

### Element Drops (from walking):
- Base: random(12, 20) raw lkC per chunk
- Efficiency modifier: 95% (walking) to 0% (vehicle)
- Analysis success: 80-90% (gloves level dependent)

### Nuclear Reactions:
- Success rate: 10%
- Failure discovery: 0.1%
- Expected Carbon_X: 1 per ~10,000 carbon used

### Why RNG?
- Adds excitement and unpredictability
- Prevents perfect optimization/botting
- Makes discoveries feel special
- Creates market value variance

---

## 🚀 Future Expansion Ideas

### Potential New Reactions:

**Physical:**
- Diamond formation (extreme compression of Coal)
- Crystal structures from Silicon

**Chemical:**
- Ammonia (lkN + lkH × 3)
- Methane (lkC + lkH × 4)
- Complex organic molecules

**Nuclear:**
- Isotope creation (lkC → lkC14)
- Element transmutation (higher atomic numbers)
- Fusion chains (lkO → lkNe → lkMg)

---

## 📋 Quick Reference

### Get Started:
1. **Walk** → Get raw lkC
2. **Analyze** → Clean lkC
3. **React** → Make compounds

### Easiest Reactions:
1. Coal (5 lkC, 5 ⚡)
2. CO2 (need lkO first)
3. H2O (need lkH implementation)

### Hardest Challenges:
1. Get lkO (10% nuclear success)
2. Find Carbon_X (0.1% on failure)
3. Discover all elements first (discovery bonus)

---

## ✅ Summary

### Current Elements: **10 total**
- **5 Common:** lkC, lkO, lkH, lkN, lkSi
- **2 Uncommon:** CO2, H2O
- **2 Rare:** Coal, lkC14
- **1 Legendary:** Carbon_X

### Current Reactions: **4 total**
- **1 Physical:** Coal formation
- **2 Chemical:** CO2, H2O
- **1 Nuclear:** Carbon fusion (with failure discovery)

### Efficiency Update: ✅
- **Walking:** 95% efficiency
- **Jogging:** 85% efficiency
- **Running:** 70% efficiency
- **Vehicle:** **0% efficiency** (no rewards) ❌

**The chemistry system encourages exploration, experimentation, and rewards patient players who walk regularly!** 🚶‍♂️🧪✨

# 🎮 Health Data → Game Rewards Formula

**How real-world movement becomes in-game materials**

---

## 📊 Raw Data from Health APIs

### Input Data (from iOS/Android):

| Data Point | Type | Unit | Example |
|------------|------|------|---------|
| **Steps** | Integer | count | 5,432 steps |
| **Distance** | Float | meters | 4,123.5 m |
| **Time Range** | Timestamp | Unix time | Last app close → now |

### Data Source:
```gdscript
// iOS HealthKit
var steps = HealthKit.get_steps({
    "start_date": last_close_time,  // When app was closed
    "end_date": now                 // Current time
})

var distance = HealthKit.get_distance({
    "start_date": last_close_time,
    "end_date": now
})

// Android Health Connect (same API)
var steps = HealthConnect.getSteps({...})
var distance = HealthConnect.getDistance({...})
```

---

## 🧮 Transformation Formulas

### Step 1: Calculate Movement Efficiency

**Purpose:** Detect if player walked, ran, or used a vehicle to prevent cheating

**Formula:**
```gdscript
avg_stride = distance_meters / total_steps

if avg_stride < 0.85:
    efficiency = 0.95    // Walking (0.7-0.8m per step)
elif avg_stride < 1.2:
    efficiency = 0.85    // Jogging (1.0-1.2m per step)
elif steps > distance * 0.3:
    efficiency = 0.70    // Running (1.2-1.5m per step)
else:
    efficiency = 0.50    // Vehicle (few steps, large distance)
```

**Example:**
```
Player walked 4,000 meters with 5,000 steps
avg_stride = 4000 / 5000 = 0.8 m/step
→ Walking detected → efficiency = 95%
```

**Anti-Cheat:**
```
Player drove 10,000 meters with 100 steps
avg_stride = 10000 / 100 = 100 m/step
→ Vehicle detected → efficiency = 50% (penalty)
```

---

### Step 2: Convert Distance to Chunks

**Formula:**
```gdscript
chunks_collected = floor(distance_meters / 50.0)
```

**Meaning:**
- Every **50 meters** of real-world movement = **1 chunk** of raw material
- Example: Walk 500 meters → Get 10 chunks

**Why 50 meters?**
- ~60 steps at average walking pace
- Takes ~30-40 seconds to walk
- Encourages short, frequent walks (game design)

---

### Step 3: Generate Raw lkC per Chunk

**Formula:**
```gdscript
for each chunk:
    base_amount = random(12, 20)      // RNG per chunk
    final_amount = floor(base_amount * efficiency)
```

**Example:**
```
Walking (95% efficiency):
    Chunk 1: base=15 → final=14 raw lkC
    Chunk 2: base=18 → final=17 raw lkC
    Chunk 3: base=12 → final=11 raw lkC
    Total: 42 raw lkC from 3 chunks

Running (70% efficiency):
    Chunk 1: base=15 → final=10 raw lkC
    Chunk 2: base=18 → final=12 raw lkC
    Chunk 3: base=12 → final=8 raw lkC
    Total: 30 raw lkC from 3 chunks (penalty for running)
```

**Why random 12-20?**
- Adds excitement/variety
- Average: 16 raw lkC per chunk
- Walking: ~15 raw lkC per chunk (16 × 0.95)
- Running: ~11 raw lkC per chunk (16 × 0.70)

---

## 📈 Complete Example Calculation

### Scenario: Player walks to work

**Input (from HealthKit/Health Connect):**
```
Time offline: 30 minutes
Distance: 2,400 meters (2.4 km)
Steps: 3,000 steps
```

**Step-by-Step:**

1️⃣ **Calculate efficiency:**
```
avg_stride = 2400 / 3000 = 0.8 m/step
→ Walking detected
→ efficiency = 0.95 (95%)
```

2️⃣ **Calculate chunks:**
```
chunks = floor(2400 / 50)
chunks = floor(48)
chunks = 48 chunks
```

3️⃣ **Generate raw lkC:**
```
For 48 chunks with random(12,20) and 95% efficiency:

Chunk 1: 15 × 0.95 = 14
Chunk 2: 18 × 0.95 = 17
Chunk 3: 12 × 0.95 = 11
... (45 more chunks)

Average per chunk: 16 × 0.95 = 15.2 raw lkC
Total: 48 × 15.2 ≈ 730 raw lkC
```

**Rewards Summary:**
```gdscript
{
    "chunks": 48,
    "total_raw_lkc": ~730,
    "efficiency": 95%,
    "avg_per_chunk": 15.2
}
```

---

## 🎯 Game Economy Balancing

### Distance → Chunks Conversion:

| Distance Walked | Chunks | Avg Raw lkC (95%) | Time to Walk |
|-----------------|--------|-------------------|--------------|
| 50m | 1 | ~15 | ~40 seconds |
| 500m | 10 | ~150 | ~6 minutes |
| 1 km | 20 | ~300 | ~12 minutes |
| 5 km | 100 | ~1,500 | ~1 hour |
| 10 km | 200 | ~3,000 | ~2 hours |

### Efficiency Impact:

| Movement Type | Efficiency | lkC per 1km | Penalty |
|---------------|-----------|-------------|---------|
| **Walking** | 95% | ~300 | None (optimal) |
| **Jogging** | 85% | ~270 | -10% |
| **Running** | 70% | ~220 | -26% |
| **Vehicle** | 50% | ~160 | -47% |

**Design Goal:** Encourage healthy walking, not sprinting or driving

---

## 🔬 Raw lkC → Cleaned lkC

**Next Step (Player Action):**
Raw lkC must be **analyzed** with Alchemy Gloves to become usable:

```gdscript
raw_lkC → [Gloves Analysis] → lkC (cleaned)
```

**Analysis Success Rate:**
- Base: 80-90% success rate
- Gloves level affects success rate
- Failed analysis consumes the raw material

**Example:**
```
Player has 730 raw lkC
Analyzes all with 85% success rate
Result: 730 × 0.85 = 620 lkC (cleaned)
```

**Final Currency:**
- **lkC (cleaned)** can be spent in marketplace
- **lkC (cleaned)** can be swapped for alSOL (1M lkC = 1 alSOL)
- **lkC (cleaned)** used in reactions to create compounds

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS/Android Health API                    │
│  HealthKit (iOS) / Health Connect (Android)                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
              ┌───────────────┐
              │  Raw Data     │
              │  • Steps: int │
              │  • Distance:m │
              └───────┬───────┘
                      │
                      ▼
         ┌────────────────────────────┐
         │  HealthManager             │
         │  (health_manager.gd)       │
         ├────────────────────────────┤
         │  calculate_efficiency()    │
         │  → avg_stride = dist/steps │
         │  → return efficiency %     │
         └────────┬───────────────────┘
                  │
                  ▼
    ┌─────────────────────────────────┐
    │  GameManager                    │
    │  (game_manager.gd)              │
    ├─────────────────────────────────┤
    │  chunks = floor(distance / 50)  │
    │                                 │
    │  for each chunk:                │
    │    base = random(12,20)         │
    │    final = base × efficiency    │
    │    total += final               │
    └─────────┬───────────────────────┘
              │
              ▼
    ┌──────────────────────┐
    │  Offline Rewards     │
    │  • 48 chunks         │
    │  • 730 raw lkC       │
    │  • 95% efficiency    │
    └──────────┬───────────┘
               │
               ▼
    ┌───────────────────────┐
    │  Player Inventory     │
    │  (inventory_manager)  │
    │  raw_materials.lkC += │
    └───────────────────────┘
               │
               ▼
    ┌────────────────────────┐
    │  Player Action Needed  │
    │  (Use Gloves to Analyze)│
    └────────────────────────┘
               │
               ▼
    ┌───────────────────────┐
    │  Cleaned lkC          │
    │  • Trade on market    │
    │  • Swap for alSOL     │
    │  • Use in reactions   │
    └───────────────────────┘
```

---

## 🔢 Formula Summary

### 1. Efficiency Calculation:
```
avg_stride = distance_meters / total_steps

efficiency = {
    0.95  if avg_stride < 0.85       (Walking)
    0.85  if avg_stride < 1.2        (Jogging)
    0.70  if steps > distance × 0.3  (Running)
    0.50  otherwise                  (Vehicle/Cheating)
}
```

### 2. Chunks Generation:
```
chunks_count = floor(distance_meters / 50.0)
```

### 3. Raw lkC per Chunk:
```
base_amount = random_int(12, 20)
final_amount = floor(base_amount × efficiency)
```

### 4. Total Rewards:
```
total_raw_lkC = sum(final_amount for all chunks)
average_per_chunk = total_raw_lkC / chunks_count
```

### 5. Expected Values (Walking):
```
Expected lkC per chunk: 16 × 0.95 = 15.2
Expected lkC per 1km: (1000 / 50) × 15.2 = 304
Expected lkC per hour: (5000 / 50) × 15.2 ≈ 1,520
```

---

## 🎮 Game Design Rationale

### Why These Numbers?

**50m per chunk:**
- Small enough to feel rewarding frequently
- Large enough to prevent spam/shaking phone
- Natural "block" in city walking

**Random 12-20 base:**
- Excitement factor (RNG)
- Prevents exact prediction
- Average 16 = balanced economy

**95% walking efficiency:**
- Small penalty encourages optimal pace
- Prevents "just walk faster" meta
- Rewards sustainable movement

**Anti-cheat penalties:**
- Running: -26% (discourages rushing)
- Vehicle: -47% (strong deterrent)
- Based on biomechanics (stride length)

---

## 📱 Platform Differences

### iOS HealthKit vs Android Health Connect:

**Data Format:** Identical (both return same structure)
**Accuracy:** Similar (both use device sensors)
**Granularity:** Both track per-step precision

**Differences:**
- iOS: Automatic background tracking
- Android: Requires Health Connect app installed
- Both need explicit user permission

**No code changes needed** - HealthManager abstracts the differences!

---

## 🧪 Testing Values

### Mock Mode (No Device):
```gdscript
// Simulates 1 km/hour walked
hours_offline = 1.0
mock_distance = 1000 meters
mock_steps = 1333 (0.75m stride)
chunks = 20
raw_lkC ≈ 300
```

### Real Device Example:
```
Morning walk: 2.5 km in 30 minutes
→ Distance: 2500m
→ Steps: ~3200
→ Chunks: 50
→ Raw lkC: ~760
```

---

## ✅ Summary

### What We Get:
- **Steps** (count)
- **Distance** (meters)
- **Time range** (last close → now)

### Formula Chain:
1. **Distance + Steps** → **Efficiency %** (anti-cheat)
2. **Distance** → **Chunks** (÷ 50m)
3. **Chunks** → **Raw lkC** (random 12-20 × efficiency)
4. **Raw lkC** → **Cleaned lkC** (player analyzes with gloves)

### Key Balancing:
- **1 km walking = ~300 raw lkC**
- **1 hour walking = ~1,500 raw lkC**
- **Walking is optimal** (95% efficiency)
- **Running/vehicles penalized** (70-50% efficiency)

**The system rewards healthy, sustainable movement!** 🏃‍♂️🎮

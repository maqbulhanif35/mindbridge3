# MindBridge Crisis Text Classifier — Technical Explanation

## What it does

The crisis text classifier is a small neural network that reads a chat message and estimates the probability that the message expresses one of three mental states:

| Class | Label | Meaning |
|---|---|---|
| 0 | **safe** | Normal conversation, no distress detected |
| 1 | **distress** | Struggling emotionally but not in immediate danger |
| 2 | **crisis** | Suicidal ideation, self-harm, or immediate danger |

It runs entirely on the user's device — no text is sent to an external server for this analysis. The result is a probability score for each class, e.g. `{ safe: 0.05, distress: 0.18, crisis: 0.77 }`. These probabilities always sum to 1.0.

---

## The problem with keywords alone

The previous system matched chat messages against hand-written keyword lists (e.g. "kill myself", "want to die"). Keywords have two weaknesses:

- **False negatives** — indirect language like *"I don't see the point of waking up anymore"* contains none of the listed keywords but is clearly a crisis signal.
- **False positives** — *"I want to kill this assignment"* contains the word "kill" and would wrongly trigger the keyword system.

A trained classifier learns from examples of real crisis and non-crisis language, so it understands context rather than just matching strings.

---

## Model architecture

The model is a **dual-branch 1D Convolutional Neural Network (CNN)**. Here is what each layer does:

```
Input: sequence of 128 integer token IDs
    ↓
Embedding layer (vocab_size=10000, dims=128)
    Turns each integer token ID into a 128-dimensional vector.
    The network learns these vectors during training.
    ↓
   ┌─────────────────┬─────────────────┐
   │  Conv1D(256, 3) │  Conv1D(256, 5) │   ← two parallel branches
   │  (tri-gram)     │  (5-gram)       │
   │  GlobalMaxPool  │  GlobalMaxPool  │
   └────────┬────────┴────────┬────────┘
            └───── Concat ────┘
                    ↓
           Dense(128, ReLU) + Dropout(0.4)
                    ↓
            Dense(3, Softmax)
                    ↓
Output: [P(safe), P(distress), P(crisis)]
```

**Why two Conv1D branches?**
The 3-filter branch learns short phrases (3 words at a time: *"kill myself"*, *"want to die"*). The 5-filter branch learns longer phrases (*"I don't want to live anymore"*). Combining both gives the model sensitivity to both short explicit signals and longer indirect ones.

**Dropout(0.4)** randomly disables 40% of neurons during training. This prevents the model from memorising the training examples and forces it to learn generalisable patterns.

**Softmax** converts the final layer's raw numbers into probabilities that sum to exactly 1.0.

The exported model size is **~1.6 MB** (dynamic-range quantised), which runs comfortably in ~15 ms on a mid-tier Android device.

---

## Vocabulary

Before text reaches the model it goes through a tokeniser:

1. **Lowercase** the text
2. **Strip** all characters except letters, digits, spaces, and apostrophes
3. **Split** on whitespace to get a list of words (tokens)
4. **Map** each word to an integer index using `crisis_vocab.json`
   - Index `0` = padding (empty position)
   - Index `1` = OOV (Out Of Vocabulary — word not seen during training)
   - Index `2` onwards = known words, most frequent first
5. **Truncate or pad** the list to exactly 128 tokens

Example:
```
"I want to kill myself tonight"
→ ["i", "want", "to", "kill", "myself", "tonight"]
→ [29, 3, 2, 327, 39, 37]   (indices from vocab)
→ padded to 128 integers
→ fed into the Embedding layer
```

The current vocabulary contains **558 words** — all words that appeared in the training data. Any word not in this list is mapped to OOV (index 1).

---

## Training data

The model was trained on a manually curated synthetic dataset of **180 labelled examples** (60 per class), each written specifically for the Kenyan university student context. The examples cover three categories:

### Safe (class 0) — 60 examples
Normal campus life with no distress signal:
- *"my HELB finally came through this semester, so relieved"*
- *"finished reading the required chapters early"*
- *"had lunch with my friends at the canteen today"*

### Distress (class 1) — 60 examples
Emotional struggle, academic stress, loneliness — but no immediate danger:
- *"i can't sleep, my mind races about exams all night"*
- *"i feel completely lost and don't know what to do"*
- *"HELB hasn't come and my rent is already overdue"*

### Crisis (class 2) — 60 examples
Suicidal ideation, self-harm, expressions of intent:
- *"i want to kill myself"*
- *"i've already written goodbye letters to my family"*
- *"i'm going to hurt myself tonight"*

The synthetic examples were **oversampled 4×** during training (each example appears 4 times) to compensate for the small dataset size and give the Kenyan context stronger influence over the model's learned patterns.

The training script also attempts to download a supplementary dataset from HuggingFace (`vibhorag101/phr_suicidal_detection_dataset`, ~8,000 Reddit posts). In this training run that dataset was unavailable, so the model was trained on the synthetic data only.

---

## How the model is used in the app

The classifier runs as part of a **dual-layer detection system**. Every chat message sent to Maya goes through both layers:

```
User sends a message
        ↓
┌───────────────────────────────────────┐
│  Layer 1: Keyword scan (synchronous)  │
│  Checks against 3 hardcoded lists:    │
│    Tier 1 — general distress words    │
│    Tier 2 — explicit crisis phrases   │
│    Tier 3 — immediate danger phrases  │
└─────────────────┬─────────────────────┘
                  ↓
┌───────────────────────────────────────┐
│  Layer 2: ML classifier (async)       │
│  Runs in a background isolate.        │
│  Returns P(safe), P(distress),        │
│  P(crisis) within ~15 ms.            │
└─────────────────┬─────────────────────┘
                  ↓
     Take the MORE SEVERE of the two results.
     (Neither layer can downgrade the other.)
                  ↓
        Final crisis tier (0–3)
```

The background isolate means the ML inference never blocks the UI thread or delays Maya's response.

---

## Thresholds — mapping probabilities to tiers

The raw `P(crisis)` and `P(distress)` values from the model are mapped to the existing three-tier escalation system using thresholds stored in `assets/models/crisis_thresholds.json`:

```json
{
  "distress_min": 0.42,
  "crisis_min":   0.72,
  "tier3_min":    0.91
}
```

| Condition | Tier assigned | App response |
|---|---|---|
| `P(crisis) ≥ 0.91` | Tier 3 | Screen locked to crisis resources |
| `P(crisis) ≥ 0.72` | Tier 2 | Full crisis screen shown |
| `P(distress) ≥ 0.42` | Tier 1 | In-app banner + breathing prompt |
| Neither | None | Normal conversation continues |

These thresholds can be edited directly in the JSON file without retraining the model. Lowering `crisis_min` makes detection more sensitive (more tier 2 alerts, more false positives). Raising it makes it stricter (fewer alerts, more false negatives). The current values are conservative defaults — they should be re-calibrated once the model is retrained on a larger dataset.

---

## Detection method tracking

Each detection event records how it was triggered, stored in `CrisisEscalationState.detectionMethod`:

| Value | Meaning |
|---|---|
| `keyword` | Only the keyword scan triggered |
| `ml` | Only the ML model triggered (keyword missed it) |
| `both` | Both systems agreed |
| `none` | No crisis detected |

This is also stored in the `crisis_events` database table (`detection_method` column) alongside the raw `ml_score`, so counsellors in the admin panel can see which cases the model caught that keywords would have missed.

---

## Output visible in the admin panel

When a crisis case is open in the admin panel, counsellors see:

- **Risk score** — formula-based score (0–100) computed from tier, time of day, and repeat detections. This existed before the ML integration.
- **ML Crisis: XX%** — the raw `P(crisis)` from the model, shown as a percentage. This appears as a purple pill once the background scoring for that case completes (the admin panel scores the top 50 active cases in the background after loading).

---

## Current limitations

| Limitation | Impact | How to address |
|---|---|---|
| Only 180 training examples | Model has learned patterns but may miss unusual phrasing | Retrain with the HuggingFace dataset once available (see training script) |
| Vocabulary of 558 words | Words outside the training set map to OOV; meaning is partially lost | Retrain with more data to expand the vocabulary |
| No Swahili or Sheng support | Mixed-language messages are partially tokenised | Collect Kenyan-specific examples and add them to the training set |
| Thresholds not calibrated on held-out data | False positive/negative rate unknown | After retraining, compute precision/recall on a test set and adjust thresholds accordingly |

The keyword system remains active at all times as a hardcoded safety net. Even if the ML model produces a wrong result, explicit phrases like "going to kill myself" will always trigger tier 3 regardless.

---

## How to retrain with more data

1. Open `ml/train_crisis_classifier.py` in Google Colab
2. The script will automatically download ~8,000 examples from HuggingFace
3. Add any additional examples to the `SAFE_TEXTS`, `DISTRESS_TEXTS`, or `CRISIS_TEXTS` lists in Section 3 of the script
4. Run all cells — training takes ~10 minutes on Colab's free CPU
5. Download the three output files and replace the contents of `assets/models/`
6. Rebuild the Flutter app — the new model is picked up automatically at startup

The thresholds in `crisis_thresholds.json` can be tuned independently of retraining by editing the file directly and rebuilding.

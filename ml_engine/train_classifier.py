import joblib
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import LinearSVC
from sklearn.metrics import accuracy_score, classification_report

print("=" * 70)
print("TRAINING CATEGORY CLASSIFICATION MODEL")
print("Language: ENGLISH ONLY")
print("=" * 70)

# Load dataset
data = pd.read_csv("../data/complaints_dataset.csv")

print(f"\n✓ Dataset loaded: {len(data)} complaints")
print(f"✓ Categories: {list(data['category'].unique())}")
print(f"\nCategory distribution:")
print(data['category'].value_counts())

# Features and target
X = data["description"]
y = data["category"]

# ENGLISH ONLY: Word-level TF-IDF
vectorizer = TfidfVectorizer(
    analyzer='word',            # Word-level (not character-level)
    ngram_range=(1, 2),        # Unigrams and bigrams
    max_features=3000,
    min_df=2,
    max_df=0.8,
    stop_words='english',
    sublinear_tf=True,
    strip_accents='unicode',
    lowercase=True
)

X_vectors = vectorizer.fit_transform(X)

print(f"\n✓ Text vectorization complete")
print(f"  - Features: {X_vectors.shape[1]}")
print(f"  - Analyzer: word-level (English)")

# Stratified split
X_train, X_test, y_train, y_test = train_test_split(
    X_vectors, y, 
    test_size=0.2, 
    random_state=42, 
    stratify=y
)

print(f"\n✓ Train-test split")
print(f"  - Training: {X_train.shape[0]} samples")
print(f"  - Testing: {X_test.shape[0]} samples")

# Train LinearSVC
print(f"\n⏳ Training LinearSVC model...")
model = LinearSVC(
    C=1.0,
    max_iter=2000,
    random_state=42,
    class_weight='balanced',
    dual='auto'
)
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

print(f"\n" + "=" * 70)
print(f"MODEL PERFORMANCE")
print("=" * 70)
print(f"\n✓ Accuracy: {accuracy:.2%}")
print(f"\nClassification Report:")
print(classification_report(y_test, y_pred, zero_division=0))

# Save model
joblib.dump(model, "../backend/ai/category_model.pkl")
joblib.dump(vectorizer, "../backend/ai/category_vectorizer.pkl")

print("=" * 70)
print("✓ Model saved: backend/ai/category_model.pkl")
print("✓ Vectorizer saved: backend/ai/category_vectorizer.pkl")
print("=" * 70)

# Test samples
print("\n" + "=" * 70)
print("TESTING WITH ENGLISH SAMPLES")
print("=" * 70)

test_samples = [
    ("No electricity for 5 days emergency", "Electricity"),
    ("Water supply stopped without notice", "Water Supply"),
    ("Garbage pile near school", "Sanitation"),
    ("Road potholes causing accidents", "Roads"),
    ("Doctor absent in emergency", "Health"),
    ("Bribe demanded for certificate", "Corruption"),
    ("Street lights not working", "Street Lighting"),
    ("Drain overflow on street", "Drainage"),
]

correct = 0
for text, expected in test_samples:
    vec = vectorizer.transform([text])
    pred = model.predict(vec)[0]
    status = "✅" if pred == expected else "❌"
    if pred == expected:
        correct += 1
    print(f"\n{status} {text}")
    print(f"   → {pred} (Expected: {expected})")

print(f"\n" + "=" * 70)
print(f"Test Accuracy: {correct}/{len(test_samples)} = {correct/len(test_samples):.1%}")
print("=" * 70)
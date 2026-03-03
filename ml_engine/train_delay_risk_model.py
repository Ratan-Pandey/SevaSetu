import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report

print("=" * 60)
print("TRAINING DELAY RISK PREDICTION MODEL")
print("=" * 60)

# Load AUGMENTED dataset
data = pd.read_csv("../data/complaints_dataset.csv")

print(f"\n[OK] Dataset loaded: {len(data)} complaints")

# Create delay label based on resolution days
# Low: <=7 days, Medium: 8-14 days, High: >14 days
def categorize_delay(days):
    if days <= 7:
        return "Low"
    elif days <= 14:
        return "Medium"
    else:
        return "High"

data["delay_label"] = data["resolution_days"].apply(categorize_delay)

print(f"\nDelay risk distribution:")
print(data["delay_label"].value_counts())

# Select features
features = data[["category", "department", "urgency"]].copy()
target = data["delay_label"]

# Create encoders for each column
category_encoder = LabelEncoder()
department_encoder = LabelEncoder()
urgency_encoder = LabelEncoder()

features["category"] = category_encoder.fit_transform(features["category"])
features["department"] = department_encoder.fit_transform(features["department"])
features["urgency"] = urgency_encoder.fit_transform(features["urgency"])

print(f"\n[OK] Feature encoding complete")
print(f"  - Categories encoded: {len(category_encoder.classes_)}")
print(f"    {list(category_encoder.classes_)}")
print(f"  - Departments encoded: {len(department_encoder.classes_)}")
print(f"    {list(department_encoder.classes_)}")
print(f"  - Urgency levels encoded: {len(urgency_encoder.classes_)}")
print(f"    {list(urgency_encoder.classes_)}")

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(
    features, target, test_size=0.2, random_state=42, stratify=target
)

print(f"\n[OK] Train-test split complete")
print(f"  - Training samples: {X_train.shape[0]}")
print(f"  - Test samples: {X_test.shape[0]}")

# Train model
print(f"\n[...] Training Random Forest model...")
model = RandomForestClassifier(
    n_estimators=100, 
    random_state=42,
    max_depth=10,
    min_samples_split=5,
    class_weight='balanced'
)
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

print(f"\n" + "=" * 60)
print(f"MODEL PERFORMANCE")
print("=" * 60)
print(f"\n[OK] Accuracy: {accuracy:.2%}")
print(f"\nDetailed Classification Report:")
print(classification_report(y_test, y_pred))

# Feature importance
print(f"\nFeature Importance:")
feature_names = ["Category", "Department", "Urgency"]
importances = model.feature_importances_
for name, importance in zip(feature_names, importances):
    print(f"  {name}: {importance:.3f}")

# Save model and encoders
joblib.dump(model, "../backend/ai/delay_risk_model.pkl")
joblib.dump(category_encoder, "../backend/ai/category_encoder.pkl")
joblib.dump(department_encoder, "../backend/ai/department_encoder.pkl")
joblib.dump(urgency_encoder, "../backend/ai/urgency_encoder.pkl")

print("\n" + "=" * 60)
print("[OK] Model saved: backend/ai/delay_risk_model.pkl")
print("[OK] Encoders saved:")
print("  - category_encoder.pkl")
print("  - department_encoder.pkl")
print("  - urgency_encoder.pkl")
print("=" * 60)

# Test with sample cases
print("\n" + "=" * 60)
print("TESTING WITH SAMPLE CASES")
print("=" * 60)

test_cases = [
    ("Electricity", "Power Department", "High"),
    ("Water Supply", "Water Department", "Medium"),
    ("Sanitation", "Municipal Services", "Low"),
    ("Corruption", "Vigilance Department", "High"),
    ("Health", "Health Department", "High"),
]

for category, department, urgency in test_cases:
    # Create DataFrame with same column names as training
    input_df = pd.DataFrame({
        'category': category_encoder.transform([category]),
        'department': department_encoder.transform([department]),
        'urgency': urgency_encoder.transform([urgency])
    })
    
    encoded = input_df
    
    prediction = model.predict(encoded)[0]
    probabilities = model.predict_proba(encoded)[0]
    confidence = probabilities[list(model.classes_).index(prediction)]
    
    print(f"\nCategory: {category}")
    print(f"Department: {department}")
    print(f"Urgency: {urgency}")
    print(f"-> Delay Risk: {prediction} (Confidence: {confidence:.2%})")

print("\n" + "=" * 60)
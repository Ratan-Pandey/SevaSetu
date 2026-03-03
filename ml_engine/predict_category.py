import joblib

# Load saved model and vectorizer
model = joblib.load("category_model.pkl")
vectorizer = joblib.load("tfidf_vectorizer.pkl")

def predict_category(text):
    text_vector = vectorizer.transform([text])
    prediction = model.predict(text_vector)
    return prediction[0]

# Test with new complaints
test_complaints = [
    "There has been no water supply in my area for two days",
    "Electric poles are damaged and power cuts are frequent",
    "Garbage has not been collected for over a week",
    "Officer asked for bribe to approve my documents"
]

for complaint in test_complaints:
    print(f"Complaint: {complaint}")
    print(f"Predicted Category: {predict_category(complaint)}")
    print("-" * 50)

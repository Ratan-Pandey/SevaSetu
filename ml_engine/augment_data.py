"""
DATA AUGMENTATION FOR GRIEVANCE CLASSIFICATION
==============================================
Expands the dataset by creating variations of existing complaints:
1. Synonym replacement
2. Word order shuffling
3. Template-based generation
"""

import pandas as pd
import random
import re

# Load original data
data = pd.read_csv("../data/complaints_multilingual_expanded.csv")
print(f"Original dataset: {len(data)} samples")

# Synonym dictionaries for augmentation
synonyms = {
    # English
    'not working': ['broken', 'malfunctioning', 'out of order', 'damaged', 'failed'],
    'urgent': ['emergency', 'critical', 'immediate', 'pressing', 'asap'],
    'days': ['day', 'hours', 'time'],
    'problem': ['issue', 'trouble', 'complaint', 'difficulty'],
    'no': ['without', 'lacking', 'missing'],
    'bad': ['poor', 'terrible', 'awful', 'pathetic'],
    'help': ['assistance', 'support', 'action'],
    'needed': ['required', 'wanted', 'necessary'],
    'repair': ['fix', 'mend', 'restore'],
    'supply': ['service', 'provision', 'delivery'],
    
    # Hinglish
    'nahi': ['nhi', 'nahin', 'na'],
    'aa rahi': ['aa rhi', 'aati', 'aata'],
    'hai': ['h', 'he', 'hain'],
    'bahut': ['bohot', 'bohat', 'bht'],
    'kharab': ['bekaar', 'bekar', 'waste'],
    'paani': ['pani', 'water'],
    'bijli': ['electricity', 'light', 'current'],
    'sadak': ['road', 'rasta'],
    'ganda': ['dirty', 'gandi', 'gandagi'],
}

# Templates for each category
templates = {
    'Electricity': [
        "{prefix} electricity {issue} {time_phrase}",
        "Power {issue} in {location}",
        "Bijli {hinglish_issue} {time_phrase}",
        "Transformer {issue} {urgency}",
        "{issue} power supply {location}",
    ],
    'Water Supply': [
        "Water {issue} {time_phrase}",
        "Paani {hinglish_issue} {time_phrase}",
        "{issue} water supply {location}",
        "Pipeline {issue} {urgency}",
        "Tanker {issue} {time_phrase}",
    ],
    'Sanitation': [
        "Garbage {issue} {time_phrase}",
        "Kachra {hinglish_issue} {time_phrase}",
        "Cleaning {issue} {location}",
        "Sewage {issue} {urgency}",
        "{issue} sanitation {location}",
    ],
    'Roads': [
        "Road {issue} {location}",
        "Sadak {hinglish_issue} {location}",
        "Potholes {issue} {urgency}",
        "{issue} footpath {location}",
        "Traffic {issue} {time_phrase}",
    ],
    'Health': [
        "Doctor {issue} {location}",
        "Hospital {issue} {urgency}",
        "Medicine {issue} {time_phrase}",
        "Dawai {hinglish_issue} {location}",
        "{issue} treatment {urgency}",
    ],
    'Corruption': [
        "Bribe {issue} for {service}",
        "Rishwat {hinglish_issue} {service}",
        "{issue} money {service}",
        "Officer {issue} {service}",
        "Paisa {hinglish_issue} {service}",
    ],
    'Street Lighting': [
        "Street light {issue} {location}",
        "Lighting {issue} {time_phrase}",
        "Light pole {issue} {urgency}",
        "{issue} bulb {location}",
        "Lamp {issue} {time_phrase}",
    ],
    'Drainage': [
        "Drain {issue} {location}",
        "Nali {hinglish_issue} {location}",
        "Sewage {issue} {urgency}",
        "Gutter {issue} {time_phrase}",
        "Overflow {issue} {location}",
    ],
}

fillers = {
    'prefix': ['No', 'Frequent', 'Daily', 'Regular', 'Continuous'],
    'issue': ['not working', 'problem', 'issue', 'broken', 'failed', 'damaged', 'blocked', 'irregular'],
    'hinglish_issue': ['nahi aa rahi', 'kharab hai', 'band hai', 'tuti hai', 'problem hai', 'nahi hai'],
    'time_phrase': ['since morning', 'for 3 days', 'since yesterday', 'for weeks', 'past month', 'teen din se', 'kal se'],
    'location': ['in our area', 'near school', 'colony mein', 'hamare mohalle mein', 'in residential area', 'near hospital'],
    'urgency': ['urgent help needed', 'immediate action', 'emergency', 'please help', 'jaldi karo', 'bahut zaruri'],
    'service': ['certificate', 'connection', 'approval', 'document', 'license', 'permission'],
}

# Augmentation functions
def synonym_replace(text):
    """Replace some words/phrases with synonyms"""
    for word, syns in synonyms.items():
        if word in text.lower():
            if random.random() < 0.5:
                replacement = random.choice(syns)
                text = re.sub(word, replacement, text, flags=re.IGNORECASE)
    return text

def generate_from_template(category):
    """Generate new complaint from template"""
    if category not in templates:
        return None
    
    template = random.choice(templates[category])
    text = template
    
    for key, values in fillers.items():
        placeholder = '{' + key + '}'
        if placeholder in text:
            text = text.replace(placeholder, random.choice(values))
    
    return text

# Generate augmented data
augmented_rows = []

# Method 1: Synonym replacement on existing data (2x)
for _, row in data.iterrows():
    new_desc = synonym_replace(row['description'])
    if new_desc != row['description']:
        augmented_rows.append({
            'complaint_id': len(data) + len(augmented_rows) + 1,
            'description': new_desc,
            'category': row['category'],
            'urgency': row['urgency'],
            'department': row['department'],
            'created_day': row['created_day'],
            'resolution_days': row['resolution_days']
        })

# Method 2: Template-based generation (3 per category)
for category in templates.keys():
    dept_map = {
        'Electricity': 'Power Department',
        'Water Supply': 'Water Department',
        'Sanitation': 'Municipal Services',
        'Roads': 'Municipal Services',
        'Health': 'Health Department',
        'Corruption': 'Vigilance Department',
        'Street Lighting': 'Municipal Services',
        'Drainage': 'Municipal Services',
    }
    
    for _ in range(50):  # 50 per category
        desc = generate_from_template(category)
        if desc:
            # Correlate urgency with resolution days
            # High urgency = faster resolution (lower days)
            # Low urgency = slower resolution (higher days)
            urgency = random.choices(['High', 'Medium', 'Low'], weights=[0.3, 0.4, 0.3])[0]
            
            # Base days by urgency (Strict separation for better model learning)
            # High Urgency -> Low Delay Risk (< 7 days)
            # Medium Urgency -> Medium Delay Risk (8-14 days)
            # Low Urgency -> High Delay Risk (> 14 days)
            
            if urgency == 'High':
                base_days = random.randint(1, 3)  # Max with bias 3+4=7 (Low)
            elif urgency == 'Medium':
                base_days = random.randint(9, 11) # Min with neg bias 9-1=8 (Med), Max 11+4=15 (High?)
            else: # Low
                base_days = random.randint(18, 25) # Min 18-1=17 (High)
            
            # Department bias
            # Infrastructure depts are slower
            if category in ['Roads', 'Sanitation', 'Drainage', 'Street Lighting']:
                base_days += random.randint(1, 4)
            # Critical depts are faster
            elif category in ['Electricity', 'Water Supply', 'Health']:
                base_days -= random.randint(0, 1)
                
            # Ensure boundaries
            days = max(1, base_days)
            
            augmented_rows.append({
                'complaint_id': len(data) + len(augmented_rows) + 1,
                'description': desc,
                'category': category,
                'urgency': urgency,
                'department': dept_map.get(category, 'Municipal Services'),
                'created_day': random.randint(1, 365),
                'resolution_days': days
            })

# Combine with original
augmented_df = pd.DataFrame(augmented_rows)
combined = pd.concat([data, augmented_df], ignore_index=True)

# Shuffle
combined = combined.sample(frac=1, random_state=42).reset_index(drop=True)

print(f"Augmented dataset: {len(combined)} samples (+{len(augmented_rows)} new)")
print(f"\nCategory distribution:")
print(combined['category'].value_counts())

# Save augmented dataset
combined.to_csv("../data/complaints_augmented.csv", index=False)
print(f"\nSaved to: data/complaints_augmented.csv")

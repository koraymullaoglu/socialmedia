CREATE TABLE Communities (
    community_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    creator_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    privacy_id INT REFERENCES PrivacyTypes(privacy_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
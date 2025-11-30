CREATE TABLE PrivacyTypes (
    privacy_id SERIAL PRIMARY KEY,
    privacy_name VARCHAR(20) UNIQUE NOT NULL
);
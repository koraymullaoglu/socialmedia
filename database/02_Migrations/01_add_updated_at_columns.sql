-- Add updated_at columns to Posts, Users, and Comments tables
-- These columns will track when records are last modified

ALTER TABLE Posts 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE Users 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE Comments 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Initialize updated_at with created_at values for existing records
UPDATE Posts SET updated_at = created_at;
UPDATE Users SET updated_at = created_at;
UPDATE Comments SET updated_at = created_at;

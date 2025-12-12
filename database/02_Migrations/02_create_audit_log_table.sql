-- Create audit log table for tracking user deletions and other important events

CREATE TABLE AuditLog (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    user_id INT,
    username VARCHAR(50),
    email VARCHAR(100),
    record_data JSONB,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_by INT,
    reason TEXT
);

-- Create index for faster queries
CREATE INDEX idx_audit_log_table_operation ON AuditLog(table_name, operation);
CREATE INDEX idx_audit_log_user_id ON AuditLog(user_id);
CREATE INDEX idx_audit_log_deleted_at ON AuditLog(deleted_at);

from tests.base_test import BaseTest
from sqlalchemy import text
from api.extensions import db

class TestDatabaseIndexes(BaseTest):
    def test_message_indexes_exist(self):
        """Verify that the new Message indexes exist in pg_indexes"""
        
        # Query postgres system catalog
        query = text("""
            SELECT indexname, indexdef 
            FROM pg_indexes 
            WHERE tablename = 'messages'
        """)
        
        result = db.session.execute(query).fetchall()
        indexes = {row.indexname: row.indexdef for row in result}
        

        
        # Check for standard indexes
        assert 'idx_messages_sender_id' in indexes, "Missing index: idx_messages_sender_id"
        assert 'idx_messages_receiver_id' in indexes, "Missing index: idx_messages_receiver_id"
        
        # Check for partial index
        assert 'idx_messages_unread' in indexes, "Missing index: idx_messages_unread"
        assert 'WHERE (is_read = false)' in indexes['idx_messages_unread'], "idx_messages_unread should be a partial index"

    def test_audit_log_indexes_exist(self):
        """Verify AuditLog indexes just in case"""
        query = text("SELECT indexname FROM pg_indexes WHERE tablename = 'auditlog'")
        result = db.session.execute(query).fetchall()
        index_names = [row.indexname for row in result]
        
        assert 'idx_audit_log_user_id' in index_names

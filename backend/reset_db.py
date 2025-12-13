import os
import sys
from sqlalchemy import create_engine, text

# Add current directory to path so we can import api
sys.path.append(os.getcwd())

from api.config import Config

def reset_db():
    print("Resetting database using SQLAlchemy...")
    
    # Get URI from Config
    uri = Config.SQLALCHEMY_DATABASE_URI
    
    try:
        engine = create_engine(uri)
        connection = engine.connect()
        
        # Read init.sql
        print("Reading init.sql...")
        with open('init.sql', 'r') as f:
            sql_content = f.read()
            
        # Execute SQL content
        # We might need to handle transaction commit manually
        trans = connection.begin()
        try:
            connection.execute(text(sql_content))
            trans.commit()
            print("Database reset successful!")
        except Exception as e:
            trans.rollback()
            print(f"Error executing SQL: {e}")
            sys.exit(1)
        finally:
            connection.close()
            
    except Exception as e:
        print(f"Connection error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    reset_db()

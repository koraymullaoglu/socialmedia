import unittest
import sys
import os

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def run_tests():
    # Discover and run tests
    loader = unittest.TestLoader()
    start_dir = 'backend/tests'
    if not os.path.exists(start_dir):
        # If running from inside backend
        start_dir = 'tests'
        
    suite = loader.discover(start_dir, pattern='test_*.py')
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    if not result.wasSuccessful():
        sys.exit(1)

if __name__ == '__main__':
    run_tests()

"""Tests for CommunityRepository and CommunityService"""

import sys
import os

# Add parent directory (backend/) to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime

from api.entities.entities import Community, CommunityMember
from api.repositories.community_repository import CommunityRepository
from api.services.community_service import CommunityService


class TestCommunityRepository(unittest.TestCase):
    """Test cases for CommunityRepository"""

    def setUp(self):
        """Set up test fixtures"""
        self.mock_db = MagicMock()
        self.repo = CommunityRepository()
        self.repo.db = self.mock_db

    def test_create_community(self):
        """Test creating a new community"""
        # Arrange
        community = Community(
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1
        )
        
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.name = "Test Community"
        mock_row.description = "Test Description"
        mock_row.creator_id = 1
        mock_row.privacy_id = 1
        mock_row.created_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.create(community)
        
        # Assert
        self.assertEqual(result.name, "Test Community")
        self.assertEqual(result.creator_id, 1)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_create_community passed")

    def test_get_by_id(self):
        """Test getting community by ID"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.name = "Test Community"
        mock_row.description = "Test Description"
        mock_row.creator_id = 1
        mock_row.privacy_id = 1
        mock_row.created_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.get_by_id(1)
        
        # Assert
        self.assertIsNotNone(result)
        self.assertEqual(result.community_id, 1)
        self.assertEqual(result.name, "Test Community")
        print("✅ test_get_by_id passed")

    def test_get_all(self):
        """Test getting all communities with pagination"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.name = "Community 1"
        mock_row.description = "Description 1"
        mock_row.creator_id = 1
        mock_row.privacy_id = 1
        mock_row.created_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchall.return_value = [mock_row]
        
        # Act
        result = self.repo.get_all(limit=50, offset=0)
        
        # Assert
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].name, "Community 1")
        print("✅ test_get_all passed")

    def test_search_communities(self):
        """Test searching communities"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.name = "Python Lovers"
        mock_row.description = "A community for Python enthusiasts"
        mock_row.creator_id = 1
        mock_row.privacy_id = 1
        mock_row.created_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchall.return_value = [mock_row]
        
        # Act
        result = self.repo.search("Python", limit=50, offset=0)
        
        # Assert
        self.assertEqual(len(result), 1)
        self.assertIn("Python", result[0].name)
        print("✅ test_search_communities passed")

    def test_update_community(self):
        """Test updating a community"""
        # Arrange
        community = Community(
            community_id=1,
            name="Updated Community",
            description="Updated Description",
            creator_id=1,
            privacy_id=2
        )
        
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.name = "Updated Community"
        mock_row.description = "Updated Description"
        mock_row.creator_id = 1
        mock_row.privacy_id = 2
        mock_row.created_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.update(community)
        
        # Assert
        self.assertEqual(result.name, "Updated Community")
        self.assertEqual(result.privacy_id, 2)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_update_community passed")

    def test_delete_community(self):
        """Test deleting a community"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.delete(1)
        
        # Assert
        self.assertTrue(result)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_delete_community passed")

    def test_add_member(self):
        """Test adding a member to a community"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.user_id = 2
        mock_row.role_id = 3
        mock_row.joined_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.add_member(community_id=1, user_id=2, role_id=3)
        
        # Assert
        self.assertEqual(result.community_id, 1)
        self.assertEqual(result.user_id, 2)
        self.assertEqual(result.role_id, 3)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_add_member passed")

    def test_remove_member(self):
        """Test removing a member from a community"""
        # Arrange
        mock_row = MagicMock()
        mock_row.user_id = 2
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.remove_member(community_id=1, user_id=2)
        
        # Assert
        self.assertTrue(result)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_remove_member passed")

    def test_update_member_role(self):
        """Test updating a member's role"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.user_id = 2
        mock_row.role_id = 2
        mock_row.joined_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.update_member_role(community_id=1, user_id=2, role_id=2)
        
        # Assert
        self.assertEqual(result.role_id, 2)
        self.mock_db.session.commit.assert_called_once()
        print("✅ test_update_member_role passed")

    def test_get_members(self):
        """Test getting all members of a community"""
        # Arrange
        mock_row = MagicMock()
        mock_row._mapping = {
            'community_id': 1,
            'user_id': 2,
            'role_id': 3,
            'joined_at': datetime.now(),
            'username': 'testuser',
            'email': 'test@example.com',
            'bio': 'Test bio',
            'profile_picture_url': None,
            'role_name': 'member'
        }
        
        self.mock_db.session.execute.return_value.fetchall.return_value = [mock_row]
        
        # Act
        result = self.repo.get_members(community_id=1, limit=50, offset=0)
        
        # Assert
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['username'], 'testuser')
        self.assertEqual(result[0]['role_name'], 'member')
        print("✅ test_get_members passed")

    def test_get_member(self):
        """Test getting a specific member"""
        # Arrange
        mock_row = MagicMock()
        mock_row.community_id = 1
        mock_row.user_id = 2
        mock_row.role_id = 3
        mock_row.joined_at = datetime.now()
        
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.get_member(community_id=1, user_id=2)
        
        # Assert
        self.assertIsNotNone(result)
        self.assertEqual(result.user_id, 2)
        print("✅ test_get_member passed")

    def test_get_user_communities(self):
        """Test getting all communities a user is a member of"""
        # Arrange
        mock_row = MagicMock()
        mock_row._mapping = {
            'community_id': 1,
            'name': 'Test Community',
            'description': 'Test Description',
            'creator_id': 1,
            'privacy_id': 1,
            'created_at': datetime.now(),
            'role_id': 3,
            'joined_at': datetime.now(),
            'role_name': 'member'
        }
        
        self.mock_db.session.execute.return_value.fetchall.return_value = [mock_row]
        
        # Act
        result = self.repo.get_user_communities(user_id=2)
        
        # Assert
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['name'], 'Test Community')
        self.assertEqual(result[0]['role_name'], 'member')
        print("✅ test_get_user_communities passed")

    def test_count_members(self):
        """Test counting members in a community"""
        # Arrange
        mock_row = MagicMock()
        mock_row.count = 5
        self.mock_db.session.execute.return_value.fetchone.return_value = mock_row
        
        # Act
        result = self.repo.count_members(community_id=1)
        
        # Assert
        self.assertEqual(result, 5)
        print("✅ test_count_members passed")


class TestCommunityService(unittest.TestCase):
    """Test cases for CommunityService"""

    def setUp(self):
        """Set up test fixtures"""
        self.service = CommunityService()
        self.mock_repo = MagicMock()
        self.service.community_repository = self.mock_repo

    def test_create_community_success(self):
        """Test successful community creation with auto-admin role"""
        # Arrange
        created_community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        self.mock_repo.create.return_value = created_community
        self.mock_repo.add_member.return_value = CommunityMember(
            community_id=1,
            user_id=1,
            role_id=1,
            joined_at=datetime.now()
        )
        
        # Act
        result = self.service.create_community(
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1
        )
        
        # Assert
        self.assertEqual(result.name, "Test Community")
        self.mock_repo.create.assert_called_once()
        self.mock_repo.add_member.assert_called_once_with(1, 1, role_id=1)
        print("✅ test_create_community_success passed")

    def test_create_community_validation_error(self):
        """Test community creation with validation error"""
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.create_community(
                name="AB",  # Too short
                description="Test",
                creator_id=1,
                privacy_id=1
            )
        
        self.assertIn("at least 3 characters", str(context.exception))
        print("✅ test_create_community_validation_error passed")

    def test_get_community(self):
        """Test getting a community by ID"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        self.mock_repo.get_by_id.return_value = community
        
        # Act
        result = self.service.get_community(1)
        
        # Assert
        self.assertEqual(result.community_id, 1)
        self.mock_repo.get_by_id.assert_called_once_with(1)
        print("✅ test_get_community passed")

    def test_update_community_as_admin(self):
        """Test updating community as admin"""
        # Arrange
        community = Community(
            community_id=1,
            name="Old Name",
            description="Old Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        member = CommunityMember(
            community_id=1,
            user_id=1,
            role_id=1,  # admin
            joined_at=datetime.now()
        )
        
        updated_community = Community(
            community_id=1,
            name="New Name",
            description="New Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = member
        self.mock_repo.update.return_value = updated_community
        
        # Act
        result = self.service.update_community(
            community_id=1,
            user_id=1,
            name="New Name",
            description="New Description"
        )
        
        # Assert
        self.assertEqual(result.name, "New Name")
        self.mock_repo.update.assert_called_once()
        print("✅ test_update_community_as_admin passed")

    def test_update_community_as_non_admin(self):
        """Test updating community as non-admin (should fail)"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        member = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,  # regular member
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = member
        
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.update_community(
                community_id=1,
                user_id=2,
                name="New Name"
            )
        
        self.assertIn("Only admins", str(context.exception))
        print("✅ test_update_community_as_non_admin passed")

    def test_delete_community_as_admin(self):
        """Test deleting community as admin"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        member = CommunityMember(
            community_id=1,
            user_id=1,
            role_id=1,  # admin
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = member
        self.mock_repo.delete.return_value = True
        
        # Act
        result = self.service.delete_community(community_id=1, user_id=1)
        
        # Assert
        self.assertTrue(result)
        self.mock_repo.delete.assert_called_once_with(1)
        print("✅ test_delete_community_as_admin passed")

    def test_join_community(self):
        """Test joining a community"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        member = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,  # member
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = None  # Not a member yet
        self.mock_repo.add_member.return_value = member
        
        # Act
        result = self.service.join_community(community_id=1, user_id=2)
        
        # Assert
        self.assertEqual(result['user_id'], 2)
        self.assertEqual(result['role_id'], 3)
        self.mock_repo.add_member.assert_called_once_with(1, 2, role_id=3)
        print("✅ test_join_community passed")

    def test_join_community_already_member(self):
        """Test joining community when already a member"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        existing_member = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = existing_member
        
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.join_community(community_id=1, user_id=2)
        
        self.assertIn("already a member", str(context.exception))
        print("✅ test_join_community_already_member passed")

    def test_leave_community(self):
        """Test leaving a community"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        member = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,  # regular member
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = member
        self.mock_repo.remove_member.return_value = True
        
        # Act
        result = self.service.leave_community(community_id=1, user_id=2)
        
        # Assert
        self.assertTrue(result)
        self.mock_repo.remove_member.assert_called_once_with(1, 2)
        print("✅ test_leave_community passed")

    def test_remove_member_as_admin(self):
        """Test removing a member as admin"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        requester = CommunityMember(
            community_id=1,
            user_id=1,
            role_id=1,  # admin
            joined_at=datetime.now()
        )
        
        target = CommunityMember(
            community_id=1,
            user_id=3,
            role_id=3,  # member
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.side_effect = [requester, target]
        self.mock_repo.remove_member.return_value = True
        
        # Act
        result = self.service.remove_member(community_id=1, user_id=1, target_user_id=3)
        
        # Assert
        self.assertTrue(result)
        self.mock_repo.remove_member.assert_called_once_with(1, 3)
        print("✅ test_remove_member_as_admin passed")

    def test_remove_member_as_regular_member(self):
        """Test removing a member as regular member (should fail)"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        requester = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,  # regular member
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = requester
        
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.remove_member(community_id=1, user_id=2, target_user_id=3)
        
        self.assertIn("Only admins or moderators", str(context.exception))
        print("✅ test_remove_member_as_regular_member passed")

    def test_change_member_role_as_admin(self):
        """Test changing member role as admin"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        requester = CommunityMember(
            community_id=1,
            user_id=1,
            role_id=1,  # admin
            joined_at=datetime.now()
        )
        
        target = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=3,  # member
            joined_at=datetime.now()
        )
        
        updated_target = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=2,  # moderator
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.side_effect = [requester, target]
        self.mock_repo.update_member_role.return_value = updated_target
        
        # Act
        result = self.service.change_member_role(
            community_id=1,
            user_id=1,
            target_user_id=2,
            new_role_id=2
        )
        
        # Assert
        self.assertEqual(result['role_id'], 2)
        self.mock_repo.update_member_role.assert_called_once_with(1, 2, 2)
        print("✅ test_change_member_role_as_admin passed")

    def test_change_member_role_as_non_admin(self):
        """Test changing member role as non-admin (should fail)"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        requester = CommunityMember(
            community_id=1,
            user_id=2,
            role_id=2,  # moderator (not admin)
            joined_at=datetime.now()
        )
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_member.return_value = requester
        
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.change_member_role(
                community_id=1,
                user_id=2,
                target_user_id=3,
                new_role_id=1
            )
        
        self.assertIn("Only admins can change member roles", str(context.exception))
        print("✅ test_change_member_role_as_non_admin passed")

    def test_get_members(self):
        """Test getting community members"""
        # Arrange
        community = Community(
            community_id=1,
            name="Test Community",
            description="Test Description",
            creator_id=1,
            privacy_id=1,
            created_at=datetime.now()
        )
        
        members = [
            {
                'user_id': 1,
                'username': 'admin_user',
                'role_id': 1,
                'role_name': 'admin'
            },
            {
                'user_id': 2,
                'username': 'member_user',
                'role_id': 3,
                'role_name': 'member'
            }
        ]
        
        self.mock_repo.get_by_id.return_value = community
        self.mock_repo.get_members.return_value = members
        
        # Act
        result = self.service.get_members(community_id=1, limit=50, offset=0)
        
        # Assert
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['username'], 'admin_user')
        print("✅ test_get_members passed")

    def test_search_communities(self):
        """Test searching communities"""
        # Arrange
        communities = [
            Community(
                community_id=1,
                name="Python Lovers",
                description="Python enthusiasts",
                creator_id=1,
                privacy_id=1,
                created_at=datetime.now()
            )
        ]
        
        self.mock_repo.search.return_value = communities
        
        # Act
        result = self.service.search_communities("Python", limit=50, offset=0)
        
        # Assert
        self.assertEqual(len(result), 1)
        self.assertIn("Python", result[0].name)
        self.mock_repo.search.assert_called_once_with("Python", 50, 0)
        print("✅ test_search_communities passed")

    def test_search_communities_empty_term(self):
        """Test searching with empty search term (should fail)"""
        # Act & Assert
        with self.assertRaises(ValueError) as context:
            self.service.search_communities("", limit=50, offset=0)
        
        self.assertIn("Search term is required", str(context.exception))
        print("✅ test_search_communities_empty_term passed")

    def test_get_user_communities(self):
        """Test getting user's communities"""
        # Arrange
        user_communities = [
            {
                'community_id': 1,
                'name': 'Community 1',
                'role_id': 1,
                'role_name': 'admin'
            },
            {
                'community_id': 2,
                'name': 'Community 2',
                'role_id': 3,
                'role_name': 'member'
            }
        ]
        
        self.mock_repo.get_user_communities.return_value = user_communities
        
        # Act
        result = self.service.get_user_communities(user_id=1)
        
        # Assert
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['role_name'], 'admin')
        self.mock_repo.get_user_communities.assert_called_once_with(1)
        print("✅ test_get_user_communities passed")


def run_tests():
    """Run all test suites"""
    print("\n" + "=" * 60)
    print("RUNNING COMMUNITY MODULE TESTS")
    print("=" * 60 + "\n")
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestCommunityRepository))
    suite.addTests(loader.loadTestsFromTestCase(TestCommunityService))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print("=" * 60 + "\n")
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)

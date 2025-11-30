CREATE TABLE Follows (
    follower_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    following_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    status_id INT REFERENCES FollowStatus(status_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, following_id)
);
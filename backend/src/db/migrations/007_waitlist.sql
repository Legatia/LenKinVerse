-- Waitlist table for landing page email collection
CREATE TABLE IF NOT EXISTS waitlist (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    signed_up_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(100) DEFAULT 'landing-page',
    referrer VARCHAR(500),
    ip_address INET,
    user_agent TEXT,
    notified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster email lookups
CREATE INDEX idx_waitlist_email ON waitlist(email);

-- Index for signup date queries
CREATE INDEX idx_waitlist_signup_date ON waitlist(signed_up_at DESC);

-- Index for notification status
CREATE INDEX idx_waitlist_notified ON waitlist(notified) WHERE notified = FALSE;

COMMENT ON TABLE waitlist IS 'Email waitlist for early access and beta invites';
COMMENT ON COLUMN waitlist.email IS 'User email address (normalized to lowercase)';
COMMENT ON COLUMN waitlist.signed_up_at IS 'Timestamp when user joined waitlist';
COMMENT ON COLUMN waitlist.source IS 'Source of signup (landing-page, twitter, discord, etc)';
COMMENT ON COLUMN waitlist.notified IS 'Whether user has been notified about launch/beta';

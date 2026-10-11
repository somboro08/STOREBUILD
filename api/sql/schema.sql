CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT UNIQUE NOT NULL,
  phone_display TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS otps (
  phone TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS channels (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  zone TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  color BIGINT NOT NULL DEFAULT 4278225275,
  logo_url TEXT,
  delivers BOOLEAN NOT NULL DEFAULT false,
  delivery_fee INTEGER NOT NULL DEFAULT 0,
  verified BOOLEAN NOT NULL DEFAULT false,
  created TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS follows (
  user_id TEXT NOT NULL,
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, channel_id)
);

CREATE TABLE IF NOT EXISTS posts (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  type INTEGER NOT NULL DEFAULT 0,
  time TEXT NOT NULL DEFAULT '',
  text TEXT NOT NULL DEFAULT '',
  title TEXT,
  quote TEXT,
  category TEXT,
  price INTEGER,
  stock INTEGER,
  variants JSONB NOT NULL DEFAULT '[]',
  color BIGINT NOT NULL DEFAULT 4281545523,
  bold BOOLEAN NOT NULL DEFAULT false,
  sold BOOLEAN NOT NULL DEFAULT false,
  image_url TEXT,
  extra_urls JSONB NOT NULL DEFAULT '[]',
  video_url TEXT,
  forwards INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS posts_channel_idx ON posts (channel_id, created_at);

CREATE TABLE IF NOT EXISTS post_reactions (
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS favorites (
  user_id TEXT NOT NULL,
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS payments (
  reference TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  phone TEXT NOT NULL,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  external_id TEXT,
  refunded BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  ref TEXT PRIMARY KEY,
  buyer_id TEXT NOT NULL,
  provider TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  buyer_name TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  delivery BOOLEAN NOT NULL DEFAULT false,
  status INTEGER NOT NULL DEFAULT 0,
  refunded BOOLEAN NOT NULL DEFAULT false,
  items_total INTEGER NOT NULL,
  fee_total INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL,
  fees JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_lines (
  id SERIAL PRIMARY KEY,
  order_ref TEXT NOT NULL REFERENCES orders(ref) ON DELETE CASCADE,
  channel_id TEXT NOT NULL,
  post_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  unit_price INTEGER NOT NULL,
  qty INTEGER NOT NULL,
  variant TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS order_lines_ref_idx ON order_lines (order_ref);
CREATE INDEX IF NOT EXISTS order_lines_channel_idx ON order_lines (channel_id);

CREATE TABLE IF NOT EXISTS order_reviewed (
  order_ref TEXT NOT NULL REFERENCES orders(ref) ON DELETE CASCADE,
  post_id TEXT NOT NULL,
  PRIMARY KEY (order_ref, post_id)
);

CREATE TABLE IF NOT EXISTS reviews (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  post_id TEXT NOT NULL DEFAULT '',
  author_id TEXT NOT NULL,
  author TEXT NOT NULL DEFAULT '',
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  text TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  text TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS payouts (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'demandé',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reports (
  id SERIAL PRIMARY KEY,
  channel_id TEXT NOT NULL,
  reporter_id TEXT NOT NULL,
  reporter_name TEXT NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notices_user_idx ON notices (user_id, created_at);

CREATE TABLE IF NOT EXISTS ops (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

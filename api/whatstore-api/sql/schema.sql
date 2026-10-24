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

-- ---- Catalogue physique et stock
CREATE TABLE IF NOT EXISTS catalog_groups (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  parent_id TEXT,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS catalog_items (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  group_id TEXT,
  code TEXT NOT NULL,
  barcodes JSONB NOT NULL DEFAULT '[]',
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  usage TEXT NOT NULL DEFAULT '',
  details JSONB NOT NULL DEFAULT '[]',
  location TEXT NOT NULL DEFAULT '',
  unit TEXT NOT NULL DEFAULT 'pièce',
  variant TEXT NOT NULL DEFAULT '',
  category TEXT,
  price INTEGER NOT NULL DEFAULT 0,
  cost INTEGER NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  low_stock INTEGER NOT NULL DEFAULT 3,
  image_urls JSONB NOT NULL DEFAULT '[]',
  post_id TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (channel_id, code)
);
CREATE INDEX IF NOT EXISTS catalog_items_channel_idx ON catalog_items (channel_id);
CREATE INDEX IF NOT EXISTS catalog_items_post_idx ON catalog_items (post_id);

CREATE TABLE IF NOT EXISTS catalog_codes (
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  PRIMARY KEY (channel_id, code)
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  channel_id TEXT NOT NULL,
  delta INTEGER NOT NULL,
  kind TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  by_name TEXT NOT NULL DEFAULT '',
  balance_after INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stock_movements_item_idx ON stock_movements (item_id, created_at);

-- ---- Phase 2 / 3 : équipe, caisse, achats, réservations, alertes, demande, registre partagé
CREATE TABLE IF NOT EXISTS channel_members (
  channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL CHECK (role IN ('manager','cashier','stock')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (channel_id, phone)
);

CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  cashier_id TEXT NOT NULL,
  cashier TEXT NOT NULL DEFAULT '',
  total INTEGER NOT NULL,
  cost_total INTEGER NOT NULL DEFAULT 0,
  method TEXT NOT NULL DEFAULT 'Espèces',
  note TEXT NOT NULL DEFAULT '',
  customer_phone TEXT NOT NULL DEFAULT '',
  voided BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sales_channel_idx ON sales (channel_id, created_at);

CREATE TABLE IF NOT EXISTS sale_lines (
  id SERIAL PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  qty INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  unit_cost INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS purchases (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  supplier TEXT NOT NULL DEFAULT '',
  extra_costs INTEGER NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  created_by TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_lines (
  id SERIAL PRIMARY KEY,
  purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL,
  qty INTEGER NOT NULL,
  unit_cost INTEGER NOT NULL,
  landed_cost INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS reservations (
  id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  qty INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS stock_alerts (
  item_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (item_id, user_id)
);

CREATE TABLE IF NOT EXISTS demand_terms (
  channel_id TEXT NOT NULL,
  term TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 1,
  last_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (channel_id, term)
);

CREATE TABLE IF NOT EXISTS product_registry (
  barcode TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  usage TEXT NOT NULL DEFAULT '',
  image_url TEXT,
  uses INTEGER NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id VARCHAR(64) PRIMARY KEY, product VARCHAR(64) NOT NULL,
  quantity INTEGER NOT NULL, status VARCHAR(32) NOT NULL
);
CREATE TABLE IF NOT EXISTS inventory (
  product_id VARCHAR(64) PRIMARY KEY, available INTEGER NOT NULL,
  warehouse VARCHAR(64) NOT NULL, last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO orders (id,product,quantity,status) VALUES ('ord-001','LAPTOP-X1',1,'delivered') ON CONFLICT (id) DO NOTHING;
INSERT INTO inventory (product_id,available,warehouse) VALUES ('LAPTOP-X1',15,'BOG-01') ON CONFLICT (product_id) DO NOTHING;

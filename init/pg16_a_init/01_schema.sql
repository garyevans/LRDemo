CREATE TABLE IF NOT EXISTS note (
    pk  bigint PRIMARY KEY,
    note text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
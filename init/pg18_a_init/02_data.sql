INSERT INTO note (pk, note)
VALUES
  (1, 'Initial Row on instance a')
ON CONFLICT (pk) DO NOTHING;
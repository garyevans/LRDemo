CREATE SUBSCRIPTION sub_b
  CONNECTION 'host=pg18_a port=5432 dbname=demo user=replicator password=replicator_pw'
  PUBLICATION pub_a
WITH (
  create_slot = true,
  copy_data = true,
  slot_name = 'slot_b_from_a',
  enabled = true
);
#!/usr/bin/env bash
set -e

# Allow replication + normal connections from docker network
echo "host replication replicator 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host all         replicator 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
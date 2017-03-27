#!/usr/bin/env bash

if [ $MODE = "master" ]; then
	echo "Setting up server as master..."

	# Create archive directory
	mkdir -p $PGDATA/archive

	# Give POSTGRES_USER replication permissions
	cat <<- EOF >> ${PGDATA}/pg_hba.conf
	host replication ${POSTGRES_USER} 0.0.0.0/0 md5
	EOF

	# Configure replication configuration
	cat <<- EOF >> ${PGDATA}/postgresql.conf
	wal_level = hot_standby
	hot_standby = on
	archive_mode = on
	archive_command = 'test ! -f $PGDATA/archive/%f && cp %p $PGDATA/archive/%f'
	max_wal_senders = $PG_MAX_WAL_SENDERS
	wal_keep_segments = $PG_WAL_KEEP_SEGMENTS
	EOF

elif [ $MODE = "slave" ]; then
	echo "Setting up server as slave..."

	pg_ctl stop

	# Setup .pgpass file
	echo "$REPLICATE_FROM:5432:*:$POSTGRES_USER:$POSTGRES_PASSWORD" > $PGPASSFILE
	chmod 0600 $PGPASSFILE

	# Wait for postgresql-master to be ready for connections
	until pg_isready --dbname=hardly --host=$REPLICATE_FROM --username=$POSTGRES_USER --timeout=2
	do
		echo "Waiting for master to startup..."
		sleep 2s
	done

	# Backup current data
	mv $PGDATA $PGDATA-backup

	# Take initial backup from postgresql-master
	until pg_basebackup -h ${REPLICATE_FROM} -D ${PGDATA} -U ${POSTGRES_USER} -vP -w --xlog-method=stream
	do
		echo "Waiting for backup to complete..."
		sleep 2s
	done

	# Enable replication
	cat <<- EOF >> ${PGDATA}/postgresql.conf
	hot_standby = on
	EOF

	cat <<- EOF >> ${PGDATA}/recovery.conf
	standby_mode = on
	primary_conninfo = 'host=${REPLICATE_FROM} port=5432 user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}'
	trigger_file = '/tmp/touch_me_to_promote_me_to_master'
	EOF

	# Restart server
	pg_ctl -w start
fi

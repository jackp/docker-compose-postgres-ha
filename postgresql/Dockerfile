FROM postgres:9.6

# Set environment
ENV POSTGRES_USER ${POSTGRES_USER:-hardly}
ENV POSTGRES_DB hardly
ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 32
ENV PGDATA /var/lib/postgresql/data/pgdata
ENV PGPASSFILE /var/lib/postgresql/.pgpass

# Copy initialization files
COPY ./init /docker-entrypoint-initdb.d/


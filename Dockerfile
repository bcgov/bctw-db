FROM postgres:12

# This is our time zone
ENV TZ America/Vancouver

# install PostGIS
RUN apt-get update
RUN apt-get install -y --no-install-recommends postgresql-12-postgis-3
RUN apt-get install -y --no-install-recommends postgresql-12-postgis-3-dbgsym
RUN apt-get install -y --no-install-recommends postgresql-12-postgis-3-scripts

# Set the time zone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Load the PostGIS extension into the database
COPY load_postgis.sql docker-entrypoint-initdb.d/load_postgis.sql

EXPOSE 5432

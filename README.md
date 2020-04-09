# Spatial Database Application
## British Columbia Telemetry Warehouse

### Downloading and Building
```bash
git clone https://github.com/bcgov/bctw-db.git
cd bctw-db
docker build --tag bctw-db:1.0 .
```

### Running
If you have environment variables currently set for the database environment you can do the following. Otherwise substitute in your configuration.
```bash
docker run \
  --publish 5432:5432 \
  --detach \
  --name bctw-db \
  --env POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --env POSTGRES_USER=$POSTGRES_USER \
  --env POSTGRES_DB=$POSTGRES_DB \
  bctw-db:1.0
```

Now you can connect localy.
```bash
psql -h localhost -p 5432 $POSTGRES_DB $POSTGRES_USER
```


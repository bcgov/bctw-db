![Lifecycle: Maturing](https://img.shields.io/badge/Lifecycle-Maturing-007EC6)

## British Columbia Telemetry Warehouse

Minimal Postresql 12 and PostGIS 3.0 Docker setup.

### Downloading and Building
```bash
git clone https://github.com/bcgov/bctw-db.git
cd bctw-db
docker build --tag bctw-db:1.0 .
```

### Running Locally
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

Now you can connect locally.
```bash
psql -h localhost -p 5432 $POSTGRES_DB $POSTGRES_USER
```

### Running in OpenShift
```bash
cd bctw-db
oc new-app --name=bctw-db openshift/test-bctw-db.yaml
```

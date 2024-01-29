# TechStack-Germany
Standard Infrastructure and Technology Stack used for OMOP CDM implementations in Germany

Versions of included software

| Application | Version    |
|-------------|------------|
| Atlas       | 2.14.0     |
| WebAPI      | 2.14.0     |
| Postgres    | 16         |
| OMOP CDM    | 5.3.1      |
| GermanVocab | 2023-02-16 |
---

## Step 1 - Configuration

The included [docker-compose.yml](docker-compose.yml) starts a Postgres instance with a default database called `ohdsi` as well as the OHDSI WebAPI and Atlas. The DB is initialized with a dedicated `ohdsi_admin_user` with full read and write access to the `ohdsi` DB.

You will have to manually specify a password for both the `postgres` as well as the `ohdsi_admin_user`. You can specify the environment variables `POSTGRES_PASSWORD` and `OHDSI_ADMIN_PASSWORD` to set them.

First, copy the **sample.env** file to **.env**.

```sh
cp sample.env .env
```

Now you can adjust the credentials of the users in the **.env** file.

The default settings of the deployment will work for testing purposes on a local host. If you want to connect Atlas and the WebAPI via DNS entries, you will have to adjust the following lines:

### config-local.js

`url: 'http://localhost:9876/WebAPI/'`

### docker-compose.yml

`SECURITY_ORIGIN: "http://localhost:8080"`

## Step 2 - Start the Database and OHDSI container

```sh
docker-compose up -d
```

Note that this uses [.env](.env) to populate `POSTGRES_PASSWORD` and `OHDSI_ADMIN_PASSWORD` automaticaly.

## Step 3 - Initialize the CDM Schema

```sh
# Load the OHDSI_ADMIN_PASSWORD from sample.env in the current shell environment
source .env
# Run the init container
docker run --rm -it --network=$DOCKER_NETWORK \
  -e PGPASSWORD=$OHDSI_ADMIN_PASSWORD \
  -e PGUSER=ohdsi_admin_user \
  -e PGHOST=omopdb \
  -e PGDATABASE=ohdsi \
  -e WEBAPI_URL=http://webapi.$DOCKER_NETWORK:8080/WebAPI \
  -e SETUP_CDS=true \
  -e SETUP_SYNPUF=false \
  <<IMAGE>>
```

You should only run this init container once. In case you have to init the database once again, you have to remove the volumes of the corresponding containers as well: `docker-compose down -v`

The init container has the following configuration options:

| Environment variable | Description                                                                                                                                                                         | Default    |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ---------- |
| `SETUP_CDS`          | Set to `false` if a CDM schema containing the CDS vocabs data should not be setup.                                                                                                  | `false`    |
| `SETUP_SYNPUF`       | Set to `true` if a CDM schema containing the SynPUF 1K data should be setup.                                                                                                        | `false`    |
| `WEBAPI_URL`         | Required. The base URL of the WebAPI. Used to check if the WebAPI's internal DB migrations have completed.                                                                          | `""`       |
| `PGHOST`             | Required. Hostname of the Postgres DB. Note that all `PG*` variables can be used, see: <https://www.postgresql.org/docs/13/libpq-envars.html>.                                      | `""`       |
| `PGUSER`             | Username used to connect to the DB specified with `PGHOST` DB                                                                                                                       | `postgres` |
| `PGPASSWORD`         | Required. Password of the `PGUSER` user DB                                                                                                                                          | `""`       |
| `PGDATABASE`         | Name of the database where the CDS CDM should be created. Currently, the init job requires both the WebAPI (the `ohdsi` schema) and the CDM to be placed within the same database.  | `ohdsi`    |

## Step 4 Check the installation

You can access Atlas and the WebAPI like this:

| Application | URL                                 |
| ----------- |-------------------------------------|
| **Atlas**   | <http://localhost:8080/atlas>       |
| **WebAPI**  | <http://localhost:9876/WebAPI/info> |

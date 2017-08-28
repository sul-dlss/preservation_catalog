[![Build Status](https://travis-ci.org/sul-dlss/preservation_core_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_core_catalog)

[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_core_catalog/badge.svg)](https://coveralls.io/github/sul-dlss/preservation_core_catalog)

[![Build Status](https://travis-ci.org/sul-dlss/preservation_core_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_core_catalog)

[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_core_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_core_catalog)


# README


Rails application with fixity data and object provenance supporting preservation object storage audit services


This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

### Setting up PostgreSQL

#### 1. Installing Postgres

If you use homebrew you can install PostgreSQL by typing  `brew install postgresql` into the command line.

Make sure Postgres starts every time your computer starts up.
`brew services start postgresql`

Check to see if Postgres is installed:
`postgres -V`

and that it's accepting connections:
`pg_isready`

#### 2. Configuring Postgres

Use the `psql` utility, which lets you carry out admin functions:
* Enter `psql postgres` into the command line.
* Create the preservation core user and grant it the privileges it needs by entering the following commands in psql:
```sql
CREATE USER preservation_core_catalog;
ALTER USER preservation_core_catalog CREATEDB;
CREATE DATABASE preservation_core_catalog;
ALTER DATABASE preservation_core_catalog OWNER TO preservation_core_catalog;
GRANT ALL PRIVILEGES ON DATABASE preservation_core_catalog TO preservation_core_catalog;
```

For more info on postgres commands, see https://www.postgresql.org/docs/

[![Build Status](https://travis-ci.org/sul-dlss/preservation_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_catalog)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_catalog/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/preservation_catalog?branch=master)
[![Dependency Status](https://gemnasium.com/badges/github.com/sul-dlss/preservation_catalog.svg)](https://gemnasium.com/github.com/sul-dlss/preservation_catalog)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)


# README


Rails application with fixity data and object provenance supporting preservation object storage audit services


## Configuration

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

Using the `psql` utility, run these two setup scripts from the command line, like so:
```sh
psql -f db/scripts/pres_setup.sql postgres
psql -f db/scripts/pres_test_setup.sql postgres
```

These scripts do the following for you:
* create the test and dev PostgreSQL users.
* create the test and dev databases.
* setup the needed ownership and permissions between the DBs and the users.

For more info on postgres commands, see https://www.postgresql.org/docs/


## Usage Instructions

### Seed the catalog

Seeding the catalog presumes an empty or nearly empty database -- otherwise running the seed task will throw `druid NOT expected to exist in catalog but was found` errors for each found object. You can monitor the progress of the seed task by tailing `log/production.log`, or by querying the database from Rails console using ActiveRecord. The seed task can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki/Stats) on the timing of past runs (and some suggested overview queries). You can expect profiling runs will add overhead. The following rake tasks should be run from the root directory of the project, with whatever `RAILS_ENV` is appropriate. Because the task can take days when run over all storage roots, consider running it in a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/).

Without profiling:
```ruby
RAILS_ENV=production bundle exec rake seed_catalog
```

With profiling:
```ruby
RAILS_ENV=production bundle exec rake seed_catalog[profile]
```
this will generate a log at, for example, `log/seed_from_disk2017-11-13T13:57:01.log`

As an alternative to `screen`, you can also run the task, with or without profiling, in the background under `nohup`. For example:

```ruby
RAILS_ENV=production nohup bundle exec rake seed_catalog &
```
By invoking commands via`nohup`, the invoked command doesn't get the kill signal when the terminal session that started it exits.  Output that would've gone to stdout is instead redirected to a file called `nohup.out` in the location from which the command was executed (here, the project root).

## Development

### Running Tests

To run the tests:

```sh
rake spec
```

## Deploying

Capistrano is used to deploy.

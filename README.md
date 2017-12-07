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
this will generate a log at, for example, `log/profile_flat_seed_catalog_for_all_storage_roots2017-11-13T13:57:01.log`

As an alternative to `screen`, you can also run the task, with or without profiling, in the background under `nohup`. For example:

```ruby
RAILS_ENV=production nohup bundle exec rake seed_catalog &
```
By invoking commands via`nohup`, the invoked command doesn't get the kill signal when the terminal session that started it exits.  Output that would've gone to stdout is instead redirected to a file called `nohup.out` in the location from which the command was executed (here, the project root).

#### Reset the catalog for re-seeding

WARNING! this will erase the catalog, and thus require re-seeding from scratch.  It is mostly intended for development purposes, and it is unlikely that you'll need to run this against production once the catalog is in regular use.

* Deploy the branch of the code with which you wish to seed, to the instance which you wish to seed (e.g. master to stage).
* Reset the database for that instance.  E.g., on production or stage:  `RAILS_ENV=production bundle exec rake db:reset`
  * note that if you do this in an env that sees itself as production (i.e. production or stage), you'll get a scary warning along the lines of:
  ```
  ActiveRecord::ProtectedEnvironmentError: You are attempting to run a destructive action against your 'production' database.
  If you are sure you want to continue, run the same command with the environment variable:
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  ```
  Basically an especially inconvenient confirmation dialogue.  For safety's sake, the full command that skips that warning can be constructed by the user as needed, so as to prevent unintentional copy/paste dismissal when the user might be administering multiple deployment environments simultaneously.  Inadvertent database wipes are no fun.
  * `db:reset` will make sure db is migrated and seeded.  If you want to be extra sure: `RAILS_ENV=[environment] bundle exec rake db:migrate db:seed`

### Drop or Populate the catalog for a single endpoint

- To run either of the rake tasks below, give the name of the enpdoint (from settings/development.yml) as an argument.

#### Drop all database entries:

```ruby
RAILS_ENV=production bundle exec rake drop[services-disk01]
```

#### Populate the catalog:

```ruby
RAILS_ENV=production bundle exec rake populate[services-disk01]
```


## Development

### Running Tests

To run the tests:

```sh
rake spec
```

## Deploying

Capistrano is used to deploy.

[![Build Status](https://travis-ci.org/sul-dlss/preservation_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_catalog)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_catalog/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/preservation_catalog?branch=master)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)

# README

Rails application to track, audit and replicate archival artifacts associated with SDR objects.

## Table of Contents

* [Getting Started](#getting-started)
    * [PostgreSQL](#postgreSQL)
    * [Redis](#redis)
* [Usage Instructions](#usage)
    * [Moab to Catalog](#m2c) (M2C) existence/version check
    * [Catalog to Moab](#c2m) (C2M) existence/version check
    * [Checksum Validation](#cv) (CV)
    * [Seed the catalog](#seeding)
    * [Audit Checks via Console](#console)
* [Development](#development)
* [Deploying](#deploying)

## <a name="getting-started"/>Getting Started

### <a name="postgresSQL"/>PostgreSQL

#### Installing Postgres

If you use homebrew you can install PostgreSQL with:
```sh
brew install postgresql
```

Make sure Postgres starts every time your computer starts up.
```sh
brew services start postgresql
```

Check to see if Postgres is installed with `postgres -V` and that it's accepting connections with `pg_isready`.

#### Configuring Postgres

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

### <a name="redis"/>Redis

Install and run `redis`.  For example, using `homebrew`:
```sh
brew install redis
brew services start redis
```

# <a name="usage"/>Usage Instructions

## <a name="general"/>General Info About Running These Rake Tasks

- Note: If the rake task takes multiple arguments, DO NOT put a space in between the commas.

- You can monitor the progress of most rake tasks by tailing `log/production.log`, or by querying the database from Rails console using ActiveRecord. The tasks for large storage_roots can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki) on the timing of past runs (and some suggested overview queries). Profiling will add some overhead.

- Rake tasks must be run from the root directory of the project, with whatever `RAILS_ENV` is appropriate. Because the task can take days when run over all storage roots, consider running it in a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/) so you don't need to keep your connection open but can still see the output.

As an alternative to `screen`, you can also run tasks in the background using `nohup` so the invoked command is not killed when you exist your session. Output that would've gone to stdout is instead redirected to a file called `nohup.out`, or you can redirect the output explicitly.  For example:

```sh
RAILS_ENV=production nohup bundle exec rake m2c:seed_all_roots >seed_all_roots_nohup-2017-12-12.txt &
```

## <a name="m2c"/>Moab to Catalog (M2C) existence/version check

To run rake tasks below, give the name of the moab storage_root (e.g. from settings/development.yml) as an argument.

### Single Root
- Without profiling
```sh
RAILS_ENV=production bundle exec rake m2c:one_root[fixture_sr1]
```
- With profiling:
```sh

RAILS_ENV=production bundle exec rake m2c:one_root[fixture_sr1,profile]
```
this will generate a log at, for example, `log/profiler_M2C_check_existence_for_dir2017-12-11T14:34:06-flat.txt`

### All Roots
- Without profiling:
```sh
RAILS_ENV=production bundle exec rake m2c:all_roots
```
- With profiling:
```sh
RAILS_ENV=production bundle exec rake m2c:all_roots[profile]
```
this will generate a log at, for example, `log/profile_M2C_check_existence_for_all_storage_roots2017-12-11T14:25:31-flat.txt`

### Single Druid
```sh
RAILS_ENV=production bundle exec rake m2c:druid['oo000oo0000']
```

### Druid List
- Give the file path of the csv as the parameter. The first column of the csv should contain druids, without the prefix, and contain no headers.

```sh
RAILS_ENV=production bundle exec rake m2c:druid_list[/file/path/to/your/csv/druid_list.csv]
```
## <a name="c2m"/>Catalog to Moab (C2M) existence/version check

- Given a catalog entry for an online moab, ensure that the online moab exists and that the catalog version matches the online moab version.

- To run rake tasks below, give a date and the name of the moab storage_root (e.g. from settings/development.yml) as arguments.

- The (date/timestamp) argument is a threshold:  it will run the check on all catalog entries which last had a version check BEFORE the argument. It should be in the format '2018-01-22 22:54:48 UTC'.

- Note: Must enter date/timestamp argument as a string.

### Single Root
- Without profiling
```sh
RAILS_ENV=production bundle exec rake c2m:one_root['2018-01-22 22:54:48 UTC',fixture_sr1]
```
- With profiling
```sh
RAILS_ENV=production bundle exec rake c2m:one_root['2018-01-22 22:54:48 UTC',fixture_sr1,profile]
```
this will generate a log at, for example, `log/profile_C2M_check_version_on_dir2018-01-01T14:25:31-flat.txt`

### All Roots
- Without profiling:
```sh
RAILS_ENV=production bundle exec rake c2m:all_roots['2018-01-22 22:54:48 UTC']
```
- With profiling:
```sh
RAILS_ENV=production bundle exec rake c2m:all_roots['2018-01-22 22:54:48 UTC',profile]
```
this will generate a log at, for example, `log/profile_C2M_check_version_all_dirs2018-01-01T14:25:31-flat.txt`

## <a name="cv"/>Checksum Validation (CV)
- Parse all manifestInventory.xml and most recent signatureCatalog.xml for stored checksums and verify against computed checksums.
- To run rake tasks below, give the name of the endpoint (e.g. from settings/development.yml)

### Single Root
- Without profiling
```sh
RAILS_ENV=production bundle exec rake cv:one_root[fixture_sr3]
```
- With profiling
```sh
RAILS_ENV=production bundle exec rake cv:one_root[fixture_sr3,profile]
```
this will generate a log at, for example, `log/profile_cv_validate_disk2018-01-01T14:25:31-flat.txt`

### All Roots
- Without profiling:
```sh
RAILS_ENV=production bundle exec rake cv:all_roots
```
- With profiling:
```sh
RAILS_ENV=production bundle exec rake cv:all_roots[profile]
```
this will generate a log at, for example, `log/profile_cv_validate_disk_all_endpoints2018-01-01T14:25:31-flat.txt`

### Single Druid
- Without profiling:
```sh
RAILS_ENV=production bundle exec rake cv:druid[bz514sm9647]
```

### Druid List
- Give the file path of the csv as the parameter. The first column of the csv should contain druids, without the prefix, and contain no headers.
- Without profiling:
```sh
RAILS_ENV=production bundle exec rake cv:druid_list[/file/path/to/your/csv/druid_list.csv]
```

## <a name="seeding"/>Seed the catalog

Seeding the catalog presumes an empty or nearly empty database -- otherwise running the seed task will throw `druid NOT expected to exist in catalog but was found` errors for each found object.

Without profiling:
```sh
RAILS_ENV=production bundle exec rake m2c:seed_all_roots
```

With profiling:
```sh
RAILS_ENV=production bundle exec rake m2c:seed_all_roots[profile]
```
this will generate a log at, for example, `log/profile_seed_catalog_for_all_storage_roots2017-11-13T13:57:01-flat.txt`

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

### run `rake db:seed` in a deploy environment:

```sh
bundle exec cap stage db_seed # for the stage servers
```

or

```sh
bundle exec cap prod db_seed # for the prod servers
```

### Drop or Populate the catalog for a single endpoint

To run either of the rake tasks below, give the name of the moab storage_root (e.g. from settings/development.yml) as an argument.

#### Drop all database entries:

```sh
RAILS_ENV=production bundle exec rake m2c:drop_root[fixture_sr1]
```

#### Populate the catalog:

```sh
RAILS_ENV=production bundle exec rake m2c:seed_root[fixture_sr1]
```

## <a name="console"/>Audit Checks via Console
To run audit checks via the console open up the rails console:
```sh
bundle exec rails console production
```

Next, require the audit module. This will load all of the required files needed to run the audit checks.
```ruby
require 'audit'
```

Here are the list of the Audit Checks.

### Moab To Catalog Audit Checks:

#### Single Druid
```ruby
Audit::MoabToCatalog.check_existence_for_druid('xx000xx0000')
```
#### List of Druids
```ruby
Audit::MoabToCatalog.check_existence_for_druid_list('/path/to/your/csv/druid_list.csv')
```
#### Single Storage Root
```ruby
Audit::MoabToCatalog.check_existence_for_dir('path/to/root/spec/fixtures/storage_root01/moab_storage_trunk')
```
#### All Storage Roots
```ruby
Audit::MoabToCatalog.check_existence_for_all_storage_roots
```

### Catalog To Moab Audit Checks:
-  The (date/timestamp) argument is a threshold:  it will run the check on all catalog entries which last had a version check BEFORE the argument. It should be in the format '2018-01-22 22:54:48 UTC'.

- Note: Must enter date/timestamp argument as a string.
#### Single Storage Root

```ruby
Audit::CatalogToMoab.check_version_on_dir('2018-01-22 22:54:48 UTC', 'path/to/root/spec/fixtures/storage_root01/moab_storage_trunk')
```
#### All Storage Roots
```ruby
Audit::CatalogToMoab.check_version_all_dirs('2018-01-22 22:54:48 UTC')
```

### Checksum Audit Checks:

#### Single Storage Root
```ruby
Audit::Checksum.validate_disk('fixture_sr3')
```
#### All Storage Roots
```ruby
Audit::Checksum.validate_disk_all_endpoints
```
#### Single Druid
```ruby
Audit::Checksum.validate_druid('xx000xx0000')
```

#### List of Druids
```ruby
Audit::Checksum.validate_list_of_druids('/path/to/your/csv/druid_list.csv')
```

## <a name="development"/>Development

### Running Tests

To run the tests:

```sh
rake spec
```

## <a name="deploying"/>Deploying

Capistrano is used to deploy.

### run `rake db:seed` in a deploy environment:

```sh
bundle exec cap stage db_seed # for the stage servers
```

or

```sh
bundle exec cap prod db_seed # for the prod servers
```

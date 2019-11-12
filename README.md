[![Build Status](https://travis-ci.org/sul-dlss/preservation_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_catalog)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_catalog/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/preservation_catalog?branch=master)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)

# README

Rails application to track, audit and replicate archival artifacts associated with SDR objects.

## Table of Contents

* [Getting Started](#getting-started)
* [Usage Instructions](#usage-instructions)
    * [Moab to Catalog](#m2c) (M2C) existence/version check
    * [Catalog to Moab](#c2m) (C2M) existence/version check
    * [Checksum Validation](#cv) (CV)
    * [Seed the catalog](#seed-the-catalog)
* [Development](#development)
* [Deploying](#deploying)

## Getting Started

### Installing dependencies

Use the docker-compose to start the dependencies (PostgreSQL and Redis)
```sh
docker-compose up
```

### Configuring The database

Run this script:
```sh
./bin/rails db:reset
RAILS_ENV=test ./bin/rails db:seed
```

# Usage Instructions

### Note: We are using the whenever gem for writing and deploying cron jobs. M2C, C2M, and CV are all scheduled using the whenever gem. You can view our schedule at [Schedule](config/schedule.rb)

## General Info

- Rake and console tasks must be run from the root directory of the project, with whatever `RAILS_ENV` is appropriate.

- You can monitor the progress of most tasks by tailing `log/production.log` (or task specific log), checking the Resque dashboard or by querying the database. The tasks for large storage_roots can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki) on the timing of past runs (and some suggested overview queries). Profiling will add some overhead.

- Tasks that use asynchronous workers will execute on any of the eligible worker pool systems for that job.  Therefore, do not expect all the results to show in the logs of the machine that enqueued the jobs!

- Because large tasks can take days when run over all storage roots, consider running in a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/) so you don't need to keep your connection open but can still see the output.

As an alternative to `screen`, you can also run tasks in the background using `nohup` so the invoked command is not killed when you exist your session. Output that would've gone to stdout is instead redirected to a file called `nohup.out`, or you can redirect the output explicitly.  For example:

```sh
RAILS_ENV=production nohup bundle exec ...
```

### Rake Tasks

- Note: If the rake task takes multiple arguments, DO NOT put a space in between the commas.

- Rake tasks will have the form:

```sh
RAILS_ENV=production bundle exec rake ...
```

### Rails Console

The application's most powerful functionality is available via `rails console`.  Open it (for the appropriate environment) like:

```sh
RAILS_ENV=production bundle exec rails console
```

## <a name="m2c"/>Moab to Catalog (M2C) existence/version check

In console, first locate a `MoabStorageRoot`, then call `m2c_check!` to enqueue M2C jobs for that root.
The actual checks for `m2c_check!` are performed asynchronously by worker processes.

### Single Root
```ruby
msr = MoabStorageRoot.find_by!(storage_location: '/path/to/storage')
msr.m2c_check!
```

### All Roots
```ruby
MoabStorageRoot.find_each { |msr| msr.m2c_check! }
```

### Single Druid
To M2C a single druid synchronously, in console:
```ruby
Audit::MoabToCatalog.check_existence_for_druid('jj925bx9565')
```

### Druid List
For a predetermined list of druids, a convenience wrapper for the above command is `check_existence_for_druid_list`.

- The parameter is the file path of a CSV file listing the druids.
  - The first column of the csv should contain druids, without prefix.
  - File should not contain headers.

```ruby
Audit::MoabToCatalog.check_existence_for_druid_list('/file/path/to/your/csv/druid_list.csv')
```

Note: it should not typically be necessary to serialize a list of druids to CSV.  Just iterate over them and use the "Single Druid" approach.

## <a name="c2m"/>Catalog to Moab (C2M) existence/version check

Note: C2M uses the `Audit::CatalogToMoab` asynchronously via workers on the `:c2m` queue.

- Given a catalog entry for an online moab, ensure that the online moab exists and that the catalog version matches the online moab version.

- You will need to identify a moab storage_root (e.g. with path from settings/development.yml) and optionally provide a date threshold.

- The (date/timestamp) argument is a threshold: it will run the check on all catalog entries which last had a version check BEFORE the argument. You can use string format like '2018-01-22 22:54:48 UTC' or ActiveRecord Date/Time expressions like `1.week.ago`.  The default is anything not checked since **right now**.

These C2M examples use a rails console, like: `RAILS_ENV=production bundle exec rails console`

### Single Root

This enqueues work for all the objects associated with the first `MoabStorageRoot` in the database, then the last:

```ruby
MoabStorageRoot.first.c2m_check!
MoabStorageRoot.last.c2m_check!
```

This enqueues work from a given root not checked in the past 3 days.

```ruby
msr = MoabStorageRoot.find_by!(storage_location: '/path/to/storage')
msr.c2m_check!(3.days.ago)
```

### All Roots
This enqueues work from **all** roots similarly.
```ruby
MoabStorageRoot.find_each { |msr| msr.c2m_check!(3.days.ago) }
```

## <a name="cv"/>Checksum Validation (CV)
- Parse all `manifestInventory.xml` and most recent `signatureCatalog.xml` for stored checksums and verify against computed checksums.
- To run the tasks below, give the name of the storage root (e.g. from `settings/development.yml`)

Note: CV jobs that are asynchronous means that their execution happens in other processes (including on other systems).

### Single Root
From console, this queues objects on the named storage root for asynchronous CV:
```ruby
msr = MoabStorageRoot.find_by!(name: 'fixture_sr3')
msr.validate_expired_checksums!
```
### All Roots
This is also asynchronous, for all roots:
```ruby
MoabStorageRoot.find_each { |msr| msr.validate_expired_checksums! }
```

### Single Druid
Synchronously:
```ruby
Audit::Checksum.validate_druid(druid)
```

### Druid List
- Give the file path of the csv as the parameter. The first column of the csv should contain druids, without the prefix, and contain no headers.

In console:
```ruby
Audit::Checksum.validate_list_of_druids('/file/path/to/your/csv/druid_list.csv')
```

### Druids with a particular status on a particular storage root

For example, if you wish to run CV on all the "validity_unknown" druids on storage root 15, from console:

```ruby
Audit::Checksum.validate_status_root(:validity_unknown, :services-disk15)
```

[Valid status strings](https://github.com/sul-dlss/preservation_catalog/blob/master/app/models/complete_moab.rb#L1-L10)

## Seed the catalog (with data about the Moabs on the storage roots the catalog tracks -- presumes rake db:seed already performed)

_<sub>Note: "seed" might be slightly confusing terminology here, see https://github.com/sul-dlss/preservation_catalog/issues/1154</sub>_

Seeding the catalog presumes an empty or nearly empty database -- otherwise seeding will throw `druid NOT expected to exist in catalog but was found` errors for each found object.
Seeding does more validation than regular M2C.

From console:
```ruby
Audit::MoabToCatalog.seed_catalog_for_all_storage_roots
```

#### Reset the catalog for re-seeding

WARNING! this will erase the catalog, and thus require re-seeding from scratch.  It is mostly intended for development purposes, and it is unlikely that you'll need to run this against production once the catalog is in regular use.

* Deploy the branch of the code with which you wish to seed, to the instance which you wish to seed (e.g. master to stage).
* Reset the database for that instance.  E.g., on production or stage:  `RAILS_ENV=production bundle exec rake db:reset`
  * note that if you do this while `RAILS_ENV=production` (i.e. production or stage), you'll get a scary warning along the lines of:
  ```
  ActiveRecord::ProtectedEnvironmentError: You are attempting to run a destructive action against your 'production' database.
  If you are sure you want to continue, run the same command with the environment variable:
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  ```
  Basically an especially inconvenient confirmation dialogue.  For safety's sake, the full command that skips that warning can be constructed by the user as needed, so as to prevent unintentional copy/paste dismissal when the user might be administering multiple deployment environments simultaneously.  Inadvertent database wipes are no fun.
  * `db:reset` will make sure db is migrated and seeded.  If you want to be extra sure: `RAILS_ENV=[environment] bundle exec rake db:migrate db:seed`

### run `rake db:seed` on remote servers:
These require the same credentials and setup as a regular Capistrano deploy.

```sh
bundle exec cap stage db_seed # for the stage servers
```

or

```sh
bundle exec cap prod db_seed # for the prod servers
```

### Populate the catalog

In console, start by finding the storage root.

```ruby
msr = MoabStorageRoot.find_by!(name: name)
MoabToCatalog.seed_catalog_for_dir(msr.storage_location)
```

Or for all roots:
```ruby
MoabStorageRoot.find_each { |msr| MoabToCatalog.seed_catalog_for_dir(msr.storage_location) }
```

## Development

### Seed

You should only need to do this:
* when you first start developing on Preservation Catalog
* after nuking your test database
* when adding storage roots or zip endpoints:
```
RAILS_ENV=test bundle exec rails db:reset
```

The above populates the database with PreservationPolicy, MoabStorageRoot, and ZipEndpoint objects
as defined in the configuration files.

If you are new to developing on this project, you should read [the database README](db/README.md).  It
has a detailed explanation of the data model, some sample queries, and an ER diagram illustrating the
DB table relationships.  For those less familiar with ActiveRecord, there is also some guidance about
how this project uses it.

_Please keep the database README up to date as the schema changes!_

You may also wish to glance at the (much shorter) [Replication README](app/jobs/README.md).

### Running Tests

To run the tests:

```sh
bundle exec rspec
```

## Deploying

Capistrano is used to deploy.  You will need SSH access to the targeted servers, via `kinit` and VPN.

```sh
bundle exec cap stage deploy # for the stage servers
```

Or:

```sh
bundle exec cap prod deploy # for the prod servers
```

### Resque Pool
The Resque Pool admin interface is available at `<hostname>/resque/overview`.


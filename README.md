# preservation_catalog (aka PresCat)

[![CircleCI](https://circleci.com/gh/sul-dlss/preservation_catalog.svg?style=svg)](https://circleci.com/gh/sul-dlss/preservation_catalog)
[![Test Coverage](https://api.codeclimate.com/v1/badges/96b330db62f304b786cb/test_coverage)](https://codeclimate.com/github/sul-dlss/preservation_catalog/test_coverage)
[![Maintainability](https://api.codeclimate.com/v1/badges/96b330db62f304b786cb/maintainability)](https://codeclimate.com/github/sul-dlss/preservation_catalog/maintainability)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)
[![Docker image](https://images.microbadger.com/badges/image/suldlss/preservation_catalog.svg)](https://microbadger.com/images/suldlss/preservation_catalog "Get your own image badge on microbadger.com")
[![OpenAPI Validator](http://validator.swagger.io/validator?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)](http://validator.swagger.io/validator/debug?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)

*preservation_catalog* is a Rails application that tracks, audits and replicates
archival artifacts associated with SDR objects.

## Development

Here are the steps you need to follow to get a working development instance of *preservation_catalog* running:

### Install dependencies

First get the Ruby dependencies:
```sh
bundle install
```

Use `docker compose` to start supporting services (PostgreSQL and Redis)
```sh
docker compose up -d db redis
```

### Configure the database 

Set up the database:

```sh
./bin/rails db:reset
```

Ensure storage roots and cloud endpoints have the necessary database records:

```sh
RAILS_ENV=test ./bin/rails db:seed
```

### Run Tests

To run the tests:

```sh
bundle exec rspec
```

### Run the App

If you've chosen to install Ruby dependencies you can run the app locally with:

```sh
bin/dev
```

If you prefer you can also run the web app inside of a Docker container:

```sh
docker compose build app
```

Bring up the docker container and its dependencies:

```sh
docker compose up -d
```

It does the same thing as the `db:reset` and `db:seed` above, but you can
initialize the database directly from inside in the container if you like:

```sh
docker compose run app bundle exec rails db:reset db:seed
```

All set, now you can view the app:

Visit `http://localhost:3000/dashboard/`

### Interact with API

You can use curl to interact with the API via localhost:

```sh
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' -F 'druid=druid:bj102hs9688' -F 'incoming_version=3' -F 'incoming_size=2070039' -F 'storage_location=spec/fixtures/storage_root01' -F 'checksums_validated=true' http://localhost:3000/v1/catalog
```

```sh
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' http://localhost:3000/v1/objects/druid:bj102hs9688

{
  "id":1,
  "druid":"bj102hs9688",
  "current_version":3,
  "created_at":"2019-12-20T15:04:56.854Z",
  "updated_at":"2019-12-20T15:04:56.854Z"
}
```

## General Info

- The PostgreSQL database is the catalog of metadata about preserved SDR content, both on premises and in the cloud.  Integrity constraints are used heavily for keeping data clean and consistent.

- Background jobs (using ActiveJob/Resque/Redis) perform the audit and replication work.

- The whenever gem is used for writing and deploying cron jobs. Queueing of weekly audit jobs, temp space cleanup, etc are scheduled using the whenever gem.

- Communication with other DLSS services happens via REST.

- Most human/manual interaction happens via Rails console and rake tasks.

- There's troubleshooting advice in the wiki.  If you debug or clean something up in prod, consider documenting in a wiki entry (and please update entries that you use that are out of date).

- Tasks that use asynchronous workers will execute on any of the eligible worker pool VM.  Therefore, do not expect all the results to show in the logs of the machine that enqueued the jobs!

- We strongly prefer to run large numbers of validations using ActiveJob, so they can be run in parallel.

- You can monitor the progress of most tasks by tailing `log/production.log` (or task specific log), checking the Resque dashboard, or by querying the database. The tasks for large storage roots can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki) on the timing of past runs.

- When executing long running queries, audits, remediations, etc from the Rails console, consider using a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/) or `nohup` so that the process isn't killed when you log out.

If you are new to developing on this project, you should at least skim [the database README](db/README.md).
It has a detailed explanation of the data model, some sample queries, and an ER diagram illustrating the
table/model relationships.  For those less familiar with ActiveRecord, there is also some guidance about
how this project uses it.

_Please keep the database README up to date as the schema changes!_

You may also wish to glance at the (much shorter) [Replication README](app/jobs/README.md).

Making modifications to the database is usually done either using the Rails console or a Rake task. Some common operations are listed below.

## Moab to Catalog (M2C) existence/version check

See [Validations-for-Moabs wiki](http://github.com/sul-dlss/preservation_catalog/wiki/Validations-for-Moabs) for basic info about M2C validation.

### Rake task for Single Root

- You need to know the MoabStorageRoot name, available from settings.yml (shared_configs for deployments)
- You do NOT need quotes for the root name
- Checks will be run asynchronously via MoabToCatalogJob

```sh
RAILS_ENV=production bundle exec rake prescat:audit:m2c[root_name]
```

### Via Rails Console

In console, first locate a `MoabStorageRoot`, then call `m2c_check!` to enqueue asynchronous executions via MoabToCatalogJob. Storage root information is available from settings.yml (shared_configs for deployments).

#### Single Root
```ruby
msr = MoabStorageRoot.find_by!(storage_location: '/path/to/storage')
msr.m2c_check!
```

#### All Roots
```ruby
MoabStorageRoot.find_each { |msr| msr.m2c_check! }
```

#### Single Druid
To M2C a single druid synchronously, in console:
```ruby
Audit::MoabToCatalog.check_existence_for_druid('jj925bx9565')
```

#### Druid List
For a predetermined list of druids, a convenience wrapper for the above command is `check_existence_for_druid_list`.

- The parameter is the file path of a CSV file listing the druids.
  - The first column of the csv should contain druids, without prefix.
  - File should not contain headers.

```ruby
Audit::MoabToCatalog.check_existence_for_druid_list('/file/path/to/your/csv/druid_list.csv')
```

Note: it should not typically be necessary to serialize a list of druids to CSV.  Just iterate over them and use the "Single Druid" approach.

## Catalog to Moab (C2M) existence/version check

See [Validations-for-Moabs wiki](http://github.com/sul-dlss/preservation_catalog/wiki/Validations-for-Moabs) for basic info about C2M validation.

### Rake task for Single Root

- You need to know the MoabStorageRoot name, available from settings.yml (shared_configs for deployments)
- You do NOT need quotes for the root name.
- You cannot provide a date threshold:  it will perform the validation for every CompleteMoab prescat has for the root.
- Checks will be run asynchronously via CatalogToMoabJob

```sh
RAILS_ENV=production bundle exec rake prescat:audit:c2m[root_name]
```

### Via Rails Console

In console, first locate a `MoabStorageRoot`, then call `c2m_check!` to enqueue asynchronous executions for the CompleteMoabs associated with that root via CatalogToMoabJob. Storage root information is available from settings.yml (shared_configs for deployments).

- The (date/timestamp) argument is a threshold: it will run the check on all catalog entries which last had a version check BEFORE the argument. You can use string format like '2018-01-22 22:54:48 UTC' or ActiveRecord Date/Time expressions like `1.week.ago`.  The default is anything not checked since **right now**.


#### Single Root

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

#### All Roots
This enqueues the checks from **all** roots similarly.
```ruby
MoabStorageRoot.find_each { |msr| msr.c2m_check!(3.days.ago) }
```

## Checksum Validation (CV)

See [Validations-for-Moabs wiki](http://github.com/sul-dlss/preservation_catalog/wiki/Validations-for-Moabs) for basic info about CV validation.

### Rake task for Single Root

- You need to know the MoabStorageRoot name, available from settings.yml (shared_configs for deployments)
- You do NOT need quotes for the root name.
- It will perform checksum validation for *every* CompleteMoab prescat has for the root, ignoring the "only older than fixity_ttl threshold" (which is currently 90 days)
- Checks will be run asynchronously via ChecksumValidationJob

```sh
RAILS_ENV=production bundle exec rake prescat:audit:cv[root_name]
```

### Via Rails Console

In console, first locate a `MoabStorageRoot`, then call `validate_expired_checksums!` to enqueue asynchronous executions for the CompleteMoabs associated with that root via ChecksumValidationJob.  Storage root information is available from settings.yml (shared_configs for deployments).

#### Single Root
From console, this queues objects on the named storage root for asynchronous CV:
```ruby
msr = MoabStorageRoot.find_by!(name: 'fixture_sr3')
msr.validate_expired_checksums!
```

#### All Roots
This is also asynchronous, for all roots:
```ruby
MoabStorageRoot.find_each { |msr| msr.validate_expired_checksums! }
```

#### Single Druid
Synchronously, from Rails console (will take a long time for very large objects):
```ruby
Audit::ChecksumValidatorUtils.validate_druid(druid)
```

#### Druid List
- Give the file path of the csv as the parameter. The first column of the csv should contain druids, without the prefix, and contain no headers.

Synchronously, from Rails console:
```ruby
Audit::ChecksumValidatorUtils.validate_list_of_druids('/file/path/to/your/csv/druid_list.csv')
```

#### Druids with a particular status on a particular storage root

For example, if you wish to run CV on all the "validity_unknown" druids on storage root 15, from console:

```ruby
Audit::ChecksumValidatorUtils.validate_status_root(:validity_unknown, 'services-disk15')
```

[Valid status strings](https://github.com/sul-dlss/preservation_catalog/blob/main/app/models/complete_moab.rb#L1-L10)

## Seed the Catalog 

Seed the Catalog with data about the Moabs on the storage roots the catalog tracks -- presumes rake db:seed already performed)

_<sub>Note: "seed" might be slightly confusing terminology here, see https://github.com/sul-dlss/preservation_catalog/issues/1154</sub>_

Seeding the catalog presumes an empty or nearly empty database -- otherwise seeding will throw `druid NOT expected to exist in catalog but was found` errors for each found object.
Seeding does more validation than regular M2C.

From console:
```ruby
Audit::MoabToCatalog.seed_catalog_for_all_storage_roots
```

#### Reset the catalog for re-seeding

**DANGER!** this will erase the catalog, and thus require re-seeding from scratch.  It is mostly intended for development purposes, and it is unlikely that you'll _ever_ need to run this against production once the catalog is in regular use.

* Deploy the branch of the code with which you wish to seed, to the instance which you wish to seed (e.g. main to stage).
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
Audit::MoabToCatalog.seed_catalog_for_dir(msr.storage_location)
```

Or for all roots:
```ruby
MoabStorageRoot.find_each { |msr| Audit::MoabToCatalog.seed_catalog_for_dir(msr.storage_location) }
```

## Moving Moabs

Sometimes it's necessary to move Moabs from one storage root to another, either in bulk as part of a storage hardware migration, or manually for a small number, as when an existing Moab might get too much additional content for the storage root it's currently on.

There are rake tasks and documentation to support the bulk migration scenario.  See the [migration issue template](.github/ISSUE_TEMPLATE/storage-migration-checklist.md).

When the need for moving a single Moab arises, the repository manager or a developer should:
1. [on the file system] Move the Moab to a storage root with enough space
1. [from pres cat VM rails console] Update prescat with the new location
1. Accession the additional content to be preserved

Updating Preservation Catalog to reflect the Moab's new location can be done using Rails console, like so:
```ruby
target_storage_root = MoabStorageRoot.find_by!(name: '/services-disk-with-lots-of-free-space')
cm = CompleteMoab.by_druid('ab123cd4567')
cm.migrate_moab(target_storage_root).save! # save! is important.  migrate_moab doesn't save automatically, to allow building larger transactions.
```
Under the assumption that the contents of the Moab were written anew in the target location, `#migrate_moab` will clear all audit timestamps related to the state of the Moab on our disks, along with `status_details`.  `status` will similarly be re-set to `validity_unknown`, and a checksum validation job will automatically be queued for the Moab.

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

The Resque Pool admin interface is available at `<hostname>/resque/overview`.  The wiki has advice for troubleshooting failed jobs.

## API

The API is versioned; only requests to explicitly versioned endpoints will be serviced.
Full API documentation (maintained in openapi.yml): see https://sul-dlss.github.io/preservation_catalog/

### AuthN

Authentication/authorization is handled by JWT.  Preservation Catalog mints JWTs for individual client services, and the client services each provide their respective JWT when making HTTP API calls to PresCat.

To generate an authentication token run `rake generate_token` on the server to which the client will connect (e.g. stage, prod).  This will use the HMAC secret to sign the token. It will ask you to submit a value for "Account". This should be the name of the calling service, or a username if this is to be used by a specific individual. This value is used for traceability of errors and can be seen in the "Context" section of a Honeybadger error. For example:

```ruby
{"invoked_by" => "preservation-robots"}
```

The token generated by `rake generate_token` should be passed along in the `Authorization` header as `Bearer <GENERATED_TOKEN_VALUE>`.

API requests that do not supply a valid token for the target server will be rejected as Unauthorized.

At present, all tokens grant the same (full) access to the read/update API.

## Cron check-ins
Some cron jobs (configured via the whenever gem) are integrated with Honeybadger check-ins. These cron jobs will check-in with HB (via a curl request to an HB endpoint) whenever run. If a cron job does not check-in as expected, HB will alert.

Cron check-ins are configured in the following locations:
1. `config/schedule.rb`: This specifies which cron jobs check-in and what setting keys to use for the checkin key. See this file for more details.
2. `config/settings.yml`: Stubs out a check-in key for each cron job. Since we may not want to have a check-in for all environments, this stub key will be used and produce a null check-in.
3. `config/settings/production.yml` in shared_configs: This contains the actual check-in keys.
4. HB notification page: Check-ins are configured per project in HB. To configure a check-in, the cron schedule will be needed, which can be found with `bundle exec whenever`. After a check-in is created, the check-in key will be available. (If the URL is `https://api.honeybadger.io/v1/check_in/rkIdpB` then the check-in key will be `rkIdpB`).

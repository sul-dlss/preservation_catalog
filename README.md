# preservation_catalog (aka PresCat)

[![CircleCI](https://circleci.com/gh/sul-dlss/preservation_catalog.svg?style=svg)](https://circleci.com/gh/sul-dlss/preservation_catalog)
[![Test Coverage](https://api.codeclimate.com/v1/badges/96b330db62f304b786cb/test_coverage)](https://codeclimate.com/github/sul-dlss/preservation_catalog/test_coverage)
[![Maintainability](https://api.codeclimate.com/v1/badges/96b330db62f304b786cb/maintainability)](https://codeclimate.com/github/sul-dlss/preservation_catalog/maintainability)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)
[![Docker image](https://images.microbadger.com/badges/image/suldlss/preservation_catalog.svg)](https://microbadger.com/images/suldlss/preservation_catalog "Get your own image badge on microbadger.com")
[![OpenAPI Validator](http://validator.swagger.io/validator?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)](http://validator.swagger.io/validator/debug?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)

## Overview

*preservation_catalog* (aka *prescat*) is a Rails application that tracks, audits and replicates
archival artifacts associated with SDR objects. Unlike many SDR services, prescat is directly dependent on external, third party Internet services. As a result prescat can also be uniquely subject to intermittent network and service failures.

prescat works in concert with [preservation_robots](https://github.com/sul-dlss/preservation_robots) (aka *presrobots*) to ensure that all versions of SDR objects are stored on disk using the [Moab](https://searchworks.stanford.edu/view/vt105qd7230) packaging standard. Moab directories are zipped and then stored in three, geographically distributed, architecturally heterogeneous, cloud storage platforms. These storage architectures include [Amazon S3](https://aws.amazon.com/s3/), [IBM Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage) and a [Ceph](https://ceph.io/en/) cluster being run on premises. The storage systems operate in northern California, northern Virginia and central Texas.

The *prescat* application has several modes of operation, that are either self-managed (cron) or initiated externally via its [REST API](https://sul-dlss.github.io/preservation_catalog/) using  the [preservation-client](https://github.com/sul-dlss/preservation-client) gem.

1. As part of the *preservation-ingest* workflow *presrobots* notifies *prescat* about a new or updated Moab using the prescat REST API. After the [PreservedObject](https://github.com/sul-dlss/preservation_catalog/blob/main/app/models/preserved_object.rb) is created or updated in the database, asynchronous [queues](https://preservation-catalog-web-prod-01.stanford.edu/queues/) are used to create a zip for the Moab version, which is then replicated to each of the storage endpoints (AWS S3 and IBM Cloud).

2. *prescat* has an internal schedule of cron jobs which perform periodic [audits](https://github.com/sul-dlss/preservation_catalog/wiki/Validations-for-Moabs) that compare the Moabs that are on disk, with what is in the database (and vice-versa), and also verify that data has been replicated to the cloud. These audits ensure that files are present with the expected content (fixity). When these audits succeed or fail they generate events using the [DOR Services API](https://sul-dlss.github.io/dor-services-app/#operation/events#create), and (if they fail) Honey Badger alerts.

3. Both [Argo](https://github.com/sul-dlss/argo) and [HappyHeron](https://github.com/sul-dlss/happy-heron) allow users to fetch preserved files using the *prescat* REST API.

4. [DOR Services](https://github.com/sul-dlss/dor-services-app) uses the *prescat* REST API in order to determine what files are in need of replication during shelving to [Stacks](https://github.com/sul-dlss/stacks).

```mermaid
flowchart LR;
  H2 --> PresCat;
  Argo --> PresCat;
  DSA <--> PresCat;
  PresRobots --> PresCat;
  PresCat <--> S3[(AWS)];
  PresCat <--> IBM[(IBM)];
  Ceph --> PresCat;
  PresRobots <--> Ceph[(Ceph)];
```

For more detailed information please see the [General Info](#general-info) section below.

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

- The PostgreSQL database is the catalog of metadata about preserved SDR content, both on premises and in the cloud.  Database-level constraints are used heavily for keeping data clean and consistent.

- Background jobs (using ActiveJob/Sidekiq/Redis) perform the audit and replication work.

- The whenever gem is used for writing and deploying cron jobs. Queueing of weekly audit jobs, temp space cleanup, etc are scheduled using the whenever gem.

- Communication with other DLSS services happens via REST.

- Most human/manual interaction happens via Rails console and rake tasks.

- There's troubleshooting advice in the wiki. If you debug or clean something up in prod, consider documenting in a wiki entry (and please update entries that you use that are out of date).

- Tasks that use asynchronous workers will execute on any of the eligible worker pool VM.  Therefore, do not expect all the results to show in the logs of the machine that enqueued the jobs!

- We strongly prefer to run large numbers of validations using ActiveJob, so they can be run in parallel.

- You can monitor the progress of most tasks by tailing `log/production.log` (or task specific log), checking the Sidekiq dashboard, or by querying the database. The tasks for large storage roots can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki) on the timing of past runs.

- When executing long running queries, audits, remediations, etc from the Rails console, consider using a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/) or `nohup` so that the process isn't killed when you log out.

If you are new to developing on this project, you should at least skim [the database README](db/README.md).
It has a detailed explanation of the data model, some sample queries, and an ER diagram illustrating the
table/model relationships.  For those less familiar with ActiveRecord, there is also some guidance about
how this project uses it.

_Please keep the database README up to date as the schema changes!_

You may also wish to glance at the (much shorter) [Replication README](app/jobs/README.md).

Making modifications to the database is usually done either using the Rails console or a Rake task. Some common operations are listed below.

## Audits

See wiki, in particular

- [https://github.com/sul-dlss/preservation_catalog/wiki/Audits-(basic-info)](Audits (basic info))
- [https://github.com/sul-dlss/preservation_catalog/wiki/Audits-(how-to-run-as-needed)](Audits (how to run as needed))

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

## Deploying

Capistrano is used to deploy.  You will need SSH access to the targeted servers, via `kinit` and VPN.

```sh
bundle exec cap stage deploy # for the stage servers
```

Or:

```sh
bundle exec cap prod deploy # for the prod servers
```

### Sidekiq

The Sidekiq admin interface is available at `<hostname>/queues`.  The wiki has advice for troubleshooting failed jobs.

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

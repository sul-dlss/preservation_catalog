# preservation_catalog (aka PresCat)

[![CircleCI](https://circleci.com/gh/sul-dlss/preservation_catalog.svg?style=svg)](https://circleci.com/gh/sul-dlss/preservation_catalog)
[![codecov](https://codecov.io/github/sul-dlss/preservation_catalog/graph/badge.svg?token=dyOwoVHZ1y)](https://codecov.io/github/sul-dlss/preservation_catalog)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)
[![Docker image](https://img.shields.io/docker/pulls/suldlss/preservation_catalog.svg)](https://hub.docker.com/r/suldlss/preservation_catalog)
[![OpenAPI Validator](https://validator.swagger.io/validator?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)](http://validator.swagger.io/validator/debug?url=https://raw.githubusercontent.com/sul-dlss/preservation_catalog/main/openapi.yml)

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

The credentials for SideKiq Pro must be provided (e.g., in `.bash_profile`): `export BUNDLE_GEMS__CONTRIBSYS__COM=xxxx:xxxx` (available from shared_configs).

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

**NOTE**: This does not run tests which access AWS S3 resources on the fly, which are flaky and based on IP addresses. To run these, use `bundle exec rspec --tag live_s3`.)

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

## Populate the Catalog

Populate the Catalog with data about the Moabs already written to the storage roots the catalog tracks -- presumes `rake db:seed` already performed

Populating the catalog presumes an empty or nearly empty database -- otherwise walking the storage roots to populate it will throw
`druid NOT expected to exist in catalog but was found` errors for each found object.  Catalog population does more validation than the
similar `MoabToCatalogJob`/`MoabRecordService::CheckExistence`.

From console:
```ruby
CatalogUtils.populate_catalog_for_all_storage_roots
```

### Reset the catalog for re-population (without wiping preserved Moabs from storage roots)

**DANGER!** this will erase the catalog, and thus require re-population from scratch.  It is mostly intended for development purposes, and it is unlikely that you'll _ever_ need to run this against production once the catalog is in regular use.

* Deploy the branch of the code with which you wish to populate the catalog, to the instance which you wish to populate (e.g. `main` to stage).
* Reset the database for that instance.  E.g., on production or stage:  `RAILS_ENV=production bundle exec rake db:reset` (this will wipe the DB and seed it with the necessary storage root and endpoint info from the app settings, to which other catalog records will refer)
  * note that if you do this while `RAILS_ENV=production` (i.e. production or stage), you'll get a scary warning along the lines of:

```
ActiveRecord::ProtectedEnvironmentError: You are attempting to run a destructive action against your 'production' database.
If you are sure you want to continue, run the same command with the environment variable:
DISABLE_DATABASE_ENVIRONMENT_CHECK=1
```

Basically an especially inconvenient confirmation dialogue.  For safety's sake, the full command that skips that warning can be constructed by the user as needed, so as to prevent unintentional copy/paste dismissal when the user might be administering multiple deployment environments simultaneously.  Inadvertent database wipes are no fun.

### run `rake db:seed` on remote servers:

Useful if storage roots or cloud endpoints are added to configuration.  Will not delete entries that have been removed from configuration, that must be done manually using `ActiveRecord`.

These require the same credentials and setup as a regular Capistrano deploy.

```sh
bundle exec cap stage db_seed # for the stage servers
```

or

```sh
bundle exec cap prod db_seed # for the prod servers
```

### Populate the catalog for a single storage root

In console, start by finding the storage root.

```ruby
msr = MoabStorageRoot.find_by!(name: name)
CatalogUtils.populate_catalog_for_dir(msr.storage_location)
```

## Deploying

Capistrano is used to deploy.  You will need SSH access to the targeted servers, via `kinit` and VPN.

```sh
bundle exec cap ENV deploy # e.g. bundle exec cap qa deploy
```

## Jobs

Sidekiq is run on one or more worker VMs to handle queued jobs.

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

## Query Performance Instrumentation
To log slow queries to `logs/slow_query.log`, enable the slow query instrumentation in `config/setting/production.yml`:
```
slow_queries:
  enable: true
  threshold: 500 # milliseconds
```

To instrument a query, include `InstrumentationSupport` and then annotate the query. For example:
```
module ReplicationService
  include InstrumentationSupport

  def num_replication_errors
    ZipPart.where.not(status: 'ok').annotate(caller).count
  end
  ...
```

Note that `.annotate(caller)` should be placed where it receives and returns an `ActiveRecord::Relation`.
```
# Good
ZipPart.where.not(status: 'ok').annotate(caller).count
ZipPart.all.annotate(caller).where.not(status: 'ok').count

# Bad
ZipPart.annotate(caller).where.not(status: 'ok').count
ZipPart.where.not(status: 'ok').count.annotate(caller)
```

## Resetting the preservation system

This procedure should reset both the catalog and the Moab storage roots, as one would do when resetting the entire stage or QA environment.

### Requirements

These instructions assume that SDR will be quiet during the reset, and that all other SDR apps will also be reset. Since related services (like DSA) and activity (like `accessionWF` and `preservationIngestWF`) won't be making requests to preservation services, and since e.g. the Cocina data store will be reset, it's not necessary to forcibly make sure that no robots are active, and it's not necessary to worry about syncing content from other apps with preservation.

### Steps

You can view the raw markdown and copy the following checklist into a new issue description for tracking the work (if you notice any necessary changes, please update this README):

- [ ] Quiet Sidekiq workers for preservation_catalog and preservation_robots in the environment being reset.  For both apps, dump any remaining queue contents manually.
- [ ] preservation_catalog: stop the web services
- _NOTE_: stopping pres bots workers and pres cat web services will effectively halt accessioning for the environment
- [ ] Delete archived content on cloud endpoints for the environment being reset (inquire with ops if you run into cloud bucket auth issues).  If Suri is not reset, then druids won't be re-used, and this can be done async from the rest of this process.  _But_, if the reset is completed and accessioning starts up again before the old cloud archives are purged, you should dump a list of the old druids before the preservation_catalog DB reset, and use that for cleanup, so that only old content is purged.  You can query for the full druid list (and e.g. redirect or copy and save the output to a file) with the following query from pres cat: `druids = PreservedObject.pluck(:druid)` (to be clear, this will probably return tens of thousands of druids).
  - `File.open('/opt/app/pres/druids_pre_reset.txt', 'w') { |f| druids.each {|druid| f.write("#{druid}\n")}}`
  - See below for how to use this list to purge pre-reset cloud archives.
- [ ] Delete all content under the `deposit` dirs and the `sdr2objects` dirs in each of the storage roots (`sdr2objects` is the configured "storage trunk", and `deposit` is where the bags that are used to build Moabs are placed). Storage root paths are listed in shared_configs for preservation_catalog (and should be the same as what's configured for presbots/techmd in the same env).  So, e.g., `rm -rf /services-disk-stage/store2/deposit/*`, `rm -rf /services-disk-stage/store2/sdr2objects/*`, etc if the storage roots are `/services-disk-stage/store2/` etc.  Deletions must be done from a preservation_robots machine for the env, as techMD and pres cat mount pres storage roots as read-only.
- [ ] From a preservation_robots VM for the environment: Delete all content under preservation_robots' `Settings.transfer_object.from_dir` path, e.g. `rm -rf /dor/export/*`
- [ ] preservation_catalog: _NOTE: this step likely not needed for most resets:_ for the environment being reset, `cap shared_configs:update` (to push the latest shared_configs, in case e.g. storage root or cloud endpoint locations have been updated)
- [ ] preservation_catalog: from any one host in the env to be reset, perform a [db reset](https://github.com/sul-dlss/DeveloperPlaybook/blob/main/best-practices/db_reset.md) including seeding.
- [ ] re-deploy preservation_catalog, preservation_robots, and techMD.  This will bring the pres cat web services back online, bring the Sidekiq workers for all services back online, and pick up any shared_configs changes.

Once the various SDR services are started back up, preserved content on storage roots and in the cloud will be rebuilt by regular accessioning.  Since preservation just preserves whatever flows through accessioning, there's no need to worry about e.g. having particular APOs in place.

#### How to delete cloud content from before the reset, using the druid list that was dumped

_NOTE:_ You should only be doing this in stage or QA.  Production has more restricted authorization for the pres user cloud buckets anyway, and should only allow an initial write for a particular key, blocking deletes and overwrites.

Since the environment should have all the necessary credentials already for deletion on stage and QA (with secrets provided by combo of puppet/vault/env), you can do something like the following in the Rails console from one of the VMs for the env you're in:

```ruby
def aws_east_provider
  Replication::AwsProvider.new(region: Settings.zip_endpoints.aws_s3_east_1.region,
                               access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
                               secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key)
end

def aws_west_provider
  Replication::AwsProvider.new(region: Settings.zip_endpoints.aws_s3_west_2.region,
                               access_key_id: Settings.zip_endpoints.aws_s3_west_2.access_key_id,
                               secret_access_key: Settings.zip_endpoints.aws_s3_west_2.secret_access_key)
end

def ibm_south_provider
  Replication::IbmProvider.new(region: Settings.zip_endpoints.ibm_us_south.region,
                               access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
                               secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key)
end


def all_cloud_providers
  [aws_east_provider, aws_west_provider, ibm_south_provider]
end

def bucket_object_keys(bucket_objects)
  bucket_objects.map { |obj| obj.key }
end

def purge_druid_from_all_could_providers!(druid_str, dry_run: true)
  logger = Logger.new($stdout).extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'sdr_reset_cloud_archive_cleanup.log'))))

  logger.info "=== purging cloud copies for #{druid_str}"
  druid_obj = DruidTools::Druid.new(druid_str)

  all_cloud_providers.map do |provider|
    logger.info "= delete #{druid_str} from #{provider.aws_client_args.slice(:region, :endpoint)}"

    # all zips for all versions for this object, e.g. ['hx/900/cw/1590/hx900cw1590.v0001.zip', 'hx/900/cw/1590/hx900cw1590.v0002.zip', 'hx/900/cw/1590/hx900cw1590.v0003.zip']
    bucket_objects = provider.bucket.objects(prefix: druid_obj.tree.join('/'))
    pre_delete_bucket_object_keys = bucket_object_keys(bucket_objects)
    if dry_run
      logger.info "  # dry run, not deleting - #{pre_delete_bucket_object_keys}"
      del_result = nil
    else
      logger.info "  ! actual run, deleting - #{pre_delete_bucket_object_keys}"
      del_result = bucket_objects.map { |obj| obj.delete }
      logger.info "  post-delete: bucket_objects keys: #{bucket_object_keys(bucket_objects)}"
    end

    {
      druid: druid_str,
      pre_delete_bucket_object_keys:,
      delete_result: del_result
    }
  rescue StandardError => e
    logger.error "!! Error deleting #{druid_str} from #{provider.aws_client_args.slice(:region, :endpoint)}: #{e.message} #{e.backtrace.join("\n")}"
    {
      druid: druid_str,
      error_msg: e.message,
      error_backtrace: e.backtrace
    }
  end

rescue StandardError => e
  logger.error "!!! Error deleting #{druid_str}: #{e.message} #{e.backtrace.join("\n")}"
  {
    druid: druid_str,
    dry_run:,
    error_msg: e.message,
    error_backtrace: e.backtrace
  }
end



druid_filename = '/opt/app/pres/druids_pre_reset.txt'
druid_list = File.readlines(druid_filename).map!(&:chomp) # chomp the trailing newline

# smoke test before doing the whole list
test_druid = druid_list.first
purge_druid_from_all_could_providers!(test_druid)
purge_druid_from_all_could_providers!(test_druid, dry_run: false)

# dry run on the first 10, to do for real add param `dry_run: false`
druid_list.take(10).map { |druid_str| purge_druid_from_all_could_providers!(druid_str) }
```

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

Let's make sre Postgres is installing and running.
`postgres -V`

#### 2. Configuring Postgres

The `psql` utility, which lets you carry out admin functions.

Enter `psql postgres` into the command line.
Create your username and password by entering the following into the command line.
`CREATE USER 'your_username' WITH PASSWORD 'your_password';`

Next create the name of your database.
`CREATE DATABASE 'name of database';`

Grant superuser privileges so you can create and drop database.
`GRANT ALL PRIVILEGES ON DATABASE 'database name' TO 'your_username';`
`ALTER USER 'your_username' WITH SUPERUSER;`

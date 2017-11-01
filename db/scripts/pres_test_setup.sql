CREATE USER pres_test;
ALTER USER pres_test CREATEDB;
CREATE DATABASE pres_test;
ALTER DATABASE pres_test OWNER TO pres_test;
GRANT ALL PRIVILEGES ON DATABASE pres_test TO pres_test;

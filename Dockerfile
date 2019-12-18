FROM ruby:2.5.3-alpine

# postgresql-client is required for invoke.sh
RUN apk --no-cache add \
  postgresql-dev \
  postgresql-client \
  tzdata

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN apk --no-cache add --virtual build-dependencies \
  build-base \
  && bundle install --without development test\
  && apk del build-dependencies

COPY . .

LABEL maintainer="Aaron Collier <aaron.collier@stanford.edu>"

ENV RAILS_ENV=production

CMD ["./docker/invoke.sh"]
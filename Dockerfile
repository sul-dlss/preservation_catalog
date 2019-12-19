FROM ruby:2.5.3-alpine

# postgresql-client is required for invoke.sh
RUN apk --no-cache add \
  postgresql-dev \
  postgresql-client \
  tzdata \
  libxml2-dev \
  libxslt-dev

LABEL maintainer="Aaron Collier <aaron.collier@stanford.edu>"

RUN mkdir /app
WORKDIR /app

# Using argument for conditional setup in conf file  
ARG RAILS_ENV
ENV RAILS_ENV $RAILS_ENV

RUN gem update --system && \
  gem install bundler && \
  bundle config build.nokogiri --use-system-libraries

COPY Gemfile Gemfile.lock ./

RUN apk --no-cache add --virtual build-dependencies \
  build-base \
  && bundle install --without development test\
  && apk del build-dependencies

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
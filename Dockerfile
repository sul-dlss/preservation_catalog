FROM ruby:3.4.1-bookworm

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        postgresql-client postgresql-contrib libpq-dev build-essential \
        libxml2-dev libxslt-dev

LABEL maintainer="Aaron Collier <aaron.collier@stanford.edu>"

RUN mkdir /app
WORKDIR /app

# Using argument for conditional setup in conf file
ARG RAILS_ENV
ENV RAILS_ENV $RAILS_ENV
ARG BUNDLE_GEMS__CONTRIBSYS__COM
ENV BUNDLE_GEMS__CONTRIBSYS__COM $BUNDLE_GEMS__CONTRIBSYS__COM

RUN gem update --system && \
  gem install bundler && \
  bundle config build.nokogiri --use-system-libraries

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

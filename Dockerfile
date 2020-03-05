FROM ruby:2.6.3-alpine
LABEL maintainer="BobChaos <chamberland.marc@gmail.com>"

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ENV RAILS_ENV production

# Install dependencies:
# - build-base: To ensure certain gems can be compiled
# - nodejs: Compile assets
# - postgresql-dev postgresql-client: Communicate with postgres through the postgres gem
# - libxslt-dev libxml2-dev: Nokogiri native dependencies
# - imagemagick: for image processing
RUN apk --update add build-base nodejs tzdata postgresql-dev postgresql-client libxslt-dev libxml2-dev imagemagick sqlite-dev

COPY Gemfile /usr/src/app/ 
COPY Gemfile.lock /usr/src/app/ 

# So we're sure to have newer than whatever created the lockfile
RUN gem install bundler \
&& bundle install --deployment --without development test

COPY . /usr/src/app

EXPOSE 3000
ENTRYPOINT ["./entrypoint.sh"]

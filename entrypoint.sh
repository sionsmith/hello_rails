#!/bin/sh
bundle exec rake assets:precompile
bundle exec rails server -b 0.0.0.0

#!/bin/bash
export HYPER_DEV_GEM_SOURCE='https://gems.ruby-hyperloop.org'
bundle install
cd spec/test_app
bundle install
bundle exec rails db:setup
cd ../..

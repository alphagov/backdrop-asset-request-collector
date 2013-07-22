#!/bin/bash -xe
time bundle install --path "${HOME}/bundles/${JOB_NAME}" --deployment
time bundle exec rake test --trace
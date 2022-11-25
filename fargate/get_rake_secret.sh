#!/bin/sh
docker run tootsuite/mastodon bundle exec rake secret | sed 's/\(.*\)/{"secret": "\1"}/'

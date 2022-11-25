#!/bin/sh
docker run tootsuite/mastodon bundle exec rake mastodon:webpush:generate_vapid_key | tr '\n' '*' | sed 's/VAPID_PRIVATE_KEY=\([^\*]*\)\*VAPID_PUBLIC_KEY=\(.*\)\*/{"private_key": "\1", "public_key": "\2"}/'

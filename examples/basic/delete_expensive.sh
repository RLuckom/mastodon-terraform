#!/bin/sh
terraform destroy -target=module.mastodon_web -target=module.mastodon_stream -target=module.mastodon_sidekiq -target aws_db_instance.mastodon -target=aws_elasticache_replication_group.redis -target=aws_alb.mastodon -target=aws_ecs_cluster.mastodon

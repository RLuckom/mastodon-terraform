resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.redis.name}-${local.unique_suffix}"
  engine               = "redis"
  node_type            = var.redis.node_type
  num_cache_nodes      = 1
  parameter_group_name = var.redis.parameter_group_name
  engine_version       = var.redis.engine_version
  port                 = var.redis.port
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis_ingress.id]
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "mastodon-redis-public-${local.unique_suffix}"
  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
}

resource "random_password" "postgres" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "mastodon" {
  allocated_storage    = var.postgres.allocated_storage_gb
  db_name              = "${var.postgres.name}${local.unique_suffix}"
  skip_final_snapshot  = true
  engine               = "postgres"
  engine_version       = var.postgres.engine_version
  instance_class       = var.postgres.instance_class
  username             = var.postgres.username
  password             = random_password.postgres.result
  vpc_security_group_ids = [aws_security_group.postgres_ingress.id]
  db_subnet_group_name = aws_db_subnet_group.mastodon-postgres.name
  tags = {
    "Name" = "mastodon-${local.unique_suffix}-postgres"
  }
}

resource "aws_db_subnet_group" "mastodon-postgres" {
  name       = "mastodon-postgres-public-${local.unique_suffix}"
  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
}

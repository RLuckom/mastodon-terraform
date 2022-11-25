resource "aws_vpc" "mastodon" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "mastodon-${local.unique_suffix}"
  }
}

module tls_cert {
  source = "github.com/RLuckom/terraform_modules//aws/validated_cert?ref=64a65d27"
  route53_zone_name = local.zone_name
  domain_name = local.mastodon_web_domain
  subject_alternative_names = var.mastodon_subject_alternative_names
}

data "aws_route53_zone" "parent" {
  name = local.zone_name
 }

locals {
  zone_name = "${var.mastodon_domain_parts.zone_level_domain}.${var.mastodon_domain_parts.top_level_domain}"
  mastodon_subdomain_part = var.mastodon_domain_parts.subdomain_part == "" ? "" : "${var.mastodon_domain_parts.subdomain_part}${var.mastodon_domain_parts.use_unique_suffix ? "-${local.unique_suffix}" : ""}."
  mastodon_web_domain = "${local.mastodon_subdomain_part}${var.mastodon_domain_parts.zone_level_domain}.${var.mastodon_domain_parts.top_level_domain}"
  mastodon_media_domain_controlled_part = "media.${local.mastodon_subdomain_part}${var.mastodon_domain_parts.zone_level_domain}"
  mastodon_media_domain_parts = {
    top_level_domain = var.mastodon_domain_parts.top_level_domain
    controlled_domain_part = local.mastodon_media_domain_controlled_part
  }
  mastodon_media_domain = "${local.mastodon_media_domain_parts.controlled_domain_part}.${local.mastodon_media_domain_parts.top_level_domain}"
}

data "aws_route53_zone" "selected" {
  name         = local.zone_name
  private_zone = false
}

resource "aws_route53_record" "site_a_record" {
  zone_id = data.aws_route53_zone.selected.id
  name    = local.mastodon_web_domain
  type    = "A"

  alias {
    zone_id = aws_cloudfront_distribution.reverse_proxy.hosted_zone_id
    name                   = aws_cloudfront_distribution.reverse_proxy.domain_name
    evaluate_target_health = true
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.mastodon.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = var.availability_zone_a
  tags = {
    "Name" = "mastodon-${local.unique_suffix}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.mastodon.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = var.availability_zone_b
  tags = {
    "Name" = "mastodon-${local.unique_suffix}-public-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mastodon.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
    instance_id = null
    nat_gateway_id = null
  }
  tags = {
    "Name" = "public"
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.mastodon.id
}

resource "aws_route" "public_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public.id
}

resource "aws_security_group" "ingress_mastodon_web" {
  name        = "mastodon_web-${local.unique_suffix}"
  description = "http traffic from lb"
  vpc_id      = aws_vpc.mastodon.id
  ingress {
    from_port   = var.mastodon_web.port
    to_port     = var.mastodon_web.port
    protocol    = "TCP"
    security_groups = [
      aws_security_group.lb.id,
    ]
  }
}

resource "aws_security_group" "ingress_mastodon_stream" {
  name        = "mastodon_stream-${local.unique_suffix}"
  description = "http traffic from lb"
  vpc_id      = aws_vpc.mastodon.id
  ingress {
    from_port   = var.mastodon_stream.port
    to_port     = var.mastodon_stream.port
    protocol    = "TCP"
    security_groups = [
      aws_security_group.lb.id,
    ]
  }
}

resource "aws_security_group" "ingress_mastodon_sidekiq" {
  name        = "mastodon_sidekiq-${local.unique_suffix}"
  description = "sidekiq origin group"
  vpc_id      = aws_vpc.mastodon.id
}

resource "aws_security_group" "postgres_ingress" {
  name        = "postgres-${local.unique_suffix}"
  vpc_id      = aws_vpc.mastodon.id

  ingress {
    description     = "Allow Postgres traffic from only the web sg"
    from_port       = "5432"
    to_port         = "5432"
    protocol        = "TCP"
    security_groups = [
      aws_security_group.ingress_mastodon_web.id,
      aws_security_group.ingress_mastodon_stream.id,
      aws_security_group.ingress_mastodon_sidekiq.id,
    ]
  }

  tags = {
    Name = "postgres ${local.unique_suffix} ingress"
  }
}

resource "aws_security_group" "redis_ingress" {
  name        = "redis-${local.unique_suffix}"
  vpc_id      = aws_vpc.mastodon.id

  ingress {
    description     = "Allow redis traffic from the fargate tasks"
    from_port       = "6379"
    to_port         = "6379"
    protocol        = "TCP"
    security_groups = [
      aws_security_group.ingress_mastodon_web.id,
      aws_security_group.ingress_mastodon_stream.id,
      aws_security_group.ingress_mastodon_sidekiq.id,
    ]
  }

  tags = {
    Name = "redis ${local.unique_suffix} ingress"
  }
}

resource "aws_security_group" "lb" {
  name        = "lb-${local.unique_suffix}"
  vpc_id      = aws_vpc.mastodon.id
  ingress {
    from_port   = var.mastodon_web.port
    to_port     = var.mastodon_web.port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.mastodon_stream.port
    to_port     = var.mastodon_stream.port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb ${local.unique_suffix} ingress"
  }
}

resource "aws_security_group" "egress_all" {
  name        = "egress-all-${local.unique_suffix}"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.mastodon.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "mastodon_web" {
  name        = "mastodon-web-${local.unique_suffix}"
  port        = var.mastodon_web.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.mastodon.id
  health_check {
    enabled = true
    path    = "/health"
  }
  depends_on = [aws_lb.mastodon]
}

resource "aws_lb_target_group" "mastodon_stream" {
  name        = "mastodon-stream-${local.unique_suffix}"
  port        = var.mastodon_stream.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.mastodon.id
  health_check {
    enabled = true
    path    = "/api/v1/streaming/health"
  }
  depends_on = [aws_lb.mastodon]
}

resource "aws_lb" "mastodon" {
  name               = "mastodon-${local.unique_suffix}"
  internal           = false
  load_balancer_type = "application"
  preserve_host_header = true
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
  security_groups = [
    aws_security_group.lb.id,
    aws_security_group.egress_all.id,
  ]
  access_logs {
    bucket  = aws_s3_bucket.access_logs.bucket
    prefix  = "mastodon"
    enabled = true
  }
  depends_on = [aws_internet_gateway.public]
}

resource "aws_lb_listener" "mastodon_web" {
  load_balancer_arn = aws_lb.mastodon.arn
  port              = var.mastodon_web.port
  protocol          = "HTTPS"
  certificate_arn = module.tls_cert.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mastodon_web.arn
  }
}

resource "aws_lb_listener" "mastodon_stream" {
  load_balancer_arn = aws_lb.mastodon.arn
  port              = var.mastodon_stream.port
  protocol          = "HTTPS"
  certificate_arn = module.tls_cert.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mastodon_stream.arn
  }
}

resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.log_bucket_name}-${local.unique_suffix}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.access_logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.s3_bucket_lb_write.json
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "s3_bucket_lb_write" {
  policy_id = "s3_bucket_lb_logs"

  statement {
    actions = [
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.access_logs.arn}/*",
    ]

    principals {
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
      type        = "AWS"
    }
  }

  statement {
    actions = [
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }


  statement {
    actions = [
      "s3:GetBucketAcl"
    ]
    effect = "Allow"
    resources = ["${aws_s3_bucket.access_logs.arn}"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}

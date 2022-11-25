resource "aws_cloudfront_distribution" "reverse_proxy" {
  enabled             = true
  aliases = [local.mastodon_web_domain] 
  origin {
    domain_name = aws_lb.mastodon.dns_name
    origin_id   = var.mastodon_web.name
    custom_header {
      name = "X_FORWARDED_PROTO"
      value = "https"
    }
    custom_origin_config {
      http_port              = 443
      https_port             = var.mastodon_web.port
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = aws_lb.mastodon.dns_name
    origin_id   = var.mastodon_stream.name
    custom_origin_config {
      http_port              = 80
      https_port             = var.mastodon_stream.port
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/api/v1/streaming/"
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.mastodon_stream.name

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.mastodon_web.name

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_200"

  viewer_certificate {
    acm_certificate_arn = module.tls_cert.cert.arn
    minimum_protocol_version = var.min_tls_version
    ssl_support_method = "sni-only"
  }
}

locals {
  cloudfront_origin_access_principals = [{
    type = "AWS"
    identifiers = [module.mastodon_media_origin.origin_access_identity.iam_arn]
  }]
}

resource "aws_iam_user_policy" "send_email" {
  name = "mastodon-email"
  user = aws_iam_user.mastodon_media.name
  policy = data.aws_iam_policy_document.mastodon_email.json
}

data "aws_iam_policy_document" "mastodon_email" {
  policy_id = "mastodon_email"
  statement {
    actions = [
      "ses:SendRawEmail",
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_user" "mastodon_media" {
  name = "mastodon-media-${local.unique_suffix}"
}

resource "aws_iam_access_key" "mastodon_media" {
  user    = aws_iam_user.mastodon_media.name
}

module media_bucket {
  source = "github.com/RLuckom/terraform_modules//snapshots/aws/state/object_store/website_bucket?ref=64a65d27"
  unique_suffix = local.unique_suffix
  name = "mastodon-media"
  enable_acls = true
  account_id = local.account_id
  region = var.region
  force_destroy = var.force_destroy_media_bucket
  domain_parts = local.mastodon_media_domain_parts
  cors_rules = [{
    expose_headers = []
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 300
  }]
  principal_prefix_object_permissions = concat(
    [
      {
        permission_type = "read_write_objects",
        prefix = ""
        principals = [{
          type = "AWS"
          identifiers = [aws_iam_user.mastodon_media.arn]
        }]
      },
      {
        permission_type = "read_write_object_acls",
        prefix = ""
        principals = [{
          type = "AWS"
          identifiers = [aws_iam_user.mastodon_media.arn]
        }]
      },
      {
        permission_type = "delete_object",
        prefix = ""
        principals = [{
          type = "AWS"
          identifiers = [aws_iam_user.mastodon_media.arn]
        }]
      },
    ],
  )
  website_access_principals = local.cloudfront_origin_access_principals
}

module mastodon_media_origin {
  source = "github.com/RLuckom/terraform_modules//aws/cloudfront_s3_website?ref=64a65d27"
  unique_suffix = local.unique_suffix
  enable_distribution = true
  website_buckets = [{
    origin_id = local.mastodon_media_domain_parts.controlled_domain_part
    regional_domain_name = "${module.media_bucket.bucket_name}.s3.${var.region == "us-east-1" ? "" : "${var.region}."}amazonaws.com"
  }]
  routing = {
    domain_parts = local.mastodon_media_domain_parts
    domain = local.mastodon_media_domain
    route53_zone_name = local.zone_name 
  }
  system_id = {
    security_scope = "${var.mastodon_family_name}-${local.unique_suffix}"
    subsystem_name = "media"
  }
}

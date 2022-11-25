resource "aws_ses_domain_identity" "mastodon" {
  domain = local.mastodon_web_domain
}

resource "aws_ses_domain_mail_from" "mastodon" {
  domain           = aws_ses_domain_identity.mastodon.domain
  mail_from_domain = local.mail_from_domain
}
locals {
  mail_from_domain = "mail.${aws_ses_domain_identity.mastodon.domain}"
}

resource "aws_route53_record" "example_ses_domain_mail_from_mx" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = aws_ses_domain_mail_from.mastodon.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "mastodon_ses_domain_mail_from_txt" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = aws_ses_domain_mail_from.mastodon.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "verification" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.mastodon.id}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.mastodon.verification_token]
}

resource "aws_ses_domain_identity_verification" "verification" {
  domain = aws_ses_domain_identity.mastodon.id

  depends_on = [aws_route53_record.verification]
}

resource "aws_route53_record" "email" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = local.zone_name
  type    = "MX"
  ttl     = "600"
  records = ["10 inbound-smtp.${var.region}.amazonaws.com"]
}

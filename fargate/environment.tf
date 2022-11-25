resource "aws_ssm_parameter" "db_password" {
  name  = local.secret_parameter_names.db_password
  type  = "String"
  value = random_password.postgres.result
}

resource "aws_ssm_parameter" "smtp_password" {
  name  = local.secret_parameter_names.smtp_password
  type  = "String"
  value = aws_iam_access_key.mastodon_media.ses_smtp_password_v4
}

resource "aws_ssm_parameter" "redis_url" {
  name  = local.secret_parameter_names.redis_url
  type  = "String"
  value = "redis://:@${aws_elasticache_cluster.redis.cache_nodes[0].address}:${var.redis.port}"
}

resource "aws_ssm_parameter" "media_aws_access_key" {
  name  = local.secret_parameter_names.media_key
  type  = "String"
  value = aws_iam_access_key.mastodon_media.id
}

resource "aws_ssm_parameter" "media_aws_secret_access_key" {
  name  = local.secret_parameter_names.media_secret_key
  type  = "String"
  value = aws_iam_access_key.mastodon_media.secret
}

resource "aws_ssm_parameter" "secret_key_base" {
  name  = local.secret_parameter_names.secret_key_base
  type  = "String"
  value = data.external.secret_key_base.result.secret
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "otp_secret" {
  name  = local.secret_parameter_names.otp_secret
  type  = "String"
  value = data.external.otp_secret.result.secret
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "vapid_private_key" {
  name  = local.secret_parameter_names.vapid_private_key
  type  = "String"
  value = data.external.vapid_keys.result.private_key
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "vapid_public_key" {
  name  = local.secret_parameter_names.vapid_public_key
  type  = "String"
  value = data.external.vapid_keys.result.public_key
  lifecycle {
    ignore_changes = [value]
  }
}

data "external" "vapid_keys" {
  program = ["/bin/sh", "${path.module}/get_vapid_keys.sh"]
}

data "external" "secret_key_base" {
  program = ["/bin/sh", "${path.module}/get_rake_secret.sh"]
}

data "external" "otp_secret" {
  program = ["/bin/sh", "${path.module}/get_rake_secret.sh"]
}

locals {
  secret_parameter_names = {
    db_password = "mastodon-${local.unique_suffix}-postgres-pass"
    redis_url = "mastodon-${local.unique_suffix}-redis-url"
    media_key = "mastodon-${local.unique_suffix}-media-key"
    media_secret_key = "mastodon-${local.unique_suffix}-media-secret-key"
    smtp_password = "mastodon-${local.unique_suffix}-smtp-password"
    secret_key_base = "mastodon-${local.unique_suffix}-secret-key-base"
    otp_secret = "mastodon-${local.unique_suffix}-otp-secret"
    vapid_private_key = "mastodon-${local.unique_suffix}-vapid-privkey"
    vapid_public_key = "mastodon-${local.unique_suffix}-vapid-pubkey"
  }
  secrets = {
    DB_PASS = local.secret_parameter_names.db_password
    SMTP_PASSWORD = local.secret_parameter_names.smtp_password
    REDIS_URL = local.secret_parameter_names.redis_url
    AWS_ACCESS_KEY_ID = local.secret_parameter_names.media_key
    AWS_SECRET_ACCESS_KEY = local.secret_parameter_names.media_secret_key
    SMTP_LOGIN = local.secret_parameter_names.media_key
    SECRET_KEY_BASE = local.secret_parameter_names.secret_key_base
    OTP_SECRET = local.secret_parameter_names.otp_secret
    VAPID_PRIVATE_KEY = local.secret_parameter_names.vapid_private_key
    VAPID_PUBLIC_KEY = local.secret_parameter_names.vapid_public_key
  }
  environment = {
    DB_HOST = aws_db_instance.mastodon.address
    DB_NAME = aws_db_instance.mastodon.name
    DB_POOL = ""
    DEFAULT_LOCALE = ""
    ES_ENABLED = ""
    ES_HOST = ""
    ES_PORT = ""
    LOCAL_DOMAIN = local.mastodon_web_domain
    WEB_DOMAIN = local.mastodon_web_domain
    ALTERNATE_DOMAINS = aws_lb.mastodon.dns_name
    LIMITED_FEDERATION_MODE = ""
    SINGLE_USER_MODE = ""
    MALLOC_ARENA_MAX = ""
    NODE_ENV = "production"
    RAILS_ENV = "production"
    RAILS_LOG_LEVEL = "debug"

    // TODO: to avoid this, one could make a CDN-bucket, local-exec the container,
    // copy the assets out of it and upload them to the CDN-bucket, and 
    // fill in the CDN_HOST variable with the domain given to the bucket.
    RAILS_SERVE_STATIC_FILES = "true"

    REDIS_HOST = aws_elasticache_cluster.redis.cache_nodes[0].address
    REDIS_PORT = "${var.redis.port}"
    S3_BUCKET = module.media_bucket.bucket.id
    S3_ENABLED = "true"
    S3_REGION = var.region
    S3_ALIAS_HOST = local.mastodon_media_domain
    SMTP_DELIVERY_METHOD = "smtp"
    SMTP_DOMAIN = local.mail_from_domain
    SMTP_ENABLE_STARTTLS = "auto"
    SMTP_FROM_ADDRESS = "mastodon@${local.mail_from_domain}"
    SMTP_PORT = "587"
    SMTP_SERVER = "email-smtp.${var.region}.amazonaws.com"
    STREAMING_CLUSTER_NUM = ""
    STREAMING_API_BASE_URL = ""
    OIDC_ENABLED = ""
    OIDC_DISPLAY_NAME = ""
    OIDC_ISSUER = ""
    OIDC_DISCOVERY = ""
    OIDC_SCOPE = ""
    OIDC_UID_FIELD = ""
    OIDC_CLIENT_ID = ""
    OIDC_CLIENT_SECRET = ""
    OIDC_REDIRECT_URI = ""
    OIDC_SECURITY_ASSUME_EMAIL_IS_VERIFIED = ""
    OIDC_CLIENT_AUTH_METHOD = ""
    OIDC_RESPONSE_TYPE = ""
    OIDC_RESPONSE_MODE = ""
    OIDC_DISPLAY = ""
    OIDC_PROMPT = ""
    OIDC_SEND_NONCE = ""
    OIDC_SEND_SCOPE_TO_TOKEN_ENDPOINT = ""
    OIDC_IDP_LOGOUT_REDIRECT_URI = ""
    OIDC_HTTP_SCHEME = ""
    OIDC_HOST = ""
    OIDC_PORT = ""
    OIDC_JWKS_URI = ""
    OIDC_AUTH_ENDPOINT = ""
    OIDC_TOKEN_ENDPOINT = ""
    OIDC_USER_INFO_ENDPOINT = ""
    OIDC_END_SESSION_ENDPOINT = ""
    SAML_ENABLED = ""
    SAML_ACS_URL = ""
    SAML_ISSUER = ""
    SAML_IDP_SSO_TARGET_URL = ""
    SAML_IDP_CERT = ""
    SAML_IDP_CERT_FINGERPRINT = ""
    SAML_NAME_IDENTIFIER_FORMAT = ""
    SAML_CERTSAML_PRIVATE_KEY = ""
    SAML_SECURITY_WANT_ASSERTION_SIGNED = ""
    SAML_SECURITY_WANT_ASSERTION_ENCRYPTED = ""
    SAML_SECURITY_ASSUME_EMAIL_IS_VERIFIED = ""
    SAML_UID_ATTRIBUTE = ""
    SAML_ATTRIBUTES_STATEMENTS_UID = ""
    SAML_ATTRIBUTES_STATEMENTS_EMAIL = ""
    SAML_ATTRIBUTES_STATEMENTS_FULL_NAME = ""
    SAML_ATTRIBUTES_STATEMENTS_FIRST_NAME = ""
    SAML_ATTRIBUTES_STATEMENTS_LAST_NAME = ""
    SAML_ATTRIBUTES_STATEMENTS_VERIFIED = ""
    SAML_ATTRIBUTES_STATEMENTS_VERIFIED_EMAIL = ""
    OAUTH_REDIRECT_AT_SIGN_IN = ""
    CAS_ENABLED = ""
    CAS_URL = ""
    CAS_HOST = ""
    CAS_PORT = ""
    CAS_SSL = ""
    CAS_VALIDATE_URL = ""
    CAS_CALLBACK_URL = ""
    CAS_LOGOUT_URL = ""
    CAS_LOGIN_URL = ""
    CAS_UID_FIELD = ""
    CAS_CA_PATH = ""
    CAS_DISABLE_SSL_VERIFICATION = ""
    CAS_SECURITY_ASSUME_EMAIL_IS_VERIFIED = ""
    CAS_UID_KEY = ""
    CAS_NAME_KEY = ""
    CAS_EMAIL_KEY = ""
    CAS_NICKNAME_KEY = ""
    CAS_FIRST_NAME_KEY = ""
    CAS_LAST_NAME_KEY = ""
    CAS_LOCATION_KEY = ""
    CAS_IMAGE_KEY = ""
    CAS_PHONE_KEY = ""
    PAM_ENABLED = ""
    PAM_EMAIL_DOMAIN = ""
    PAM_DEFAULT_SERVICE = ""
    PAM_CONTROLLED_SERVICE = ""
    LDAP_ENABLED = ""
    LDAP_HOST = ""
    LDAP_PORT = ""
    LDAP_METHOD = ""
    LDAP_BASE = ""
    LDAP_BIND_ON = ""
    LDAP_PASSWORD = ""
    LDAP_UID = ""
    LDAP_MAIL = ""
    LDAP_SEARCH_FILTER = ""
    LDAP_UID_CONVERSION_ENABLED = ""
    LDAP_UID_CONVERSION_SEARCH = ""
    LDAP_UID_CONVERSION_REPLACE = ""
  }
}

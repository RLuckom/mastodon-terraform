variable availability_zone_a {
  type = string
  default = "us-east-1a"
}

variable profile {
  type = string
  default = ""
}

variable availability_zone_b {
  type = string
  default = "us-east-1b"
}

variable mastodon_subdomain {
  type = string
  default = ""
}

variable log_bucket_name {
  type = string
  default = "mastodon"
}

variable region {
  type = string
  default = "us-east-1"
}

variable mastodon_family_name {
  type = string
  default = "mastodon"
}

variable mastodon_domain_parts {
  type = object({
    top_level_domain = string
    zone_level_domain = string
    subdomain_part = string
    use_unique_suffix = bool
  })
}

variable mastodon_subject_alternative_names {
  type = list(string)
  default = []
}

variable min_tls_version {
  type = string
  default = "TLSv1.2_2021"
}

variable force_destroy_media_bucket {
  type = bool
  default = false
}

variable mastodon_web {
  type = object({
    name = string
    db_migration_container_name = string
    port = number
    resources = object({
      mem = number
      cpu = number
     })
    num_tasks = number
    command = list(string)
    db_migration_command = list(string)
    health_check = list(string)
  })
  default = {
    name = "mastodon-web"
    db_migration_container_name = "mastodon_db_migration"
    port = 3000
    resources = {
      mem = 512
      cpu = 256
    }
    num_tasks = 1
    command = ["bundle", "exec", "puma", "-C", "config/puma.rb"]
    db_migration_command = ["bundle", "exec", "rake", "db:migrate"]
    health_check =  ["CMD-SHELL", "wget -q --spider --proxy=off localhost:3000/health || exit 1"]
  }
}

variable mastodon_stream {
  type = object({
    name = string
    port = number
    resources = object({
      mem = number
      cpu = number
     })
    num_tasks = number
    command = list(string)
    health_check = list(string)
  })
  default = {
    name = "mastodon-stream"
    port = 4000
    resources = {
      mem = 512
      cpu = 256
    }
    num_tasks = 1
    command = ["node", "./streaming"]
    health_check = ["CMD-SHELL", "wget -q --spider --proxy=off localhost:4000/api/v1/streaming/health || exit 1"]
  }
}

variable mastodon_sidekiq {
  type = object({
    name = string
    resources = object({
      mem = number
      cpu = number
     })
    num_tasks = number
    command = list(string)
    health_check = list(string)
  })
  default = {
    name = "mastodon-sidekiq"
    resources = {
      mem = 512
      cpu = 256
    }
    num_tasks = 1
    command = ["bundle", "exec", "sidekiq"]
    health_check = ["CMD-SHELL", "ps aux | grep '[s]idekiq\\ 6' || false"] 
  }
}

variable mastodon_image {
  type = object({
    name = string
    tag = string
  })
  default = {
    name =  "tootsuite/mastodon"
    tag = "latest"
  }
}

variable admin {
  type = object({
    user_email = string
    user_name = string
  })
}

variable redis {
  type = object({
    name = string
    node_type = string
    parameter_group_name = string
    engine_version = string
    port = number
  })
  default = {
    name = "mastodon"
    node_type = "cache.t4g.micro"
    parameter_group_name = "default.redis7"
    engine_version = "7.0"
    port = 6379
  }
}

variable postgres {
  type = object({
    name = string
    allocated_storage_gb = number
    engine_version = string
    instance_class = string
    username = string
  })
  default = {
    name = "mastodon"
    // $0.115 per GB-month as of 2022/11
    allocated_storage_gb = 10
    engine_version = "14.4"
    instance_class = "db.t4g.micro"
    username = "mastodon"
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "unique_suffix" {
  length           = 4
  min_lower        = 4
  special          = false
}

variable "unique_suffix" {
  type = string
  default = ""
}

locals {
  unique_suffix = var.unique_suffix == "" ? random_string.unique_suffix.result : var.unique_suffix
  account_id = data.aws_caller_identity.current.account_id
}

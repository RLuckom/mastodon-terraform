variable admin {
  type = object({
    user_email = string
    user_name = string
  })
}

variable mastodon_domain_parts {
  type = object({
    top_level_domain = string
    zone_level_domain = string
    subdomain_part = string
    use_unique_suffix = bool
  })
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

variable profile {
  type = string
  default = ""
}

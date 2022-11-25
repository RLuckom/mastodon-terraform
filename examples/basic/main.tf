module mastodon {
  source = "../../fargate"
  //source = "github.com/RLuckom/mastodon-terraform//fargate"
  admin = var.admin
  profile = var.profile
  mastodon_domain_parts = var.mastodon_domain_parts
  mastodon_image = var.mastodon_image
}

output mastodon_info {
  value = module.mastodon
}

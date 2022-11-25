output run_assign_owner_command {
  value = "aws ecs run-task ${var.profile == "" ? "" : "--profile '${var.profile}'"} --region='${var.region}' --cli-input-json file://$(pwd)/assign-owner.generated.json"
}

output browser_address {
  value = "https://${local.mastodon_web_domain}"
}

resource "local_file" "assign_owner_json" {
  content  = templatefile("${path.module}/run-task.json.template", {
    cluster = aws_ecs_cluster.mastodon.id
    task_definition = module.assign_owner_task.task.arn
    role = module.assign_owner_task.role.role.arn
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
    ]
    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_mastodon_sidekiq.id,
    ]
  })
  filename = "${path.root}/assign-owner.generated.json"
}

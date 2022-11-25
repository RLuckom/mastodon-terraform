module assign_owner_task {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_fargate_task?ref=64a65d27"
  name = "assign-owner"
  unique_suffix = local.unique_suffix
  region = var.region
  account_id = local.account_id
  cluster_id = aws_ecs_cluster.mastodon.id
  security_groups = [
    aws_security_group.egress_all.id,
    aws_security_group.ingress_mastodon_web.id,
  ]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
  task_config = {
    resources = {
      mem = 512
      cpu = 256
    }
    containers = [{
      name = "assign-owner"
      image = var.mastodon_image
      command = ["bin/tootctl", "accounts", "create", var.admin.user_name,  "--email", var.admin.user_email, "--confirmed", "--role", "Owner"]
      essential = null
      port_mappings = []
      depends_on = []
      health_check = {
        command = null
        interval = null
        retries = null
        timeout = null
        startPeriod = null
      }
      resources = {
        mem = 512
        cpu = 256
      }
      secrets = local.secrets
      environment = local.environment 
    }]
  }
}

resource "aws_ecs_cluster" "mastodon" {
   name = "${var.mastodon_family_name}-${local.unique_suffix}"
}

module "mastodon_web" {
  source = "github.com/RLuckom/terraform_modules//aws/fargate_service?ref=64a65d27"
  name = var.mastodon_web.name
  cluster_id = aws_ecs_cluster.mastodon.id
  account_id = local.account_id
  region = var.region
  unique_suffix = local.unique_suffix
  num_tasks = var.mastodon_web.num_tasks
  network_configuration = {
    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_mastodon_web.id,
    ]
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
    ]
    assign_public_ip = true
  }
  load_balancer_configs = [{
    target_group_arn = aws_lb_target_group.mastodon_web.arn
    container_name = var.mastodon_web.name
    container_port = var.mastodon_web.port
  }]
  task_config = {
    execution_role_arn = ""
    resources = {
      mem = var.mastodon_web.resources.mem * 2
      cpu = var.mastodon_web.resources.cpu * 2
    }
    containers = [{
      name = var.mastodon_web.db_migration_container_name
      essential = false
      depends_on = []
      command = var.mastodon_web.db_migration_command
      environment = local.environment
      health_check = {
        command = null
        startPeriod = null
        interval = null
        retries = null
        timeout = null
      }
      image = var.mastodon_image
      resources = var.mastodon_web.resources
      port_mappings = []
      secrets = local.secrets
      },{
      name = var.mastodon_web.name
      essential = true
      depends_on = [{
        condition = "SUCCESS"
        container_name = var.mastodon_web.db_migration_container_name
      }]
      command = var.mastodon_web.command
      environment = local.environment
      health_check = {
        command = var.mastodon_web.health_check
        startPeriod = 200
        interval = 30
        retries = 10
        timeout = 5
      }
      image = var.mastodon_image
      resources = var.mastodon_web.resources
      port_mappings = [{
        container_port = var.mastodon_web.port
        host_port = var.mastodon_web.port
        protocol = "tcp"
      }]
      secrets = local.secrets
    }]
  }
}

module "mastodon_stream" {
  source = "github.com/RLuckom/terraform_modules//aws/fargate_service?ref=64a65d27"
  name = var.mastodon_stream.name
  cluster_id = aws_ecs_cluster.mastodon.id
  account_id = local.account_id
  region = var.region
  num_tasks = var.mastodon_stream.num_tasks
  unique_suffix = local.unique_suffix
  network_configuration = {
    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_mastodon_stream.id,
    ]
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
    ]
    assign_public_ip = true
  }
  load_balancer_configs = [{
    target_group_arn = aws_lb_target_group.mastodon_stream.arn
    container_name = var.mastodon_stream.name
    container_port = var.mastodon_stream.port
  }]
  task_config = {
    execution_role_arn = ""
    resources = var.mastodon_stream.resources
    containers = [{
      name = var.mastodon_stream.name
      depends_on = []
      essential = true
      command = var.mastodon_stream.command
      environment = local.environment
      health_check = {
        command = var.mastodon_stream.health_check
        startPeriod = 200
        interval = 30
        retries = 10
        timeout = 5
      }
      image = var.mastodon_image
      resources = var.mastodon_stream.resources
      port_mappings = [{
        container_port = var.mastodon_stream.port
        host_port = var.mastodon_stream.port
        protocol = "tcp"
      }]
      secrets = local.secrets
    }]
  }
}

module "mastodon_sidekiq" {
  source = "github.com/RLuckom/terraform_modules//aws/fargate_service?ref=64a65d27"
  name = var.mastodon_sidekiq.name
  cluster_id = aws_ecs_cluster.mastodon.id
  account_id = local.account_id
  region = var.region
  unique_suffix = local.unique_suffix
  num_tasks = var.mastodon_sidekiq.num_tasks
  network_configuration = {
    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_mastodon_sidekiq.id,
    ]
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
    ]
    assign_public_ip = true
  }
  load_balancer_configs = []
  task_config = {
    execution_role_arn = ""
    resources = var.mastodon_sidekiq.resources
    containers = [{
      name = var.mastodon_sidekiq.name
      depends_on = []
      essential = true
      command = var.mastodon_sidekiq.command
      environment = local.environment
      health_check = {
        command = var.mastodon_sidekiq.health_check
        startPeriod = 200
        interval = 30
        retries = 10
        timeout = 5
      }
      image = var.mastodon_image
      resources = var.mastodon_sidekiq.resources
      port_mappings = []
      secrets = local.secrets
    }]
  }
}

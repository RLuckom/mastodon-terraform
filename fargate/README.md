### Disclaimer
Running this module will incur AWS costs to your account. It is your responsibility to look at the resources terraform is going to create and
understand the costs. Use at your own risk.

It is not recommended to use this module for production instances.

### Overview
The stack is one basic functioning Mastodon instance with its required services and data stores.
It does not include Elastic for full-text search. It has working email and working media uploads to s3.

The network architecture is a VPC with two public subnets, using security groups to lock down traffic.
Redis is provided by a small elasticache instance; Postgres is provided by a small RDS instance; all the
Mastodon containers are running on Fargate. Redis and Postgres only have private IPs and their security 
groups only allow traffic from Mastodon containers. The Mastodon containers have public IPs but only egress 
traffic is allowed over them. There is an application load balancer with IP addresses in the subnets; 
the ALB itself is behind Cloudfront. TLS is set up between the ALB and Cloudfront, and between Cloudfront 
and the browser. Traffic within the VPC is not encrypted. An S3 bucket handles media storage. SES is used 
for email. DNS is handled by Route53. Certificates are from ACM. The secrets are stored in Parameter Store 
and provided to the containers as environment variables. Everything is provisioned by Terraform except 
the manual approval of email addresses for SES and the rake task to add a user via the Mastodon CLI.

For more details see the [blog post](https://raphaelluckom.com/posts/Notes%20on%20a%20test%20Mastodon%20deployment.html)

### Prerequisites

1. A domain name and DNS hosted zone in AWS.
2. The ability to pull and run docker containers on the machine you're deploying from

### Usage

```
module mastodon {
  source = "github.com/RLuckom/mastodon-terraform//fargate"

  // this object controls the domain that mastodon will be served on.
  // top_level_domain: the TLD; "com", "org", "social" etc
  // zone_level_domain: This plus the tld should add up to your
  //   hosted zone. In this example, the hosted zone would be "example.com"
  // subdomain_part: the subdomain at which mastodon should be hosted. If 
  //   blank, mastodon will be hosted on the zone domain
  // use_unique_suffix: Whether to append a unique suffix to the subdomain
  //   so that multiple mastodons can be stood up with the same basic domain
  //   settings
  mastodon_domain_parts = {
    top_level_domain = "com"
    zone_level_domain = "example"
    subdomain_part = "mastodon"
    use_unique_suffix = true
  }

  // user name and email address of the account to be given the owner
  // role in the deployment
  admin = {
    user_email = "user@example"
    user_name  = "user"
  }

  // image repo and version
  mastodon_image = {
    name =  "tootsuite/mastodon"
    // latest version confirmed to work is 4.0.2
    tag = "latest"
  }
}

// This output contains instructions for running the
// task to add the admin user
output mastodon_info {
  value = module.mastodon
}
```

Once deployed, the output will include a `browser_address` field where the new Mastodon instance is hosted

### Manual Steps

1. Verify your email address to receive emails from AWS SES. Follow the 
  instructions [here](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html#verify-email-addresses-procedure).
2. Run the task to create the admin user. When you finish applying the terraform,
  the output will contain instructions for running an ECS task to create an admin user
  such as: `aws ecs run-task --profile 'default' --region='us-east-1' --cli-input-json file://$(pwd)/assign-owner.generated.json"`.
  Wait a few minutes after deploying until the site can be resolved and then run this task to create the admin
  user. To get the password, either log in to the AWS console and look at the cloudwatch logs for the task, or simplu
  use the Reset Password feature in the mastodon UI to set a new password.

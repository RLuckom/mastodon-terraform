### Disclaimer
Running this module will incur AWS costs to your account. It is your responsibility to look at the resources terraform is going to create and
understand the costs. Use at your own risk.

It is not recommended to use this module for production instances.

### Overview
This is an example of a terraform stack that uses the [fargate-based mastodon module](https://github.com/RLuckom/mastodon-terraform/tree/main/fargate)

The `versions.tf.example` and `domain.tfvars.example` files are templates. They assume a deployment using an S3 terraform state store.

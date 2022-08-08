# Description

Creates an AWS VPC with:
- [Application Load Balancer][aws_alb] (random assignment policy)
- [NAT][aws_nat] (for outward communication)
- EC2 [launch template][aws_launch_template] under a [scaling group][aws_scaling_group]
- [RDS][aws_rds]
- [Gateway][aws_gateway]
- creates private + public [subnets][aws_subnet] and [routing table][aws_routing_table]

Also uses [Route 53][aws_route53] to create a DNS record.

# Project Requirements

- [Homebrew][homebrew]
- [AWS CLI][aws_cli]
- [AWS admin account][aws_admin_account]
- [reusable delegation set][aws_reusable_delegation_set]
- Your own domain name.

Note that a reusable delegation set will _not_ be managed by Terraform and
will thus need to be manually created and deleted.

# SSH Key

It may be good practice to create a specific key for AWS. Skip this section if
you already have a preferred key.

```
cd ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/fatcat -C "fatcat@aws"
ssh-add fatcat
```

> Where `fatcat` is the filename for your new key, and `fatcat@aws` is an
arbitrary comment to help you remember what it is.

You may be prompted for a password. Choose a memorable password or none at all
(this is also considered acceptable security).

If you look at your folder, we should see two new files. `fatcat@aws` will be
your private key, not to be shared with the world, and `fatcat.pub` will be the
public key, which is safe to share with others.

# Installation

## Obtain a domain name

Skip this section if you already have a domain name. Otherwise go to a domain
registrar such as [Google Domains][google_domains] and register a domain at
approximately $12 per year for a `.com` domain.

Make sure to select any privacy options to stop people from spamming your real
address.

## AWS Setup

1. Install the official AWS CLI (command line interface).
   ```
   brew install awscli
   ```
2. Setup an AWS admin user
   - Go to IAM (Identity & Access Management) on AWS Console
   - Go to Users in the left navigation menu
   - Click **Add Users** button.
      - Provide a **User Name** and select both (all) credential types.
      - Provide a custom password.
      - Uncheck require password reset (not needed).
   - Click the **Next: Permissions** button.
      - Click **Attach existing policies directly** button.
      - Select `AdministratorAccess`. This provides all access _except_ for billing.
      - Click **Next: Tags** button.
        - Nothing needed.
      - Click **Next: Review** button.
        - You will see a summary of the changes you're about to make.
      - Click **Create user** button.
   - You will see a table with `Access key ID` and `Secret access key`. Record
     them both, as you may not be able to recover this.
3. Configure AWS CLI
   - Run `aws configure --profile username` where `username` is the name of your
     recently created admin user.
   - You will be prompted to enter your `Access key ID` and `Secret access key`
     for the AWS admin user you just created.
4. Use the AWS CLI to create a **reusable delegation set** for a more permanent
   set of name servers which persists despite Terraform. This also means that if
   you want to delete these name servers, then you will have to do it manually.
   ```
   aws route53 create-reusable-delegation-set --caller-reference example.com
   ```
   Where `example.com` is your registered domain. Record the four name servers
   you see.
5. Go to your domain registrar and choose the option for custom name servers and
   enter the name servers you just recorded.

## Terraform Setup

1. Install Terraform
   ```
   brew install terraform
   ```
2. Record your 12-digit AWS `Account ID`, such as by logging in and looking at
   the top right account area.
3. Navigate to `locals.tf` using your preferred code editor and set the
   following parameters:

| parameter           | description                                          |
| ------------------- | ---------------------------------------------------- |
| `aws_admin_user`    | AWS admin username                                   |
| `allowed_accounts`  | array should include the string of your `Account ID` |
| `ssh_key_name`      | arbitrary name of your SSH key pair                  |
| `ssh_key_public`    | the public part of your SSH key                      |
| `delegation_set_id` | the ID of the reusable delegation set you created    |
| `domain_name`       | the domain name you registered with your registrar   |

# Run Terraform

1. Navigate to the Terraform directory.
2. Run `terraform init` for your first time only to install any required plugins.
3. Run `terraform plan` to see what's about to change (optional).
4. Run `terraform apply` to deploy to AWS.
5. Run `terraform destroy` to destroy your deployment.

AWS may take 5 minutes (!) to get everything up due to backup procedures with
PostgreSQL.

When Terraform completes, it will inform you of the public IP address of your
instance. Login with `ssh ubuntu@address-goes-here`. Or you can just find your
EC2 instance on the console.

[aws_admin_account]: https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html
[aws_alb]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
[aws_cli]: https://aws.amazon.com/cli/
[aws_gateway]: https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html
[aws_launch_template]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html
[aws_nat]: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
[aws_rds]: https://aws.amazon.com/rds/
[aws_reusable_delegation_set]: https://docs.aws.amazon.com/Route53/latest/APIReference/API_CreateReusableDelegationSet.html
[aws_route53]: https://aws.amazon.com/route53/
[aws_routing_table]: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
[aws_subnet]: https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html
[aws_scaling_group]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html
[homebrew]: https://brew.sh/
[google_domains]: https://domains.google/get-started/domain-search/
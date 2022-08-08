# See: https://aws.amazon.com/rds/
# See: https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
resource "aws_db_instance" "REMEMBER_POSTGRES_DATABASE" {
  availability_zone = "us-west-2a"

  # AWS generally wants subnets in more than one AZ, so that it can store
  # geographically separated DB backups.
  # See: https://aws.amazon.com/rds/faqs/
  db_subnet_group_name = aws_db_subnet_group.REMEMBER_POSTGRES_SUBNET_GROUP.name
  vpc_security_group_ids = [
    aws_vpc.MEOW_VPC.default_security_group_id,
    aws_security_group.REMEMBER_POSTGRES_SECURITY_GROUP.id,
  ]
  multi_az = false

  # Terraform defaults to false here, overriding AWS default, but AWS has some
  # kind of more complicated decision criterion.
  # Search AWS API docs for "PubliclyAccessible": https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html
  publicly_accessible = false
  instance_class = "db.t4g.micro"

  # Required argument (unless restoring from a backup that already had this set).
  # See: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html#Concepts.DBInstanceClass.Support
  engine = "postgres"

  # Optional argument, but it's nice to be explicit about the version you get.
  # aws rds describe-db-engine-versions --engine postgres | jq '.DBEngineVersions[].EngineVersion'
  # See: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html
  engine_version = "14.2"

  # Username and password for the main database user are required. But we also
  # don't want to check them into the codebase. We cheat and load them from
  # AWS SSM parameters that we can for now manage by hand. The data sources for
  # them are below this RDS instance. We encrypt these sensitive values using
  # a key in the Key Management Service (KMS) that we, for now, manage by hand.
  # Of course, if this file never leaves your local disk, you can just type a 
  # username and password directly into the file.
  # See: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
  # See: https://aws.amazon.com/kms/
  username = local.postgres_user
  password = local.postgres_password
  db_name = "remember" # required: name of db
  port = 5432          # optional: default argument listed for explicitness

  # We must specify how much storage to allocate. Optionally, we can allocate
  # "growable" storage.
  # See: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.StorageTypes.html#USER_PIOPS.Autoscaling
  allocated_storage     = 20  # in GiB
  max_allocated_storage = 40  # in GiB

  # Default false. In general, you should leave this false in production
  # environments, so that you can't irrevocably delete databases by accident.
  skip_final_snapshot = true
  depends_on = [aws_internet_gateway.MEOW_INTERNET_GATEWAY]

  tags = { Name = "REMEMBER_POSTGRES_DATABASE" }
}

# Here are the data queries for the secret information we needed to set up the
# RDS user above. Note that Terraform can read existing SSM params (using the
# aws_ssm_parameter data source) as well as set up new ones (using the 
# aws_ssm_parameter resource). We are using the data source, because we are 
# managing the password manually outside of Terraform.
# For data: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter
# For resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
# data "aws_ssm_parameter" "REMEMBER_POSTGRES_USERNAME" {
#    name            = "REMEMBER_POSTGRES_USERNAME"
#    with_decryption = true
# }

# data "aws_ssm_parameter" "REMEMBER_POSTGRES_PASSWORD" {
#    name            = "REMEMBER_POSTGRES_PASSWORD"
#    with_decryption = true
# }

# This resource is needed for the RDS instance above. Note that we are not using
# replication and there is no standby to promote in case of failure.
# See: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html#USER_VPC.Subnets
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "REMEMBER_POSTGRES_SUBNET_GROUP" {
  # only lowercase characters allowed by AWS here for some reason
  name = "remember_postgres_subnet_group"
  # There must be at least two subnets in at least two different AZs.
  subnet_ids = [
    aws_subnet.MEOW_PRIVATE_SUBNET_A.id,
    aws_subnet.MEOW_PRIVATE_SUBNET_B.id,
  ]
  tags = { Name = "REMEMBER_POSTGRES_SUBNET_GROUP" }
}

# resource aws_subnet "REMEMBER_PRIVATE_SUBNET_DATABASES" {
#    vpc_id = aws_vpc.MEOW_VPC.id
#    cidr_block = "10.0.8.0/22"
#    availability_zone = "us-west-2a"
#    tags = { Name = "REMEMBER_PRIVATE_SUBNET_DATABASES" }
# }

# resource aws_subnet "REMEMBER_PRIVATE_SUBNET_BACKUPS" {
#    vpc_id = aws_vpc.MEOW_VPC.id
#    cidr_block = "10.0.12.0/22"
#    availability_zone = "us-west-2b"
#    tags = { Name = "REMEMBER_PRIVATE_SUBNET_BACKUPS" }
# }

resource "aws_security_group" "REMEMBER_POSTGRES_SECURITY_GROUP" {
  name   = "remember_postgres_security_group"
  vpc_id = aws_vpc.MEOW_VPC.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.MEOW_PUBLIC_SG.id]
  }
}

output "REMEMBER_POSTGRES_DATABASE_PRIVATE_URL" {
  value = aws_db_instance.REMEMBER_POSTGRES_DATABASE.endpoint
}
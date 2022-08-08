locals {
  key_name = "johnchon"
  key_public = ""
  aws_admin_user = "admin"
  allowed_accounts = [""]

  postgres_user     = "postgres"
  postgres_password = "postgres"

  // aws route53 create-reusable-delegation-set -- caller-reference vars.io
  // aws route53 list-reusable-delegation-sets
  delegation_set_id = ""
  domain_name       = "johnchon.com"
}
resource "aws_route53_zone" "ROOT_ZONE_MEOW" {
  delegation_set_id = local.delegation_set_id
  name              = local.domain_name
  force_destroy     = true
}

resource "aws_route53_record" "A_RECORD_MEOW" {
  zone_id = aws_route53_zone.ROOT_ZONE_MEOW.zone_id
  name    = local.domain_name # record name
  type    = "A"

  alias {
    name                   = aws_lb.MEOW_LOAD_BALANCER.dns_name
    zone_id                = aws_lb.MEOW_LOAD_BALANCER.zone_id
    evaluate_target_health = true
  }
}
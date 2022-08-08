output "LB_INFO" {
  value = {
    lb_dns = aws_lb.MEOW_LOAD_BALANCER.dns_name
  }
}

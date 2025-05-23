 module "levelup-vpc" {
     source      = "../module/vpc"

     ENVIRONMENT = var.ENVIRONMENT
     AWS_REGION  = var.AWS_REGION
 }

module "levelup-rds" {
    source      = "../module/rds"

    ENVIRONMENT = var.ENVIRONMENT
    AWS_REGION  = var.AWS_REGION
}

resource "aws_security_group" "levelup_webservers"{
  tags = {
    Name = "${var.ENVIRONMENT}-levelup-webservers"
  }
  
  name          = "${var.ENVIRONMENT}-levelup-webservers"
  description   = "Created by Levelup"
  vpc_id        = module.levelup-vpc.my_vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.SSH_CIDR_WEB_SERVER}"]

  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Resource key pair
resource "aws_key_pair" "levelup_key" {
  key_name      = "levelup_key"
  public_key    = file(var.public_key_path)
}

resource "aws_launch_configuration" "launch_config_webserver" {
  name   = "launch_config_webserver"
  image_id      = lookup(var.AMIS, var.AWS_REGION)
  instance_type = var.INSTANCE_TYPE
  user_data = "#!/bin/bash\napt-get update\napt-get -y install net-tools nginx\nMYIP=`ifconfig | grep -E '(inet 10)|(addr:10)' | awk '{ print $2 }' | cut -d ':' -f2`\necho 'Hello Team\nThis is my IP: '$MYIP > /var/www/html/index.html"
  security_groups = [aws_security_group.levelup_webservers.id]
  key_name = aws_key_pair.levelup_key.key_name
  
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }
}

resource "aws_autoscaling_group" "levelup_webserver" {
  name                      = "levelup_WebServers"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 30
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch_config_webserver.name
  vpc_zone_identifier       = ["${module.levelup-vpc.public_subnet1_id}", "${module.levelup-vpc.public_subnet2_id}"]
  target_group_arns         = [aws_lb_target_group.load-balancer-target-group.arn]
}

#Autoscaling Configuration policy - Scaling Alarm
resource "aws_autoscaling_policy" "levelup-cpu-policy" {
  name                   = "levelup-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.levelup_webserver.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "200"
  policy_type            = "SimpleScaling"
}


#Auto scaling Cloud Watch Monitoring
resource "aws_cloudwatch_metric_alarm" "levelup-cpu-alarm" {
  alarm_name          = "levelup-cpu-alarm"
  alarm_description   = "Alarm once CPU Uses Increase"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.levelup_webserver.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.levelup-cpu-policy.arn]
}


#Auto Descaling Policy
resource "aws_autoscaling_policy" "levelup-cpu-policy-scaledown" {
  name                   = "levelup-cpu-policy-scaledown"
  autoscaling_group_name = aws_autoscaling_group.levelup_webserver.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "200"
  policy_type            = "SimpleScaling"
}

#Auto descaling cloud watch 
resource "aws_cloudwatch_metric_alarm" "levelup-cpu-alarm-scaledown" {
  alarm_name          = "levelup-cpu-alarm-scaledown"
  alarm_description   = "Alarm once CPU Uses Decrease"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.levelup_webserver.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.levelup-cpu-policy-scaledown.arn]
}



#Application load balancer for app server
resource "aws_lb" "levelup-load-balancer" {
  name               = "${var.ENVIRONMENT}-levelup-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.levelup_webservers_alb.id]
  subnets            = ["${module.levelup-vpc.public_subnet1_id}", "${module.levelup-vpc.public_subnet2_id}"]

}

# Add Target Group
resource "aws_lb_target_group" "load-balancer-target-group" {
  name     = "load-balancer-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.levelup-vpc.my_vpc_id
}

# Adding HTTP listener
resource "aws_lb_listener" "webserver_listner" {
  load_balancer_arn = aws_lb.levelup-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.load-balancer-target-group.arn
    type             = "forward"
  }
}

output "load_balancer_output" {
  value = aws_lb.levelup-load-balancer.dns_name
}

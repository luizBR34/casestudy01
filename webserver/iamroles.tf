#Roles to access the AWS Ec2 Instance
resource "aws_iam_role" "ec2-instance-role" {
  name               = "ec2-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

#Policy to attach the Ec2 instance Role
resource "aws_iam_role_policy" "ec2-instance-role-policy" {
  name = "ec2-instance-role-policy"
  role = aws_iam_role.ec2-instance-role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ec2:RunInstances",
              "ec2:CreateLaunchTemplate",
              "ec2:CreateLaunchTemplateVersions",
              "ec2:DeleteLaunchTemplate",
              "ec2:DeleteLaunchTemplateVersions",
              "ec2:DescribeLaunchTemplate",
              "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": [
              "*"
            ]
        }
    ]
}
EOF

}

#Instance identifier
resource "aws_iam_instance_profile" "ec2-role-instanceprofile" {
  name = "ec2-instance-role"
  role = aws_iam_role.ec2-instance-role.name
}
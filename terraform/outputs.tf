################################################################
# URL output Jenkins
################################################################
output "url-jenkins" {
  value = "http://${aws_instance.jenkins-ci.public_ip}:8080"
}

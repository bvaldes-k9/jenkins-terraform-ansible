################################################################
# AWS Provider Variables
################################################################
provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}
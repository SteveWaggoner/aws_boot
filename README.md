## Bash script for launching an AWS instance to run demos from source code

This isn't generic at all but you can see how to do this for the following types of projects:
1. Gradle project running on Apache
2. Angular2 project
3. ScalaJs SBT project

This is using a plain vanilla Ubuntu AMI so the main issue is getting the prerequites installed on the server.

* aws_boot2.sh is cleaned-up version that removes Ruby on Rails and Amazon AMI support (rails is a pain to setup)


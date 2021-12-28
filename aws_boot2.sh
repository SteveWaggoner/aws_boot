#!/bin/bash -x

set -o nounset

function make_ubuntu_config() {

cat <<EOF > data/my_script.txt
#cloud-config
repo_update: true
repo_upgrade: all

write_files:
 -  path: /tmp/ubuntu_init.sh
    permissions: '0755'
    content: |
        #!/bin/bash -x

        #
        # Increase virtual memory
        #
        sudo dd if=/dev/zero of=/swap bs=1M count=1024
        sudo chmod 0600 /swap
        sudo mkswap /swap
        sudo swapon /swap

        #
        # Install Java JDK
        #
        sudo apt update
        sudo apt upgrade
        sudo apt install openjdk-8-jdk-headless --yes

        #
        # Install Apache webserver
        # 
        sudo apt install apache2 --yes
        sudo systemctl start apache2



        ###########################################
        # LET GET THE KOTLIN DEMO RUNNING
        #
        cd ~
        git clone https://github.com/SteveWaggoner/KotlinPhysics.git
        cd KotlinPhysics
        ./gradlew build

        cd /var/www/html
        sudo ln -s ~/KotlinPhysics

        ###########################################
        # LETS GET THE ANGULAR2 DEMO RUNNING (need more than 512Mb RAM)
        #
        
        # Install Node.js
        sudo apt-get install python-software-properties --yes
        curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
        sudo apt-get install nodejs --yes
        sudo npm install -g @angular/cli

        #
        cd ~
        git clone https://github.com/SteveWaggoner/AngularTabby.git
        cd AngularTabby
        npm install
        ng build --base-href AngularTabby
        sudo ln -s ~/AngularTabby/dist /var/www/html/AngularTabby

        ###########################################
        # LETS GET THE SCALA JS DEMO RUNNING 
        #
        
        # Install SBT 
        echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
        curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
        sudo apt-get update
        sudo apt-get install sbt

        #
        cd ~
        git clone https://github.com/SteveWaggoner/KlondikeJs.git
        cd KlondikeJs
        sbt run
        sudo ln -s ~/KlondikeJs/target/scala-2.12 /var/www/html/KlondikeJs

 -  path: /var/www/html/index.html
    permissions:  '0755'
    content: |
        <html>
        <head>
          <title>Test Server - PublicScript.com</title>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        </head>
        <h3>Demos built `TZ=PST8PDT date`</h3>
        <ul>
          <li><a href="/KotlinPhysics">Kotlin Physics</a></li>
          <li><a href="/AngularTabby">Angular Tabby</a></li>
          <li><a href="/KlondikeJs/classes">Klondike Js</a></li>
        </ul>
        </html>


runcmd:
 - sudo -u ubuntu -H sh -c "/tmp/ubuntu_init.sh"

EOF
}


#Ubuntu Server 18.04 LTS (HVM), SSD Volume Type - ami-cd0f5cb6
UBUNTU_AMI_18_04=ami-07ebfd5b3428b6f4d

#INSTANCE_TYPE=t2.nano
INSTANCE_TYPE=t2.micro


function launch_ec2() {

  local AMI_IMAGE_ID=$1

  aws ec2 run-instances --image-id $AMI_IMAGE_ID --count 1 --instance-type $INSTANCE_TYPE \
    --key-name stwaggoner-personal-aws --subnet-id subnet-88c39dfe --security-group-ids sg-0809fc78 \
    --block-device-mapping "[ { \"DeviceName\": \"/dev/sda1\", \"Ebs\": { \"VolumeSize\": 120 } } ]"  \
    --user-data file://data/my_script.txt  > data/last-instance.txt-new || exit 1
  mv data/last-instance.txt-new data/last-instance.txt

  INSTANCE_ID=`grep InstanceId data/last-instance.txt | cut -d\" -f4`

  aws ec2 create-tags --resources $INSTANCE_ID --tags "Key=Name,Value=My test.publicscript-dev (`date +%H%M`)"
  aws ec2 wait instance-running --instance-ids $INSTANCE_ID

  # test.publicscript.com
  # wikijs.com

  ELASTIC_PUBLIC_IP=34.206.230.49
  aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_PUBLIC_IP

}


make_ubuntu_config
launch_ec2 $UBUNTU_AMI_18_04


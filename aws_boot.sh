#!/bin/bash -x

set -o nounset

function make_amazon_config() {

cat <<EOF > data/my_script.txt
#cloud-config
repo_update: true
repo_upgrade: all

packages:
 - httpd24
 - php56
 - mysql55-server
 - php56-mysqlnd

runcmd:
 - service httpd start
 - chkconfig httpd on
 - groupadd www
 - [ sh, -c, "usermod -a -G www ec2-user" ]
 - [ sh, -c, "chown -R root:www /var/www" ]
 - chmod 2775 /var/www
 - [ find, /var/www, -type, d, -exec, chmod, 2775, {}, + ]
 - [ find, /var/www, -type, f, -exec, chmod, 0664, {}, + ]
 - [ sh, -c, 'echo "<?php phpinfo(); ?>" > /var/www/html/phpinfox.php' ]
EOF
}


function make_ubuntu_config() {

cat <<EOF > data/my_script.txt
#cloud-config
repo_update: true
repo_upgrade: all

packages:
 - openjdk-8-jdk-headless
 - apache2
# - nodejs-legacy
# - npm

write_files:
 -  path: /tmp/ubuntu_init.sh
    permissions: '0755'
    content: |
        #!/bin/bash -x

        #
        # LET'S GET THE RUBY ON RAILS DEMO RUNNING
        #
        cd ~
        git clone https://github.com/SteveWaggoner/RubyTest.git

        #
        # LET'S GET THE RUBY QUANT LANG APP RUNNING
        #
        cd ~
        git clone https://github.com/SteveWaggoner/QuantLang.git

        #
        # ...AND ALL THE RUBY RAILS DEPENDENCIES
        #
        sudo apt-get install ruby-full libgmp-dev gcc zlib1g-dev build-essential bison openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libxml2-dev autoconf libc6-dev ncurses-dev automake libtool libcurl4-openssl-dev apache2-dev libsqlite3-dev --yes
        sudo gem install rails
        sudo gem install passenger
        sudo gem install sqlite3
        sudo gem install puma
        sudo gem install sass-rails
        sudo gem install uglifier
        sudo gem install coffee-rails
        sudo gem install turbolinks
        sudo gem install jbuilder
        sudo gem install byebug
        sudo gem install capybara
        sudo gem install selenium-webdriver
        sudo gem install web-console

        #QuantLang
        sudo gem install treetop
        sudo gem install chronic
        sudo gem install rbtree
        
        #increase virtual memory
        sudo dd if=/dev/zero of=/swap bs=1M count=1024
        sudo mkswap /swap
        sudo swapon /swap

        sudo passenger-install-apache2-module
        sudo a2enconf rails-passenger

        #
        # ..AND CONFIGURE RAILS AND RESTART
        #
        sudo a2ensite AllRubyAppsUnderTest.conf
        sudo service apache2 reload
 

        #
        # LET GET THE KOTLIN DEMO RUNNING
        #
        cd ~
        git clone https://github.com/SteveWaggoner/KotlinPhysics.git
        cd KotlinPhysics
        ./gradlew build

        cd /var/www/html
        sudo ln -s ~/KotlinPhysics

        #
        # LETS GET THE ANGULAR2 DEMO RUNNING (need more than 512Mb RAM)
        #
        
        #Get Latest Node.js
        sudo apt-get install python-software-properties --yes
        curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
        sudo apt-get install nodejs --yes
        sudo npm install -g @angular/cli


        #
        cd ~
        git clone https://github.com/SteveWaggoner/AngularTabby.git
        cd AngularTabby
        npm install
        ng build --base-href AngularTabby
        sudo ln -s ~/AngularTabby/dist /var/www/html/AngularTabby

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
          <li><a href="/RubyTest">Ruby Test</a></li>
          <li><a href="/QuantLang">Quant Lang</a></li>
        </ul>
        </html>

 -  path: /etc/apache2/conf-available/rails-passenger.conf
    permissions:  '0755'
    content: |
        LoadModule passenger_module /var/lib/gems/2.3.0/gems/passenger-5.2.1/buildout/apache2/mod_passenger.so
        <IfModule mod_passenger.c>
          PassengerRoot /var/lib/gems/2.3.0/gems/passenger-5.2.1
          PassengerDefaultRuby /usr/bin/ruby2.3
        </IfModule>

 -  path: /etc/apache2/sites-available/AllRubyAppsUnderTest.conf
    permissions:  '0755'
    content: |
        <VirtualHost *:80>
          ServerName test.publicscript.com
          DocumentRoot /var/www/html

          <Directory />
            Options FollowSymLinks
            AllowOverride None
          </Directory>

          Alias /RubyTest /home/ubuntu/RubyTest/public
          <Directory /home/ubuntu/RubyTest>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Order allow,deny
            allow from all
          </Directory>
          <Directory /home/ubuntu/RubyTest/public>
            PassengerEnabled on
            PassengerAppEnv development
            SetHandler none
            PassengerAppRoot /home/ubuntu/RubyTest
            RailsBaseURI /RubyTest
            Options Indexes FollowSymLinks MultiViews
            AllowOverride None
            #Order allow,deny
            #allow from all
            Require all granted
          </Directory>

          Alias /QuantLang /home/ubuntu/QuantLang/public
          <Directory /home/ubuntu/QuantLang>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Order allow,deny
            allow from all
          </Directory>
          <Directory /home/ubuntu/QuantLang/public>
            PassengerEnabled on
            PassengerAppEnv development
            SetHandler none
            PassengerAppRoot /home/ubuntu/QuantLang
            RailsBaseURI /QuantLang
            Options Indexes FollowSymLinks MultiViews
            AllowOverride None
            #Order allow,deny
            #allow from all
            Require all granted
          </Directory>
        </VirtualHost>

runcmd:
 - sudo -u ubuntu -H sh -c "/tmp/ubuntu_init.sh"

EOF
}



#amzn-ami-hvm-2017.03.1.20170623-x86_64-gp2 (ami-a4c7edb2)
AMAZON_AMI=ami-a4c7edb2
#Ubuntu Server 16.04 LTS (HVM), SSD Volume Type - ami-cd0f5cb6
UBUNTU_AMI=ami-cd0f5cb6

#INSTANCE_TYPE=t2.nano
INSTANCE_TYPE=t2.micro


function launch_ec2() {
local AMI_IMAGE_ID=$1

aws ec2 run-instances --image-id $AMI_IMAGE_ID --count 1 --instance-type $INSTANCE_TYPE \
  --key-name stwaggoner-personal-aws --subnet-id subnet-88c39dfe --security-group-ids sg-0809fc78 \
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
launch_ec2 $UBUNTU_AMI


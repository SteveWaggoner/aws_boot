#!/bin/bash -x

set -o nounset

NOW=`date`

MY_USER=ubuntu
MY_DOMAIN=test.publicscript.com
MY_PROJECT=gunicorn_flask

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

        # built: $NOW

        #set -o nounset


        #
        # Increase virtual memory
        #
        sudo dd if=/dev/zero of=/swap bs=1M count=1024
        sudo chmod 0600 /swap
        sudo mkswap /swap
        sudo swapon /swap


        #
        # Install Nginx
        #
        sudo apt update
        sudo apt install nginx -y

        sudo ufw allow 'Nginx HTTP'

        sudo mkdir -p /var/www/$MY_DOMAIN/html
        sudo chown -R $MY_USER:$MY_USER /var/www/$MY_DOMAIN/html
        sudo chmod -R 755 /var/www/$MY_DOMAIN

        cat <<EOF > /var/www/$MY_DOMAIN/html/index.html

        <html>
          <head>
            <title>Welcome to $MY_DOMAIN!</title>
          </head>
          <body>
            <h1>Success! The $MY_DOMAIN server block is working!</h1>
          </body>
        </html>

        EOF

        
        sudo tee /etc/nginx/sites-available/$MY_DOMAIN > /dev/null <<EOF

        server {
           listen 80;
           listen [::]:80;

           root /var/www/$MY_DOMAIN/html;
           index index.html index.htm index.nginx-debian.html;

           server_name $MY_DOMAIN www.$MY_DOMAIN;

           location / {
                try_files \\\$uri \\\$uri/ =404;
           }
        }

        EOF

        sudo ln -s /etc/nginx/sites-available/$MY_DOMAIN /etc/nginx/sites-enabled/
        sudo systemctl restart nginx


        #
        # Install Gunicorn / Flask / Project
        #
        sudo apt update
        sudo apt install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools -y
        sudo apt install python3-venv -y

        mkdir /home/$MY_USER/$MY_PROJECT
        cd /home/$MY_USER/$MY_PROJECT
        python3.6 -m venv ${MY_PROJECT}_env
        source ${MY_PROJECT}_env/bin/activate
        pip install wheel 
        pip install gunicorn flask 
        pip install flask-sock
        deactivate
        
        cat <<EOF > /home/$MY_USER/$MY_PROJECT/${MY_PROJECT}.py

        from flask import Flask

        app = Flask(__name__)

        @app.route("/")
        def hello():
           return "<h1 style='color:blue'>Hello There from $MY_PROJECT!</h1>"


        if __name__ == "__main__":
           app.run(host='0.0.0.0')

        EOF

        cat <<EOF > /home/$MY_USER/$MY_PROJECT/wsgi.py

        from $MY_PROJECT import app

        if __name__ == "__main__":
           app.run()

        EOF


        sudo tee /etc/systemd/system/$MY_PROJECT.service > /dev/null <<EOF

        [Unit]
        Description=Gunicorn instance to serve $MY_PROJECT
        After=network.target

        [Service]
        User=$MY_USER
        Group=www-data
        WorkingDirectory=/home/$MY_USER/$MY_PROJECT
        Environment="PATH=/home/$MY_USER/$MY_PROJECT/${MY_PROJECT}_env/bin"
        ExecStart=/home/$MY_USER/$MY_PROJECT/${MY_PROJECT}_env/bin/gunicorn --workers 3 --bind unix:$MY_PROJECT.sock -m 007 wsgi:app

        [Install]
        WantedBy=multi-user.target

        EOF

        sudo systemctl start  $MY_PROJECT
        sudo systemctl enable $MY_PROJECT


        #
        # Connect Gunicorn to Nginx
        #

        sudo tee /etc/nginx/sites-available/$MY_PROJECT > /dev/null <<EOF

        server {
           listen 80;
           server_name $MY_DOMAIN www.$MY_DOMAIN;

           location / {
              include proxy_params;
              proxy_pass http://unix:/home/$MY_USER/$MY_PROJECT/$MY_PROJECT.sock;
           }
        }

        EOF

        sudo ln -s /etc/nginx/sites-available/$MY_PROJECT /etc/nginx/sites-enabled/
        sudo systemctl restart nginx
        sudo ufw allow 'Nginx Full'


        #
        # Integrate Quack network example with Flask
        #
        cd /home/$MY_USER/$MY_PROJECT
        git clone https://github.com/SteveWaggoner/Quack.git

        # append registering blueprint to app
        cat <<EOF >> /home/$MY_USER/$MY_PROJECT/${MY_PROJECT}.py

        # Quack echo example 
        from Quack.network import echo
        echo.register_page(app)

        EOF

        sudo systemctl stop  $MY_PROJECT
        sudo systemctl start $MY_PROJECT

        #
        # Install Git server into nginx
        # https://esc.sh/blog/setting-up-a-git-http-server-with-nginx/
        #
        sudo apt update
        sudo apt-get install nginx git fcgiwrap apache2-utils -y
        sudo mkdir -p /srv/git/repo1
        touch /tmp/blah
        sudo chown -R ubuntu:ubuntu /srv/git
        cd /srv/git/repo1
        sudo git init . --bare --shared
        git config --global --add safe.directory /srv/git/repo1
        sudo git update-server-info
        sudo cat <<EOF >> /srv/git/repo1/config

        [http]
            receivepack = true

        EOF

        sudo git config --bool core.bare true
        sudo chown -R www-data:www-data /srv/git

        sudo cat <<EOF >> /tmp/nginx-git

        server {
            listen       80;
            server_name  git.publicscript.com;

            # This is where the repositories live on the server
            root /srv/git;


            location ~ (/.*) {
              auth_basic "Restricted";
              auth_basic_user_file /etc/nginx/.gitpasswd;
              fastcgi_pass  unix:/var/run/fcgiwrap.socket;
              include       fastcgi_params;
              fastcgi_param SCRIPT_FILENAME     /usr/lib/git-core/git-http-backend;
              # export all repositories under GIT_PROJECT_ROOT
              fastcgi_param GIT_HTTP_EXPORT_ALL "";
              fastcgi_param GIT_PROJECT_ROOT    /srv/git;
              fastcgi_param PATH_INFO           \\\$1;
            }
        }

        EOF
        
        sudo chown root:root /tmp/nginx-git
        sudo mv /tmp/nginx-git /etc/nginx/sites-available/git

        cd /etc/nginx/sites-enabled && sudo ln -s /etc/nginx/sites-available/git
        sudo htpasswd -cb /etc/nginx/.gitpasswd test password
        sudo systemctl enable fcgiwrap
        sudo systemctl enable nginx
        sudo systemctl start fcgiwrap
        sudo systemctl start nginx
        #in case already running, restart, too	
        sudo systemctl restart nginx	


	#
	# Install Java/Scala/SBT
	#

	sudo apt install default-jdk -y
	sudo apt install scala -y

	# https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html
	sudo apt-get update
	sudo apt-get install apt-transport-https curl gnupg -yqq
	echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
	echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
	curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo -H gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import
	sudo chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg
	sudo apt-get update
	sudo apt-get install sbt

runcmd:
 - sudo -u ubuntu -H sh -c "/tmp/ubuntu_init.sh"

EOF
}


#Ubuntu Server 18.04 LTS (HVM), SSD Volume Type - ami-cd0f5cb6
UBUNTU_AMI_18_04=ami-07ebfd5b3428b6f4d

INSTANCE_TYPE=t2.nano
#INSTANCE_TYPE=t2.micro


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


make_ubuntu_config || exit 1
launch_ec2 $UBUNTU_AMI_18_04


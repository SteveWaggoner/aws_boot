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
        # Install Jupyter
        #
        sudo apt update

        sudo useradd jupyter
        echo 'jupyter:password' | sudo chpasswd

        curl -L https://tljh.jupyter.org/bootstrap.py \
        | sudo python3 - \
                --admin jupyter

        #
        # Install Ruby into Jupyter
        #
        sudo apt install libtool libffi-dev ruby ruby-dev make -y
        sudo gem install iruby
        sudo adduser jupyter-jupyter
        sudo -H -u jupyter-jupyter iruby register --force


        #
        # Install sshkernel (https://github.com/NII-cloud-operation/sshkernel/tree/master)
        #   (note: this breaks pip see https://github.com/NII-cloud-operation/sshkernel/issues/30)
        #sudo pip3 install -U sshkernel
        #sudo python3 -m sshkernel install
        #jupyter kernelspec list


        #
        # Install bash_kernel (https://github.com/takluyver/bash_kernel)
        #
        #sudo pip3 install bash_kernel
        sudo pip3 install git+https://github.com/takluyver/bash_kernel.git
        sudo python3 -m bash_kernel.install
        jupyter kernelspec list


runcmd:
 - sudo -u ubuntu -H sh -c "/tmp/ubuntu_init.sh"

EOF
}


#Ubuntu Server 18.04 LTS (HVM), SSD Volume Type - ami-cd0f5cb6
UBUNTU_AMI_18_04=ami-07ebfd5b3428b6f4d

UBUNTU_AMI_20_04=ami-0e3a6d8ff4c8fe246

INSTANCE_TYPE=t3.nano
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
#  aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_PUBLIC_IP

}


make_ubuntu_config || exit 1
launch_ec2 $UBUNTU_AMI_20_04


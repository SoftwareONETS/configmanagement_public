#!/bin/bash
OS_Architecture=$(hostnamectl | grep -i Architecture | awk '{print $2}')
OS_Release=$(cat /etc/os-release | grep -i ID_LIKE | cut -d "=" -f2)
OS_Version=$(cat /etc/os-release | grep -i VERSION_ID | head -n 1 | cut -d "=" -f2 | sed 's/"//g')
if [[ "$OS_Release" == "debian" ]]; then
echo "Installation is in process for OS Release $OS_Release Version $OS_Version Architecture $OS_Architecture!"
#!/bin/bash
mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
sudo start amazon-ssm-agent
elif [[ "$OS_Release" != "debian" ]]; then
#!/bin/bash
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo rpm --install /tmp/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo start amazon-ssm-agent
else
echo "Installation Not required or Platform is not Supported for OS $OS_Release Version $OS_Version Architecture $OS_Architecture!"
fi
#!/usr/bin/env bash

die_on_bad_cd()
{
  local folder=$1
  echo "Unable to cd to $folder"
  #exit 1
}

sudo apt-get install -y python-dev postgresql libpq-dev python-pip python-virtualenv git-core solr-jetty &&
sudo -H pip install --upgrade pip &&

#create ckan user
sudo adduser ckan

mkdir -p ~/ckan/lib &&
sudo ln -s ~/ckan/lib /usr/lib/ckan &&
mkdir -p ~/ckan/etc &&
sudo ln -s ~/ckan/etc /etc/ckan &&

sudo mkdir -p /usr/lib/ckan/default &&
sudo chown ckan /usr/lib/ckan/default &&
sudo mkdir -p /var/lib/ckan/resources &&
sudo chown -R ckan /var/lib/ckan &&

export LC_ALL="en_US.UTF-8" &&
export LC_CTYPE="en_US.UTF-8"

sudo su ckan #enter password
virtualenv --no-site-packages /usr/lib/ckan/default
. /usr/lib/ckan/default/bin/activate

#deactivate

cd ~ || die_on_bad_cd "$HOME" &&
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.7' &&
pip install -r /usr/lib/ckan/default/src/ckan/requirements.txt --allow-all-external &&
echo "OK"

##	for verification
#deactivate
#. /usr/lib/ckan/default/bin/activate

exit #leave ckan user shell

#check databases (must be utf8)
#sudo -u postgres psql -l;

#create postgresql user
sudo -u postgres createuser -S -D -R -P ckan_default

#create CKAN database
sudo -u postgres createdb -O ckan_default ckan_default -E utf-8

#Create a CKAN config file
sudo mkdir -p /etc/ckan/default &&
sudo chown -R ckan /etc/ckan/ &&
sudo chown -R ckan ~/ckan/etc &&
sudo chown -R ckan  ~/ckan/etc &&

#edit Jetty8 configuration
sudo vim /etc/default/jetty8

#Replace sections
#   NO_START=0                            -> NO_START=0            # (line 4)
#   #JETTY_HOST=$(uname -n)               -> JETTY_HOST=127.0.0.1  # (line 16)
#   #JETTY_PORT=8080                      -> JETTY_PORT=8983       # (line 19)

#save (type :wq ENTER)

printf "Edit Jetty config file at /etc/default/jetty8"
read

#Replace the default schema.xml file with a symlink to the CKAN schema file included in the sources.
sudo mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak &&
sudo ln -s /usr/lib/ckan/default/src/ckan/ckan/config/solr/schema.xml /etc/solr/conf/schema.xml &&
sudo service jetty8 restart

#check if jetty runs at the correct port
telnet localhost 8983 #should show "Escape character is '^]'"

#create ckan configuration file
sudo apt-get -y install python-pastescript

# Verify that the ckan user directory has been created
sudo su ckan
cd ~ || die_on_bad_cd "$HOME"

#activate python virtualenv
virtualenv --no-site-packages /usr/lib/ckan/default
. /usr/lib/ckan/default/bin/activate

#create default ckan config file
paster make-config ckan /etc/ckan/default/development.ini

#create your logfiles Directory
sudo mkdir -p /var/log/ckan &&
sudo chown -R ckan /var/log/ckan

#Replace sections in CKAN configuration
vim /etc/ckan/default/development.ini

#Replace sections
#   #solr_url = http://127.0.0.1:8983/solr                            -> solr_url=http://127.0.0.1:8983/solr
#   ckan.site_url =                             -> ckan.site_url = http://<IP/name of the machine.xpto.com>
#   #DB PASSWORD
#   sqlalchemy.url = postgresql://ckan_default:pass@localhost/ckan_default =                             -> sqlalchemy.url = postgresql://ckan_default:ckan@localhost/ckan_default #ASSUMING THE postgresql credentials are: password 'ckan';  username 'ckan_default'

# Logging configuration
# (NOTE THAT YOUR log file path is at the end of this section, change it accordingly!a)

# ## Logging configuration
# [loggers]
# keys = root, ckan, ckanext
#
# [handlers]
# keys = console
#
# [formatters]
# keys = generic
#
# [logger_root]
# level = WARNING
# handlers = console, file
#
# [logger_ckan]
# level = INFO
# handlers = console,file
# qualname = ckan
# propagate = 0
#
# [logger_ckanext]
# level = DEBUG
# handlers = console,file
# qualname = ckanext
# propagate = 0
#
# [handler_console]
# class = StreamHandler
# args = (sys.stderr,)
# level = NOTSET
# formatter = generic
#
# [handler_file]
# class = handlers.TimedRotatingFileHandler
# args = ('/var/log/ckan/default_development.log', 'W0', 1, 4)
# level = NOTSET
# formatter = generic

#save (type :wq ENTER)

#Create database tables
cd /usr/lib/ckan/default/src/ckan || die_on_bad_cd "/usr/lib/ckan/default/src/ckan"
pip install -I html5lib==0.9999999
paster db init -c /etc/ckan/default/development.ini

#link who.ini
ln -s /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/default/who.ini

#start server (make sure you have the python virtual env activated before)
#the command line should be like >>>>>>(default)<<<<<<< ckan@yulia-VirtualBox:/usr/lib/ckan/default/src/ckan$
cd /usr/lib/ckan/default/src/ckan || die_on_bad_cd "/usr/lib/ckan/default/src/ckan"
paster serve /etc/ckan/default/development.ini

#check your new ckan installation in the browser...

#leave ckan user's shell
exit

#set up ckan service
sudo touch /var/log/ckan_port_5000.log &&
sudo chown ckan /var/log/ckan_port_5000.log &&
sudo chmod 0666 /var/log/ckan_port_5000.log &&

sudo rm -rf /etc/systemd/system/ckan_port_5000.service &&
sudo touch /etc/systemd/system/ckan_port_5000.service &&
sudo chmod 0655 /etc/systemd/system/ckan_port_5000.service &&
sudo mkdir -p /var/lib/ckan &&

#create storage files
sudo mkdir -p /var/lib/ckan/resources &&
sudo chmod u+rwx /var/lib/ckan/resources  &&

sudo mkdir -p /var/lib/ckan/default  &&
sudo chmod u+rwx /var/lib/ckan/default  &&

sudo chown -R ckan /var/lib/ckan/

#create a script file at /usr/lib/ckan/default/src/ckan/startup.sh to load it in the service. oneliner in ExecStart command was not working because you need to source the virtualenv init script???

printf "
#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
virtualenv --no-site-packages /usr/lib/ckan/default
source /usr/lib/ckan/default/bin/activate
paster serve /etc/ckan/default/development.ini | tee /var/log/ckan_port_5000.log
" | sudo tee /usr/lib/ckan/default/src/ckan/startup.sh

sudo chmod +x /usr/lib/ckan/default/src/ckan/startup.sh

printf "[Unit]
Description=CKAN Instance at Port 5000
[Service]
Type=simple
Restart=on-failure
RestartSec=5s
RuntimeMaxSec=infinity
TimeoutStartSec=infinity
User=ckan
WorkingDirectory=/usr/lib/ckan/default/src/ckan
KillMode=control-group
ExecStart=/bin/bash -c '/usr/lib/ckan/default/src/ckan/startup.sh'
[Install]
WantedBy=multi-user.target\n" | sudo tee /etc/systemd/system/ckan_port_5000.service

sudo systemctl daemon-reload
sudo systemctl reload
sudo systemctl enable ckan_port_5000
sudo systemctl start ckan_port_5000

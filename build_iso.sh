#!/bin/bash

dir=$(pwd)

source $dir/env.sh


## Clone git

echo "clone mirco-mode"
git clone ssh://${GIT_USER}@gerrit.mirantis.com:29418/ericsson-mcp-enablement-program/micro-model model


cd $dir/model
echo "checkout to defined tag"
git checkout origin/${GIT_TAG}
cd $dir/

## Remove everhting else from working DIR

find model \( -path model/classes/cluster/${MCLUSTER} -o -path model/nodes/cfg01.${MDOMAIN}.yml \) -prune -o -type f -print | xargs rm -f

find model \( -path model/classes/cluster/${MCLUSTER} -o -path model/nodes/cfg01.${MDOMAIN}.yml \) -prune -o -type d -print | sort -r | grep -Ev '^(model/classes/cluster|model/classes|model/nodes|model)$' | xargs -I{} rmdir {}


## fetch config drive script 

echo "clone mcp common scripts"
git clone -b ${GIT_TAG} https://github.com/Mirantis/mcp-common-scripts


cp $dir/mcp-common-scripts/config-drive/master_config.sh $dir/user_data.sh


##
cp $dir/mcp-common-scripts/config-drive/create_config_drive.sh $dir/create-config-drive

chmod 0755 $dir/create-config-drive


MASTER_IP=$(cat $dir/model/classes/cluster/multinode-ha/infra/init.yml | python -c 'import yaml,sys; y=yaml.safe_load(sys.stdin); print y["parameters"]["_param"]["infra_config_deploy_address"]')

APTLY_IP=$(cat $dir/model/classes/cluster/multinode-ha/infra/init.yml | python -c 'import yaml,sys; y=yaml.safe_load(sys.stdin); print y["parameters"]["_param"]["aptly_server_deploy_address"]')

PXE_GW=$(cat $dir/model/classes/cluster/multinode-ha/infra/init.yml | python -c 'import yaml,sys; y=yaml.safe_load(sys.stdin); print y["parameters"]["_param"]["deploy_network_gateway"]')

PXE_NETMASK=$(cat $dir/model/classes/cluster/multinode-ha/infra/init.yml | python -c 'import yaml,sys; y=yaml.safe_load(sys.stdin); print y["parameters"]["_param"]["deploy_network_netmask"]')

MCP_VERSION=$(cat $dir/model/classes/cluster/multinode-ha/infra/init.yml | python -c 'import yaml,sys; y=yaml.safe_load(sys.stdin); print y["parameters"]["_param"]["apt_mk_version"]')


echo $MCP_VERSION $MASTER_IP $APTLY_IP $PXE_GW $PXE_NETMASK

echo "repalce salt  kvm pxe network vlaues to user data "

sed -i "s/^export SALT_MASTER_DEPLOY_IP\ *=.*/export SALT_MASTER_DEPLOY_IP=${MASTER_IP}/" $dir/user_data.sh

sed -i "s/^export SALT_MASTER_MINION_ID\ *=.*/export SALT_MASTER_MINION_ID=cfg01.${MDOMAIN}/" $dir/user_data.sh

sed -i "s/^export DEPLOY_NETWORK_GW\ *=.*/export DEPLOY_NETWORK_GW=${PXE_GW}/" $dir/user_data.sh

sed -i "s/^export DEPLOY_NETWORK_NETMASK\ *=.*/export DEPLOY_NETWORK_NETMASK=${PXE_NETMASK}/" $dir/user_data.sh

sed -i "s/^export PIPELINES_FROM_ISO\ *=.*/export PIPELINES_FROM_ISO=false/" $dir/user_data.sh
sed -i "s/^export PIPELINE_REPO_URL\ *=.*/export PIPELINE_REPO_URL=http:\/\/${APTLY_IP}:8088/" $dir/user_data.sh

sed -i "s/^export MCP_VERSION\ *=.*/export MCP_VERSION=${MCP_VERSION}/" $dir/user_data.sh
sed -i "s/^export MCP_SALT_REPO_KEY\ *=.*/export MCP_SALT_REPO_KEY=http:\/\/${APTLY_IP}\/public.gpg/" $dir/user_data.sh

sed -i "s/^export MCP_SALT_REPO_URL\ *=.*/export MCP_SALT_REPO_URL=http:\/\/${APTLY_IP}\/ubuntu-xenial/" $dir/user_data.sh


## Git moduel

cd $dir/model
git init .
git submodule add https://github.com/Mirantis/reclass-system-salt-model classes/system

##Check out specific version
cd $dir/model/classes/system
git checkout ${MCP_VERSION}
cd $dir/model

##Initialize new git source inside of a cloned model
git add *
git commit -m 'Init'
cd $dir


##build config drive
echo "build config drive iso file"

$dir/create-config-drive --user-data $dir/user_data.sh --hostname cfg01 --model $dir/model cfg01.${MDOMAIN}-config.iso

mv $dir/user_data.sh $dir/cfg.user_data.sh

## Build APTLY config drive 


cp $dir/mcp-common-scripts/config-drive/mirror_config.sh $dir/user_data.sh

sed -i "s/^export SALT_MASTER_DEPLOY_IP\ *=.*/export SALT_MASTER_DEPLOY_IP=${MASTER_IP}/" $dir/user_data.sh

sed -i "s/^export APTLY_DEPLOY_IP\ *=.*/export APTLY_DEPLOY_IP=${APTLY_IP}/" $dir/user_data.sh
sed -i "s/^export APTLY_DEPLOY_NETMASK\ *=.*/export APTLY_DEPLOY_NETMASK=${PXE_NETMASK}/" $dir/user_data.sh

sed -i "s/^export APTLY_MINION_ID\ *=.*/export APTLY_MINION_ID=apt01.${MDOMAIN}/" $dir/user_data.sh


$dir/create-config-drive --user-data $dir/user_data.sh --hostname apt apt.${MDOMAIN}-config.iso
mv $dir/user_data.sh $dir/apt.user_data.sh

echo "##### Done ####"

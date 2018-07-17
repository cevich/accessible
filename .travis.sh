#!/bin/bash

set -eo pipefail

env | sort

export CONTAINER="${CONTAINER:-docker}"
cd $(dirname $0)
curl -O https://raw.githubusercontent.com/cevich/ADEPT/master/.travis_typo_check.sh
chmod +x ./.travis_typo_check.sh
[[ -z "$CI" ]] || ./.travis_typo_check.sh

cd tests
curl -O https://raw.githubusercontent.com/cevich/subscribed/master/tests/test_vault.yml
mkdir -p roles
ansible-galaxy install --roles-path=$PWD/roles cevich.subscribed

cd roles
ln -sf ../../ cevich.accessible
cd ..

echo "Configuring vault"
export ANSIBLE_VAULT_PASSWORD_FILE=$(mktemp -p '' .XXXXXXXX)
export OUTPUT_TEMP_FILE=$(mktemp -p '' .XXXXXXXX)
cleanup(){
    set +e
    echo "Cleaning up"
    rm -f ansible.cfg
    rm -f "$ANSIBLE_VAULT_PASSWORD_FILE"
    rm -f "$OUTPUT_TEMP_FILE"
    rm -rf roles/cevich.subscribed
    rm -f ../.travis_typo_check.sh
    rm -f test_vault.yml
    rm -f ssh_private_key
    sudo $CONTAINER exec -i subtest /usr/sbin/subscription-manager unregister
    sudo $CONTAINER exec -i subtest /usr/sbin/subscription-manager clean
    for name in subtest centos fedora ubuntu foobar
    do
        sudo $CONTAINER rm -f $name
    done
}
trap cleanup EXIT

export ANSIBLE_CONFIG="$PWD/ansible.cfg"
cat << EOF > $ANSIBLE_CONFIG
[defaults]
inventory = inventory.yml
gathering = smart
gather_subset = min
vault_password_file = $ANSIBLE_VAULT_PASSWORD_FILE
display_skipped_hosts = False
any_errors_fatal = True
host_key_checking = False
force_color = 1
no_target_syslog = True
squash_actions = apk,apt,dnf,package,pacman,pkgng,yum,zypper
retry_files_enabled = False

[privilege_escalation]
become=False
become_user=root

[ssh_connection]
pipelining=True
control_path = /tmp/ansible-%%n-%%p
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=publickey -o ConnectTimeout=13
EOF

sudo $CONTAINER run --detach --name "foobar" -p 22 lnterface/centos-ssh:latest &
sudo $CONTAINER run --detach --name "subtest" docker.io/cevich/test_rhsm sleep 1h
# Make subtest centos container pretend to be RHEL
if [[ "$CONTAINER" == "podman" ]]
then
    mnt=$(sudo podman mount subtest)
    sudo cp files/os-release $mnt/etc/os-release
    sudo umount $mnt
else
    sudo $CONTAINER cp ./files/os-release subtest:/etc/os-release
fi

# setup the ssh key access
curl -o ssh_private_key https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant
curl -o ssh_private_key.pub https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
chmod 600 ssh_private_key*

wait
if [[ "$CONTAINER" == "podman" ]]
then
    mnt=$(sudo podman mount foobar)
    sudo mkdir "$mnt/root/.ssh"
    sudo cp ssh_private_key.pub "$mnt/root/.ssh/authorized_keys"
    sudo chown -R root.root "$mnt/root/.ssh"
    sudo chmod 700 "$mnt/root/.ssh"
    sudo chmod 600 "$mnt/root/.ssh/authorized_keys"
    sudo umount $mnt
else
    sudo $CONTAINER exec foobar mkdir /root/.ssh
    sudo $CONTAINER cp ssh_private_key.pub foobar:/root/.ssh/authorized_keys
    sudo $CONTAINER exec foobar chown -R root.root "/root/.ssh"
    sudo $CONTAINER exec foobar chmod 700 "/root/.ssh"
    sudo $CONTAINER exec foobar chmod 600 "/root/.ssh/authorized_keys"
fi
export FOOBAR_PORT="$(sudo $CONTAINER port foobar 22 | cut -d : -f 2)"

(
    set +abefhkmnptuvxBCEHPT
    echo "$ANSIBLE_VAULT_PASSWORD" > "$ANSIBLE_VAULT_PASSWORD_FILE"
) &>/dev/null
unset -v ANSIBLE_VAULT_PASSWORD

echo "Testing syntax"
ansible-playbook test.yml -e foobar_port=$FOOBAR_PORT --verbose --syntax-check

# Check wait-for-available functionality, assuming pulling these images
# will take a few moments more that starting the playbook run.
for name in centos fedora ubuntu
do
    sleep 30s && sudo $CONTAINER run --detach --name "$name" docker.io/$name sleep 1h &
done

echo "Testing functionality"
ansible-playbook -e foobar_port=$FOOBAR_PORT test.yml --verbose

echo "Testing idempotence based on functionality test"
ansible-playbook -e foobar_port=$FOOBAR_PORT test.yml | tee "$OUTPUT_TEMP_FILE"
grep -q 'changed=0.*failed=0'  "$OUTPUT_TEMP_FILE" \
    && (echo 'Idempotence test: pass' && exit 0) \
    || (echo 'Idempotence test: fail' && exit 1)

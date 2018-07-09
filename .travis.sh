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
ansible-galaxy install --roles-path roles cevich.subscribed

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
    sudo $CONTAINER exec -i subtest /usr/sbin/subscription-manager unregister
    sudo $CONTAINER exec -i subtest /usr/sbin/subscription-manager clean
    for name in subtest centos fedora ubuntu
    do
        sudo $CONTAINER rm -f $name
    done
}
trap cleanup EXIT

mkdir -p roles
cd roles
ln -s ../../ cevich.accessible
cd ..

export ANSIBLE_CONFIG="$PWD/ansible.cfg"
cat << EOF > ansible.cfg
[defaults]
gather_subset = min
vault_password_file = $ANSIBLE_VAULT_PASSWORD_FILE
display_skipped_hosts = False
any_errors_fatal = True
deprecation_warnings = False
force_color = 1
EOF

sudo $CONTAINER run --detach --name "subtest" docker.io/cevich/test_rhsm sleep 1h
# Make subtest centos container pretend to be RHEL
if [[ "$CONTAINER" == "podman" ]]
then
    mnt=$(podman mount subtest)
    cp files/os-release $mnt/etc/os-release
    podman umount subtest
else
    sudo $CONTAINER cp ./files/os-release subtest:/etc/os-release
fi

(
    set +abefhkmnptuvxBCEHPT
    echo "$ANSIBLE_VAULT_PASSWORD" > "$ANSIBLE_VAULT_PASSWORD_FILE"
) &>/dev/null
unset -v ANSIBLE_VAULT_PASSWORD

echo "Testing syntax"
ansible-playbook -i inventory test.yml --verbose --syntax-check

# Check wait-for-available functionality, assuming pulling these images
# will take a few moments more that starting the playbook run.
for name in centos fedora ubuntu
do
    sudo $CONTAINER rmi docker.io/$name || true
    sudo $CONTAINER run --detach --name "$name" docker.io/$name sleep 1h &> "$OUTPUT_TEMP_FILE" &
done

echo "Testing functionality"
ansible-playbook -i inventory test.yml # --verbose

echo "Testing idempotence based on functionality test"
ansible-playbook -i inventory test.yml | tee "$OUTPUT_TEMP_FILE"
grep -q 'changed=0.*failed=0'  "$OUTPUT_TEMP_FILE" \
    && (echo 'Idempotence test: pass' && exit 0) \
    || (echo 'Idempotence test: fail' && exit 1)

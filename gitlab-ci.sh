#!/bin/bash
# This script relies on the following global variables (set through .gitlab-ci.yml)
# - WEB_DIR, where Magento is installed

# The source file .gitlab-ci.env should define at least the following variables
# - VENDOR, for example Yireo
# - MODULE, for example FooBar
#
# Optionally, the following variables are also supported
# - RUN_PHPCS_EQP2=1
# - RUN_PHPCS_EXTDN=1
# - RUN_YIREO_EXTENSIONCHECKER=1

ENV_FILE=`pwd`/.gitlab-ci.env
source $ENV_FILE
EXTENSION_DIR=`pwd`

# Create a symlink to this repo
cd $WEB_DIR
mkdir -p app/code/${VENDOR}/
cd app/code/${VENDOR}/
ln -s $EXTENSION_DIR ${MODULE}

# Install this extension
cd $WEB_DIR
./bin/magento module:enable ${VENDOR}_${MODULE}
./bin/magento module:status --enabled | grep ${VENDOR}_${MODULE}

# Run PHPUnit tests
vendor/bin/phpunit -c ./app/code/${VENDOR}/${MODULE}/phpunit.yireo-unit.xml

# Run Yireo ExtensionChecker
composer require yireo/magento2-extensionchecker:dev-master
./bin/magento module:enable Yireo_ExtensionChecker
echo "Checking extension with Yireo_ExtensionChecker"
./bin/magento yireo_extensionchecker:scan ${VENDOR}_${MODULE} && exit 1
echo "Done"

# MEQP2 rules
echo "Running MEQP2 codesniffer"
MEQP2_DIR=$WEB_DIR/meqp2
mkdir $MEQP2_DIR
cd $MEQP2_DIR
composer create-project --repository=https://repo.magento.com magento/marketplace-eqp .
vendor/bin/phpcs --config-set m2-path $WEB_DIR
vendor/bin/phpcs $WEB_DIR/app/code/${VENDOR}/${MODULE} --standard=MEQP2 --severity=10 --extensions=php,phtml

# Run PHPUnit Integration Tests
echo "Running PHPUnit Integration Tests"
cd $WEB_DIR
cp /shared/integration-tests/install-config-mysql.php $WEB_DIR/dev/tests/integration/etc
cp /shared/integration-tests/phpunit.xml $WEB_DIR/dev/tests/integration
bin/magento dev:tests:run integration

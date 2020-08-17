echo "exporting Scikit-learn root directory"
export SCIKITLEARN_ROOT=`pwd`
# export PATH='/opt/bin':${PATH}
# echo "Installing requirement"
# /opt/hostedtoolcache/Python/*/x64/bin/python3 -m pip install -U setuptools wheel
set -e
SKIP_BUILD="false"
if [ "$BUILD_REASON" == "Schedule" ]; then
  BUILD_COMMIT=$NIGHTLY_BUILD_COMMIT
  if [ "$NIGHTLY_BUILD" != "true" ]; then
    SKIP_BUILD="true"
  fi
fi
echo "Building scikit-learn@$BUILD_COMMIT"
echo "##vso[task.setvariable variable=BUILD_COMMIT]master"
echo "##vso[task.setvariable variable=SKIP_BUILD]$SKIP_BUILD"
# Platform variables used in multibuild scripts
echo "##vso[task.setvariable variable=TRAVIS_OS_NAME]linux"
# Store original Python path to be able to create test_venv pointing
# to same Python version.
PYTHON_EXE=`which python`
echo "##vso[task.setvariable variable=PYTHON_EXE]$PYTHON_EXE"
echo " Define build env variables "
# /opt/hostedtoolcache/Python/*/x64/bin/python3 -m pip install --upgrade pip
# yum install gcc gcc-c++ python3-devel wget make enchant-devel -y
rm /var/lib/dpkg/lock 
rm /var/lib/apt/lists/lock
apt-get install -y python-virtualenv 
BUILD_DEPENDS="numpy==1.13.3 cython==0.29.14 scipy"
source multibuild/common_utils.sh
source multibuild/travis_steps.sh
source extra_functions.sh
# Setup build dependencies
before_install
# OpenMP is not present on macOS by default
setup_compiler
clean_code scikit-learn master
build_wheel scikit-learn aarch64
teardown_compiler
echo "Build wheel"
condition: eq(variables['SKIP_BUILD'], 'false')
set -xe
source multibuild/common_utils.sh
source multibuild/travis_steps.sh
source extra_functions.sh
setup_test_venv
install_run aarch64
teardown_test_venv
echo "Install wheel and test"
condition: eq(variables['SKIP_BUILD'], 'false')
  - task: PublishTestResults@2
    inputs:
      testResultsFiles: '$(TEST_DIR)/$(JUNITXML)'
      testRunTitle: ${{ format('{0}-$(Agent.JobName)', parameters.name) }}
    displayName: 'Publish Test Results'
    condition: eq(variables['SKIP_BUILD'], 'false')

   - bash: |
     set -e
     if [ "$BUILD_REASON" == "Schedule" ]; then
       ANACONDA_ORG="scipy-wheels-nightly"
       TOKEN="$SCIKIT_LEARN_NIGHTLY_UPLOAD_TOKEN"
     else
       ANACONDA_ORG="scikit-learn-wheels-staging"
       TOKEN="$SCIKIT_LEARN_STAGING_UPLOAD_TOKEN"
     fi
     echo "##vso[task.setvariable variable=TOKEN]$TOKEN"
     echo "##vso[task.setvariable variable=ANACONDA_ORG]$ANACONDA_ORG"
     displayName: Retrieve secret upload token
     condition: and(succeeded(), eq(variables['SKIP_BUILD'], 'false'), ne(variables['Build.Reason'], 'PullRequest'), variables['SCIKIT_LEARN_NIGHTLY_UPLOAD_TOKEN'], variables['SCIKIT_LEARN_STAGING_UPLOAD_TOKEN'])
     env:
       # Secret variables need to mapped to env variables explicitly:
       SCIKIT_LEARN_NIGHTLY_UPLOAD_TOKEN: $(SCIKIT_LEARN_NIGHTLY_UPLOAD_TOKEN)
       SCIKIT_LEARN_STAGING_UPLOAD_TOKEN: $(SCIKIT_LEARN_STAGING_UPLOAD_TOKEN)
   - bash: |
       echo "##vso[task.prependpath]$CONDA/bin"
       sudo chown -R $USER $CONDA
     displayName: Add conda to PATH
     condition: and(succeeded(), eq(variables['SKIP_BUILD'], 'false'), ne(variables['Build.Reason'], 'PullRequest'), variables['TOKEN'])
   - bash: conda install -q -y anaconda-client
     displayName: Install anaconda-client
     condition: and(succeeded(), eq(variables['SKIP_BUILD'], 'false'), ne(variables['Build.Reason'], 'PullRequest'), variables['TOKEN'])

   - bash: |
       set -e
       # The --force option forces a replacement if the remote file already
       # exists.
       ls wheelhouse/*.whl
       anaconda -t $TOKEN upload --force -u $ANACONDA_ORG wheelhouse/*.whl
       echo "PyPI-style index: https://pypi.anaconda.org/$ANACONDA_ORG/simple"
     displayName: Upload to anaconda.org (only if secret token is retrieved)
     condition: variables['TOKEN']

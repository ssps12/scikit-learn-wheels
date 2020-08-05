parameters:
  name: ""
  vmImage: ""
  matrix: []

jobs:
  - job: ${{ parameters.name }}
    pool:
      vmImage: ${{ parameters.vmImage }}
    variables:
      REPO_DIR: "scikit-learn"
      PLAT: "arm64"
      NP_BUILD_DEP: "numpy==1.13.3"
      CYTHON_BUILD_DEP: "cython==0.29.14"
      SCIPY_BUILD_DEP: "scipy"
      JOBLIB_BUILD_DEP: "joblib==0.11"
      NIGHTLY_BUILD_COMMIT: "master"
      NIGHTLY_BUILD: "false"
      TEST_DEPENDS: "pytest"
      JUNITXML: "test-data.xml"
      TEST_DIR: "tmp_for_test"
    strategy:
      matrix:
        ${{ insert }}: ${{ parameters.matrix }}

    steps:
      - checkout: self
        submodules: true

      - task: UsePythonVersion@0
        inputs:
          versionSpec: $(MB_PYTHON_VERSION)
        displayName: Set python version

      - bash: |
          set -e
          SKIP_BUILD="false"
          if [ "$BUILD_REASON" == "Schedule" ]; then
            BUILD_COMMIT=$NIGHTLY_BUILD_COMMIT
            if [ "$NIGHTLY_BUILD" != "true" ]; then
              SKIP_BUILD="true"
            fi
          fi
          echo "Building scikit-learn@$BUILD_COMMIT"
          echo "##vso[task.setvariable variable=BUILD_COMMIT]$BUILD_COMMIT"
          echo "##vso[task.setvariable variable=SKIP_BUILD]$SKIP_BUILD"
          # Platform variables used in multibuild scripts
          echo "##vso[task.setvariable variable=TRAVIS_OS_NAME]linux"
          # Store original Python path to be able to create test_venv pointing
          # to same Python version.
          PYTHON_EXE=`which python`
          echo "##vso[task.setvariable variable=PYTHON_EXE]$PYTHON_EXE"
        displayName: Define build env variables
      - bash: |
          set -e
          pip install virtualenv
          BUILD_DEPENDS="$NP_BUILD_DEP $CYTHON_BUILD_DEP $SCIPY_BUILD_DEP"
          source multibuild/common_utils.sh
          source multibuild/travis_steps.sh
          source extra_functions.sh
          # Setup build dependencies
          before_install
          # OpenMP is not present on macOS by default
          setup_compiler
          clean_code $REPO_DIR $BUILD_COMMIT
          build_wheel $REPO_DIR $PLAT
          teardown_compiler
        displayName: Build wheel
        condition: eq(variables['SKIP_BUILD'], 'false')
      - bash: |
          set -xe
          source multibuild/common_utils.sh
          source multibuild/travis_steps.sh
          source extra_functions.sh
          setup_test_venv
          install_run $PLAT
          teardown_test_venv
        displayName: Install wheel and test
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

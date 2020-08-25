#set -v -e

# Install Miniconda
#wget -q "https://github.com/conda-forge/miniforge/releases/download/4.8.2-1/Miniforge3-4.8.2-1-Linux-aarch64.sh"  -O miniconda.sh
#chmod +x miniconda.sh
#./miniconda.sh -b -p $HOME/miniconda3
#export PATH=$HOME/miniconda3/bin:$PATH
#conda --version
#hash -r
#conda config --set always_yes yes --set changeps1 no
#conda update -q conda

#!/bin/bash

set -v -e

if [ `uname -m` = 'aarch64' ]; then
    rm -rf $HOME/.condarc
fi

# first configure conda to have more tolerance of network problems, these
# numbers are not scientifically chosen, just merely larger than defaults
conda config --write-default
conda config --set remote_connect_timeout_secs 30.15
conda config --set remote_max_retries 10
conda config --set remote_read_timeout_secs 120.2
if [[ $(uname) == Linux ]]; then
    if [[ "$CONDA_SUBDIR" != "linux-32" && "$BITS32" != "yes" ]] ; then
        conda config --set restore_free_channel true
    fi
fi
conda info
conda config --show

CONDA_INSTALL="conda install -q -y"
PIP_INSTALL="pip install -q"


EXTRA_CHANNELS=""
if [ "${USE_C3I_TEST_CHANNEL}" == "yes" ]; then
    EXTRA_CHANNELS="${EXTRA_CHANNELS} -c c3i_test"
fi


# Deactivate any environment
# Display root environment (for debugging)
conda list

$CONDA_INSTALL numpy scipy cython

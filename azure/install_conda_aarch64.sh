set -v -e

# Install Miniconda
wget -q "https://github.com/conda-forge/miniforge/releases/download/4.8.2-1/Miniforge3-4.8.2-1-Linux-aarch64.sh"  -O miniconda.sh
chmod +x miniconda.sh
./miniconda.sh -b -p $HOME/miniconda3
export PATH=$HOME/miniconda3/bin:$PATH
conda --version
hash -r
conda config --set always_yes yes --set changeps1 no
conda update -q conda

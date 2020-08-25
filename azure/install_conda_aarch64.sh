set -v -e

# Install Miniconda
wget -q "https://github.com/conda-forge/miniforge/releases/download/4.8.2-1/Miniforge3-4.8.2-1-Linux-aarch64.sh" -O archiconda.sh
chmod +x archiconda.sh
sudo find / -type f -name ld-linux-aarch64.so.1
./archiconda.sh -b -p /opt/conda
export PATH="/opt/conda/bin:$PATH"
conda --version
hash -r
conda config --set always_yes yes --set changeps1 no
conda update -q conda

set -xeo pipefail

ROOT=$(cd "$(dirname "$0")/.."; pwd;)

docker info

# In order for the conda-build process in the container to write to the mounted
# volumes, we need to run with the same id as the host machine, which is
# normally the owner of the mounted volumes, or at least has write permission
export HOST_USER_ID=$(id -u)
# Check if docker-machine is being used (normally on OSX) and get the uid from
# the VM
if hash docker-machine 2> /dev/null && docker-machine active > /dev/null; then
    export HOST_USER_ID=$(docker-machine ssh $(docker-machine active) id -u)
fi

ARTIFACTS="$ROOT/build_artifacts"
mkdir -p "$ARTIFACTS"
CI='azure'
if [ -z "${CI}" ]; then
    DOCKER_RUN_ARGS="-it "
fi

export UPLOAD_PACKAGES="${UPLOAD_PACKAGES:-True}"
docker run ${DOCKER_RUN_ARGS} \
           -v "${ROOT}":/home/conda/root:rw,z \
           -e TEST_START_INDEX \
           -e TEST_COUNT \
           -e HOST_USER_ID \
           -e CI \
           $DOCKER_IMAGE \
           bash /home/conda/root/azure/build_steps.sh

# verify that the end of the script was reached
test -f "$DONE_CANARY"

# docker build -t usd_ubuntu_build --network=host --progress=plain .
# docker run -it --network=host usd_ubuntu_build
# docker run -it --network=host --gpus=all usd_ubuntu_build

# Copy contents out when done:
# rm -rf /tmp/usd_build && id=$(docker create usd_ubuntu_build) && docker cp $id:/tmp/usd_build /tmp/usd_build && docker rm -v $id

# To test:
# cd /tmp/usd_build/USD
# export USD_BUILD_ROOT=/tmp/usd_build
# export PATH="${USD_BUILD_ROOT}/USD/_install/bin:${PATH}"
# export PYTHONPATH="${USD_BUILD_ROOT}/USD/_install/lib/python${PYTHONPATH:+:${PYTHONPATH}}"
# cd "${USD_BUILD_ROOT}/USD/_install/build/USD"
# /tmp/usd_build/miniconda3/bin/conda run --no-capture-output -n usd37 ctest --output-on-failure -R '^testUsdImagingGLInstancing_nestedInstance$'

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    'cmake=3.22.*' \
    'curl' \
    'g++=4:11.*' \
    'git=1:2.34.*' \
    'libglew-dev=2.2.*' \
    'libglib2.0' \
    'zlib1g-dev=1:1.2.*' \
 && rm -rf /var/lib/apt/lists/*

ENV USD_BUILD_ROOT=/tmp/usd_build

RUN curl https://repo.anaconda.com/miniconda/Miniconda3-py37_22.11.1-1-Linux-x86_64.sh > install_miniconda.sh \
 && bash install_miniconda.sh -b -p ${USD_BUILD_ROOT}/miniconda3 \
 && rm install_miniconda.sh

RUN "${USD_BUILD_ROOT}/miniconda3/bin/conda" create -y -n usd37 -c conda-forge \
    libstdcxx-ng=12 \
    python=3.7 \
 && "${USD_BUILD_ROOT}/miniconda3/bin/conda" clean -y --all --force-pkgs-dirs

SHELL ["/tmp/usd_build/miniconda3/bin/conda", "run", "--no-capture-output", "-n", "usd37", "/bin/bash", "-c"]

RUN pip install --no-input --no-cache-dir \
    'jinja2==3.1.*' \
    'PyOpenGL==3.1.*' \
    'PySide2==5.15.*'

RUN git clone https://github.com/PixarAnimationStudios/USD.git "${USD_BUILD_ROOT}/USD" \
  && cd "${USD_BUILD_ROOT}/USD" \
  && git checkout -B docker_build 48b3d1452bed1c2cb4d3fe94360bd6d85c133dc5

WORKDIR "${USD_BUILD_ROOT}/USD"

ARG CXXFLAGS=-DPTHREAD_STACK_MIN=16384

RUN python build_scripts/build_usd.py \
    -vvv --tests \
    $PWD/_install \
    --build-args boost,define=PTHREAD_STACK_MIN=16384

ENV \
 PATH="${USD_BUILD_ROOT}/USD/_install/bin:${PATH}" \
 PYTHONPATH="${USD_BUILD_ROOT}/USD/_install/lib/python:${PYTHONPATH}"

ENTRYPOINT ["/tmp/usd_build/miniconda3/bin/conda", "run", "--no-capture-output", "-n", "usd37", "/bin/bash"]

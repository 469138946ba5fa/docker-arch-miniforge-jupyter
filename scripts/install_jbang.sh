#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Setting up JBang and configuring Jupyter Java Kernel..."

# Miniforge 安装路径
# export MINIFORGE_DIR=/opt/Miniforge

# miniforge 软件源
# export CONDA_CHANNELS="${CONDA_CHANNELS:-defaults}"

# 初始化 Miniforge 环境
# export PATH=${MINIFORGE_DIR}/bin:${PATH}
# 某些 linux 系统可能需要导入 Miniforge 的 lib 环境
# 如果你需要这个，就执行，之后可能还需要手动写入到 bash 或 zsh 的配置文件中，以持续生效
# 但是我不确定是不是所有的 linux 都会 lib 缺失，先注释吧
#export LD_LIBRARY_PATH=${MINIFORGE_DIR}/lib:${LD_LIBRARY_PATH}

# 指定 python 版本
#export PY_VERSION=3.12.10
#export CONDA_PY_ENV=py${PY_VERSION}

# jbang 环境
# export PATH="${HOME}/.jbang/bin:${PATH}"

# 明确激活cling，确保非交互式环境变量生效，规避 ADDR2LINE: unbound variable
set +u
# 激活cling
source activate ${CONDA_PY_ENV}
set -u

curl -Ls https://sh.jbang.dev | bash -s - app setup
jbang trust add https://github.com/jupyter-java/jbang-catalog/
jbang trust add https://github.com/jupyter-java/
jbang install-kernel@jupyter-java
rm -rf "${HOME}/.jbang/currentjdk" "${HOME}/.jbang/cache/jdks"
log_info "JBang setup completed."
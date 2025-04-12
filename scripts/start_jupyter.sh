#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# 初始化 Miniforge 环境
log_info "Initializing conda..."

# Miniforge 安装路径
# export MINIFORGE_DIR=/opt/Miniforge

# 初始化 Miniforge 环境
# export PATH=${MINIFORGE_DIR}/bin:${PATH}
# 某些 linux 系统可能需要导入 Miniforge 的 lib 环境
# 如果你需要这个，就执行，之后可能还需要手动写入到 bash 或 zsh 的配置文件中，以持续生效
# 但是我不确定是不是所有的 linux 都会 lib 缺失，先注释吧
#export LD_LIBRARY_PATH=${MINIFORGE_DIR}/lib:${LD_LIBRARY_PATH}

# 配置 locale
# export LANGUAGE=zh_CN.UTF-8
# export LC_ALL=zh_CN.UTF-8
# export LANG=zh_CN.UTF-8
# export LC_CTYPE=zh_CN.UTF-8

# jbang 环境
# export PATH="${HOME}/.jbang/bin:${PATH}"
# java 环境
# export JAVA_HOME=${HOME}/.jbang/currentjdk
# export CLASSPATH=.:${JAVA_HOME}/lib
# export PATH=${PATH}:${JAVA_HOME}/bin

# 明确激活cling，确保非交互式环境变量生效，规避 ADDR2LINE: unbound variable
set +u
# 激活cling
log_info "Activate cling env..."
source activate cling
set -u

# 将日志输出重定向到日志文件
LOG_FILE="/notebook/jupyter_startup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "Starting JupyterLab service..."

if [ ! -d "/notebook" ]; then
  log_error "/notebook directory does not exist. Please check volume mounts."
  exit 1
fi

for cmd in mamba jupyter-lab; do
  if ! command_exists "${cmd}"; then
    log_error "${cmd} is not installed. Aborting."
    exit 1
  fi
done

# --------- 开始统一修改 jupyter_server_config.py ---------

# 确保配置文件目录存在
mkdir -p "${HOME}/.jupyter"

# 如配置文件不存在则生成 jupyter_server_config.py
if [ ! -f "${HOME}/.jupyter/jupyter_server_config.py" ]; then
    log_info "Generating Jupyter server configuration..."
    jupyter-server --generate-config -y
fi

# 设置密码：如果PASSWORD变量未设置，则采用默认值
if [[ -z "${PASSWORD:-}" ]]; then
    log_warning "PASSWORD variable not set, using default value: 123456"
    export PASSWORD=123456
fi

# 生成密码哈希（新版Jupyter使用 Notebook.auth 模块产生密码哈希）
PASSWORD_HASH=$(python -c "from notebook.auth import passwd; print(passwd('${PASSWORD}'))")

log_info "Appending custom configuration for default shell and password to Jupyter server config..."

# 将 Terminal 默认 shell 和密码写入 jupyter_server_config.py
cat <<EOF >> "${HOME}/.jupyter/jupyter_server_config.py"

# ------------------------------
# Custom configuration appended automatically via startup script
c.ServerApp.terminado_settings = {'shell_command': ['/bin/bash']}
c.ServerApp.password = "${PASSWORD_HASH}"
# ------------------------------
EOF

log_info "Jupyter server configuration updated at ${HOME}/.jupyter/jupyter_server_config.py"

# 设置默认主题为 JupyterLab Dark
mkdir -p "${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/"
cat <<'EOF' > "${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings"
{
    "theme": "JupyterLab Dark"
}
EOF
log_info "Default JupyterLab theme set to 'JupyterLab Dark'."

# --------- 启动 JupyterLab ---------
log_info "Launching JupyterLab on port 8888..."
jupyter-lab --allow-root --no-browser --notebook-dir=/notebook --ip=0.0.0.0 --port=8888

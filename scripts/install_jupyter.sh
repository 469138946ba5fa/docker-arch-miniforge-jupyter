#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting Jupyter environment setup..."

# Miniforge 安装路径
# export MAMBA_ROOT_PREFIX=/opt/Miniforge

# miniforge 软件源
# export CONDA_CHANNELS="${CONDA_CHANNELS:-defaults}"
# export PIP_CHANNELS='https://pypi.org/simple'

# 初始化 Miniforge 环境
# export PATH=${MAMBA_ROOT_PREFIX}/bin:${PATH}
# 某些 linux 系统可能需要导入 Miniforge 的 lib 环境
# 如果你需要这个，就执行，之后可能还需要手动写入到 bash 或 zsh 的配置文件中，以持续生效
# 但是我不确定是不是所有的 linux 都会 lib 缺失，先注释吧
#export LD_LIBRARY_PATH=${MAMBA_ROOT_PREFIX}/lib:${LD_LIBRARY_PATH}
# 指定 python 版本
#export PY_VERSION=3.12.10
#export CONDA_PY_ENV=py${PY_VERSION}
export JUPYTER_KERNEL_USER="--user"

# conda 包安装带重试逻辑
retry_conda_install_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Installing conda packages in bulk (attempt ${i}/${retries})"
    if mamba install "${pkgs[@]}" -c "${CONDA_CHANNELS}" -y; then
      log_info "All conda packages installed successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to install conda packages, retrying after ${sleep_seconds}s..."
      sleep ${sleep_seconds}
    fi
  done
  log_error "Failed to install conda packages after ${retries} attempts."
  exit 1
}

# pip 包安装带重试逻辑
retry_pip_install_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Installing pip packages in bulk (attempt ${i}/${retries})"
    if python -m pip install --no-cache-dir -v "${pkgs[@]}" --break-system-packages -i ${PIP_CHANNELS}; then
      log_info "All pip packages installed successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to install pip packages, retrying after ${sleep_seconds}s..."
      sleep ${sleep_seconds}
    fi
  done
  log_error "Failed to install pip packages after ${retries} attempts."
  exit 1
}

# pip 包重安装带重试逻辑
retry_pip_force_reinstall_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Reinstalling pip packages in bulk (attempt ${i}/${retries})"
    if python -m pip install --force-reinstall -v "${pkgs[@]}" --break-system-packages -i ${PIP_CHANNELS}; then
      log_info "All pip packages reinstalling successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to reinstalling pip packages, retrying after ${sleep_seconds}s..."
      sleep ${sleep_seconds}
    fi
  done
  log_error "Failed to reinstalling pip packages after ${retries} attempts."
  exit 1
}

# 所需软件包列表
conda_packages=(
  # cling 类别：为 Jupyter 提供 C++ 交互式内核及其依赖
  xeus-cling                      # 基于 xeus 的 C++ 内核，可在 Jupyter 中运行 C++ 代码
  # 压缩类别
  zlib                            # 压缩库，各种软件包可能依赖它
  # jupyter 类别
  nb_conda_kernels                # 允许自动检测和使用 conda 环境中的内核
)

pip_packages=(
  # jupyter 类别：构建完整的 Jupyter 环境及扩展
  jupyterlab                      # 下一代 Jupyter 用户界面，支持交互式笔记本和代码
  notebook                        # 经典 Jupyter Notebook 应用
  voila                           # 可将 Jupyter 笔记本转换为独立的 Web 应用
  ipywidgets                      # 为笔记本提供交互式控件（HTML widgets）
  qtconsole                       # 基于 Qt 的 Jupyter 控制台，提供终端式界面
  jupyter_contrib_nbextensions    # 社区贡献的 Notebook 扩展集合，可增强功能
  jupyterlab-git                  # 在 JupyterLab 中集成 Git 版本控制功能
  jupyterlab-dash                 # 允许在 JupyterLab 中嵌入和交互使用 Dash 应用
  # data 类别：用于数值计算、数据处理和可视化
  numpy                           # 数组计算基础库，为后续科学计算提供支持
  scipy                           # 科学计算库，包含大量算法和数学工具
  pandas                          # 数据分析和数据结构处理工具
  matplotlib                      # 绘图和数据可视化库
  # machine 类别：机器学习
  seaborn                         # 基于 matplotlib 的统计数据可视化库
  scikit-learn                    # 机器学习库，提供分类、回归、聚类等算法
  # network 类别：与网络请求、爬虫及数据库交互相关
  beautifulsoup4                  # HTML/XML 解析库，用于网页数据爬取和处理
  requests                        # 简单优雅的 HTTP 请求库
  SQLAlchemy                      # SQL 工具包及 ORM，用于数据库交互
  retrying                        # 帮助实现函数重试机制的库，适用于网络请求等场景
  httpx                           # 现代化的 HTTP 客户端，支持同步与异步请求
  tensorflow                      # 由 Google 开发的一个可商业化的开源深度学习框架
)

# 备用功能，所需强制重装安装包
pip_force_packages=(
  setuptools                      # 生成 console_scripts entrypoints
  wheel                           # 确保正确的 wheel 安装机制
)

# Miniforge 创建最新的 py 环境
PY_VERSIONS=$(mamba repoquery search python -c ${CONDA_CHANNELS})

# 拼接下载链接和校验码链接
log_info "Detected beta release version..."
if [[ "${PY_VERSIONS}" == *"${PY_VERSION}"* ]]; then
  echo ${PY_VERSION}
else
  PY_VERSION=$(echo "${PY_VERSIONS}" | grep "python" | awk '{print $2}' | sort -V | tail -n 1)
  echo ${PY_VERSION}
fi
log_info "latest python version "${PY_VERSION}

# 创建 Conda 环境
# mamba 安装 python ${PY_VERSION} 版本并将环境命名为 ${CONDA_PY_ENV}
log_info "Creating Conda environment ${PY_VERSION} with Python ${PY_VERSION}..."
mamba create -n ${CONDA_PY_ENV} python=${PY_VERSION} -c "${CONDA_CHANNELS}" -y

# 激活${CONDA_PY_ENV}
log_info "Activate ${CONDA_PY_ENV} env..."
# 明确激活 ${CONDA_PY_ENV}，确保非交互式环境变量生效，规避 ADDR2LINE: unbound variable
# 取消 set -u（如果你之前开启了严格模式）
set +u
# source conda 环境
. /opt/Miniforge/etc/profile.d/conda.sh
conda activate "${CONDA_PY_ENV}"
set -u

# 基于 xeus 的 C++ 内核，可在 Jupyter 中运行 C++ 代码
mamba install xeus-cling -c "${CONDA_CHANNELS}" -y

# 一次性安装全部包
log_info "Installing conda packages individually with retries..."
retry_conda_install_bulk "${conda_packages[@]}"

# 循环安装各软件包
#log_info "Installing conda packages individually with retries..."
#for pkg in "${conda_packages[@]}"; do
#  retry_conda_install_bulk "${pkg}"
#done

# 更新 pip 工具包
python -m pip install --no-cache-dir -v --upgrade pip --break-system-packages -i ${PIP_CHANNELS}

# 一次性安装全部包
log_info "Installing pip packages individually with retries..."
retry_pip_install_bulk "${pip_packages[@]}"

#log_info "Installing pip packages individually with retries..."
#for pkg in "${pip_packages[@]}"; do
#  retry_pip_install_bulk "${pkg}"
#done

# 备用功能，补丁修复: 强制重新安装 setuptools, wheel，确保 jupyter 命令正确生成
log_info "Reinstalling setuptools and wheel to fix entrypoints..."
retry_pip_force_reinstall_bulk "${pip_force_packages[@]}"

#log_info "Reinstalling setuptools and wheel to fix entrypoints..."
#for pkg in "${pip_force_packages[@]}"; do
#  retry_pip_force_reinstall_bulk "${pkg}"
#done

# 根据架构注册内核，直到官方更新，也许他们会更新吧，唉😮‍💨
log_info "Register xeus-cling jupyter kernel..."

ARCH=$(uname -m)
if [[ "${ARCH}" == "aarch64" ]]; then
  log_warning "${ARCH} 架构检测到，跳过注册 C++ 14/17/20/23 内核，避免 cling ABI 错误"
  pushd "${CONDA_PREFIX}/share/jupyter/kernels" > /dev/null
  # 尝试从 jupyter kernelspec 中移除这些内核（静默）
  for k in xcpp14 xcpp17 xcpp20 xcpp23; do
    jupyter-kernelspec remove -f "${k}" --user > /dev/null 2>&1 || true
    # 删除文件夹（即使不存在也不报错）
    rm -frv "${k}"
  done
  popd > /dev/null
else
  log_info "${ARCH} 架构检测到，注册 C++ 14/17/20/23 内核"
  pushd "${CONDA_PREFIX}/share/jupyter/kernels" > /dev/null
  cp -a xcpp17 xcpp20
  sed -i 's/17/20/g' xcpp20/kernel.json
  cp -a xcpp20 xcpp23
  sed -i 's/20/23/g' xcpp23/kernel.json
  xcpps=(xcpp20 xcpp23)
  for k in "${xcpps[@]}"; do
    log_info "注册 Jupyter 内核：${k}"
    jupyter-kernelspec install "${k}" ${JUPYTER_KERNEL_USER}
  done
  popd > /dev/null
fi

# 将激活环境写入配置文件中，保留长期有效
# 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
cat << 469138946ba5fa | tee -a /etc/environment "${HOME}/.profile"
conda activate ${CONDA_PY_ENV}
469138946ba5fa

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -q "conda activate ${CONDA_PY_ENV}" "${HOME}/.bashrc"; then
      log_info "Initializing ${CONDA_PY_ENV} for bash..."
      # 固化 ${CONDA_PY_ENV} 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "conda activate ${CONDA_PY_ENV}" | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
    fi
    ;;
  zsh)
    if ! grep -q "conda activate ${CONDA_PY_ENV}" "${HOME}/.zshrc"; then
      log_info "Initializing ${CONDA_PY_ENV} for zsh..."
      # 固化 ${CONDA_PY_ENV} 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "conda activate ${CONDA_PY_ENV}" | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "Jupyter setup is complete."
jupyter-kernelspec list
jupyter --version
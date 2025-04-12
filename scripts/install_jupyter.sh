#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting Jupyter environment setup..."

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
# 指定 cling 的 python 版本
# export PY_VERSION=3.12.10

# 所需软件包列表
packages=(
  # cling 类别：为 Jupyter 提供 C++ 交互式内核及其依赖
  xeus-cling                     # 基于 xeus 的 C++ 内核，可在 Jupyter 中运行 C++ 代码
  zlib                           # 压缩库，各种软件包可能依赖它
  # jupyter 类别：构建完整的 Jupyter 环境及扩展
  jupyterlab                     # 下一代 Jupyter 用户界面，支持交互式笔记本和代码
  notebook                       # 经典 Jupyter Notebook 应用
  voila                          # 可将 Jupyter 笔记本转换为独立的 Web 应用
  ipywidgets                     # 为笔记本提供交互式控件（HTML widgets）
  qtconsole                      # 基于 Qt 的 Jupyter 控制台，提供终端式界面
  jupyter_contrib_nbextensions   # 社区贡献的 Notebook 扩展集合，可增强功能
  nb_conda_kernels               # 允许自动检测和使用 conda 环境中的内核
  jupyterlab-git                 # 在 JupyterLab 中集成 Git 版本控制功能
  jupyterlab-dash                # 允许在 JupyterLab 中嵌入和交互使用 Dash 应用
  # data 类别：用于数值计算、数据处理和可视化
  numpy                          # 数组计算基础库，为后续科学计算提供支持
  scipy                          # 科学计算库，包含大量算法和数学工具
  pandas                         # 数据分析和数据结构处理工具
  matplotlib                     # 绘图和数据可视化库
  # machine 类别：机器学习
  seaborn                        # 基于 matplotlib 的统计数据可视化库
  scikit-learn                   # 机器学习库，提供分类、回归、聚类等算法
  # network 类别：与网络请求、爬虫及数据库交互相关
  beautifulsoup4                 # HTML/XML 解析库，用于网页数据爬取和处理
  requests                       # 简单优雅的 HTTP 请求库
  SQLAlchemy                     # SQL 工具包及 ORM，用于数据库交互
  retrying                       # 帮助实现函数重试机制的库，适用于网络请求等场景
  httpx                          # 现代化的 HTTP 客户端，支持同步与异步请求
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

# mamba 安装 python ${PY_VERSION} 版本并将环境命名为 cling
mamba create -n cling python=${PY_VERSION} -c ${CONDA_CHANNELS} -y

# 明确激活cling，确保非交互式环境变量生效，规避 ADDR2LINE: unbound variable
set +u
# 激活cling
source activate cling
set -u


# 将激活环境及 locale 配置写入配置文件中，保留长期有效
cat << 469138946ba5fa | tee -a /etc/default/locale /etc/environment "${HOME}/.profile"
conda activate cling
469138946ba5fa

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -q "cling initialize" "${HOME}/.bashrc"; then
      log_info "Initializing cling for bash..."
      # 固化 cling 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "conda activate cling" | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
    fi
    ;;
  zsh)
    if ! grep -q "cling initialize" "${HOME}/.zshrc"; then
      log_info "Initializing cling for zsh..."
      # 固化 cling 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "conda activate cling" | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

# 循环安装各软件包
for pkg in "${packages[@]}"; do
  log_info "Installing package: ${pkg}"
  mamba install "${pkg}" -c "${CONDA_CHANNELS}" -y || { log_error "Failed to install ${pkg}"; exit 1; }
done

# 根据 Python 版本安装 pip 和 tensorflow
python -m pip install --no-cache-dir -v --upgrade pip --break-system-packages
python -m pip install --no-cache-dir -v tensorflow --break-system-packages

log_info "Jupyter setup is complete."
jupyter --version
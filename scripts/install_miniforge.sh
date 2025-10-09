#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting Miniforge environment setup..."

# Miniforge 安装路径
# export MAMBA_ROOT_PREFIX=/opt/Miniforge

# miniforge 软件源
# export CONDA_CHANNELS="${CONDA_CHANNELS:-defaults}"

# 初始化 Miniforge 环境
# export PATH=${MAMBA_ROOT_PREFIX}/bin:${PATH}
# 某些 linux 系统可能需要导入 Miniforge 的 lib 环境
# 如果你需要这个，就执行，之后可能还需要手动写入到 bash 或 zsh 的配置文件中，以持续生效
# 但是我不确定是不是所有的 linux 都会 lib 缺失，先注释吧
#export LD_LIBRARY_PATH=${MAMBA_ROOT_PREFIX}/lib:${LD_LIBRARY_PATH}

# GitHub 项目 URI
URI="conda-forge/miniforge"

# 获取最新版本
VERSION=$(curl -sL "https://github.com/${URI}/releases" | grep -Eo '/releases/tag/[^"]+' | awk -F'/tag/' '{print $2}' | head -n 1)
log_info "Latest version: ${VERSION}"

# 获取操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 映射平台到官方命名
case "${OS}" in
  Linux)
    PLATFORM="Linux"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="aarch64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="x86_64"
    else
      log_error "Unsupported architecture: ${ARCH}"
      exit 1
    fi
    ;;
  Darwin)
    PLATFORM="MacOSX"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="arm64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="x86_64"
    else
      log_info "Unsupported architecture: ${ARCH}"
    fi
    ;;
  *)
    log_error "Unsupported OS: ${OS}"
    exit 1
    ;;
esac

# 输出最终平台和架构
log_info "Platform: ${PLATFORM}"
log_info "Architecture: ${ARCH}"

# 拼接下载链接和校验码链接
TARGET_FILE="Miniforge3-${VERSION}-${PLATFORM}-${ARCH}.sh"
SHA256_FILE="${TARGET_FILE}.sha256"
URI_DOWNLOAD="https://github.com/${URI}/releases/download/${VERSION}/${TARGET_FILE}"
URI_SHA256="https://github.com/${URI}/releases/download/${VERSION}/${SHA256_FILE}"
log_info "Download URL: ${URI_DOWNLOAD}"
log_info "SHA256 URL: ${URI_SHA256}"

# 检查文件是否存在
if [[ -f "/tmp/${TARGET_FILE}" ]]; then
  log_info "File already exists: /tmp/${TARGET_FILE}"
  
  # 删除旧的 SHA256 文件（如果存在）
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    log_info "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi

  # 下载新的 SHA256 文件
  log_info "Downloading SHA256 file..."
  # 临时取消 set -e（如果你之前开启了严格模式）防止炸脚本
  set +e
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"
  set -e

  # 校验文件完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  log_info "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    log_warning "SHA256 checksum failed. Removing file and retrying..."
    rm -fv "/tmp/${TARGET_FILE}"
  else
    log_info "File integrity verified successfully."
  fi
fi

# 如果文件不存在或之前校验失败
if [[ ! -f "/tmp/${TARGET_FILE}" ]]; then
  log_info "Downloading file..."
  # 临时取消 set -e（如果你之前开启了严格模式）防止炸脚本
  set +e
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${TARGET_FILE}" "${URI_DOWNLOAD}"
  set -e

  # 删除旧的 SHA256 文件并重新下载
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    log_info "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi
  log_info "Downloading SHA256 file..."
  # 临时取消 set -e（如果你之前开启了严格模式）防止炸脚本
  set +e
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"
  set -e

  # 校验完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  log_info "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    log_error "Download failed: SHA256 checksum does not match."
    exit 1
  else
    log_info "File integrity verified successfully."
  fi
fi

# 创建安装目录
log_info "Installing Miniforge..."
mkdir -pv ${MAMBA_ROOT_PREFIX}
chmod -Rv a+x ${MAMBA_ROOT_PREFIX}
OS=$(uname -s)

# 设置安装目录权限
if [[ "${OS}" == "Darwin" ]]; then
  # macOS 使用 "admin" 作为用户组
  chown -Rv $(whoami):admin ${MAMBA_ROOT_PREFIX}
elif [[ "${OS}" == "Linux" ]]; then
  # Linux 通常用户组为用户名
  chown -Rv $(whoami):$(whoami) ${MAMBA_ROOT_PREFIX}
else
  log_error "Unsupported OS: ${OS}"
  exit 1
fi

# 安装 Miniforge
bash "/tmp/${TARGET_FILE}" -b -f -p ${MAMBA_ROOT_PREFIX}

# 更新 Mamba 和 Conda
mamba update -n base -c ${CONDA_CHANNELS} mamba -y
mamba update -n base -c ${CONDA_CHANNELS} conda -y

# 将激活环境写入配置文件中，保留长期有效
# 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
cat << 469138946ba5fa | tee -a /etc/environment "${HOME}/.profile"
. /opt/Miniforge/etc/profile.d/conda.sh
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
      echo ". /opt/Miniforge/etc/profile.d/conda.sh" | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
    fi
    ;;
  zsh)
    if ! grep -q "conda activate ${CONDA_PY_ENV}" "${HOME}/.zshrc"; then
      log_info "Initializing ${CONDA_PY_ENV} for zsh..."
      # 固化 ${CONDA_PY_ENV} 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo ". /opt/Miniforge/etc/profile.d/conda.sh" | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "Miniforge setup is complete."
mamba --version
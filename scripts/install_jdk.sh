#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting download and configuration of OpenJDK..."

# jdk 版本
# export JDK_VERSION=25

# GitHub 项目 URI
URI="adoptium/temurin${JDK_VERSION}-binaries"

# 获取最新版本
VERSIONS=$(curl -sL "https://github.com/${URI}/releases" | grep -Eo '/releases/tag/[^"]+' | awk -F'/tag/' '{print $2}' | head -n 1)
VERSION=$(echo "${VERSIONS#jdk-}" | sed 's;%2B;_;g;s;-beta;;g')
log_info "Latest version: ${VERSION}"

# 获取操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 映射平台到官方命名
case "${OS}" in
  Linux)
    PLATFORM="linux"
    if grep -qi 'alpine' /etc/*-release; then
      PLATFORM="alpine-linux"
    fi
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="aarch64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="x64"
    else
      log_error "Unsupported architecture: ${ARCH}"
      exit 1
    fi
    ;;
  Darwin)
    PLATFORM="mac"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="aarch64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="x64"
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
log_info "Detected beta release version..."
if [[ "${VERSIONS}" == *"beta"* ]]; then
  TARGET_FILE="OpenJDK-jdk_${ARCH}_${PLATFORM}_hotspot_${VERSION}.tar.gz"
else
  TARGET_FILE="OpenJDK${JDK_VERSION}U-jdk_${ARCH}_${PLATFORM}_hotspot_${VERSION}.tar.gz"
fi
SHA256_FILE="${TARGET_FILE}.sha256.txt"
URI_DOWNLOAD="https://github.com/${URI}/releases/download/${VERSIONS}/${TARGET_FILE}"
URI_SHA256="https://github.com/${URI}/releases/download/${VERSIONS}/${SHA256_FILE}"
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

tar xvf "/tmp/${TARGET_FILE}" -C /opt/

newjdk=$(ls -1d /opt/jdk* | sort | tail -n 1)
ln -fs "${newjdk}" "${HOME}/.jbang/currentjdk"

# 将激活环境写入配置文件中，保留长期有效
# 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
cat << '469138946ba5fa' | tee -a /etc/environment "${HOME}/.profile"
export JAVA_HOME=${HOME}/.jbang/currentjdk
export CLASSPATH=.:${JAVA_HOME}/lib
export PATH=${PATH}:${JAVA_HOME}/bin
469138946ba5fa

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -qEi 'JAVA_HOME|CLASSPATH' "${HOME}/.bashrc"; then
      log_info "Initializing jdk for bash..."
      # 固化 jdk 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
export JAVA_HOME=${HOME}/.jbang/currentjdk
export CLASSPATH=.:${JAVA_HOME}/lib
export PATH=${PATH}:${JAVA_HOME}/bin
469138946ba5fa
    fi
    ;;
  zsh)
    if ! grep -qEi 'JAVA_HOME|CLASSPATH' "${HOME}/.zshrc"; then
      log_info "Initializing jdk for zsh..."
      # 固化 jdk 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
export JAVA_HOME=${HOME}/.jbang/currentjdk
export CLASSPATH=.:${JAVA_HOME}/lib
export PATH=${PATH}:${JAVA_HOME}/bin
469138946ba5fa
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "OpenJDK configuration completed."

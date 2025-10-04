#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting clean of System..."

# Miniforge 安装路径
# export MAMBA_ROOT_PREFIX=/opt/Miniforge

# 清理 APT 缓存
clean_apt() {
  log_info "清理 init_system.sh 所产生的 APT 缓存..."
  apt autoremove -y && apt clean && apt autoclean && rm -rf /var/lib/apt/lists/* || true
  #apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y && rm -frv /var/lib/apt/lists/* || true
}

# 清理系统日志
clean_logs() {
  log_info "清理系统日志..."
  find /var/log -type f -name "*.log" -delete
  rm -f /var/log/*.gz /var/log/*.1 /var/log/*.old
}

# 清理临时文件
clean_temp() {
  log_info "清理临时文件..."
  rm -rf /tmp/* /var/tmp/*
}

# 清理用户缓存
clean_user_cache() {
  log_info "清理所有用户的缓存..."
  log_info "清理 root 的缓存"
  [ -d "/root/.cache" ] && rm -rf "/root/.cache"/* 2>/dev/null || true
  for user_home in /home/*; do
    [ -d "${user_home}/.cache" ] || continue
    log_info "清理 ${user_home} 的缓存"
    rm -rf "${user_home}/.cache"/* 2>/dev/null || true
  done
}

# 清理历史记录
clean_history() {
  log_info "清理命令历史记录..."
  # 清理当前用户的历史
  bash -c 'history -c' || true
  [ -f /root/.bash_history ] && shred -u /root/.bash_history 2>/dev/null || true
  [ -f /root/.zsh_history ] && shred -u /root/.zsh_history 2>/dev/null || true
  # 清理所有用户的历史
  for user_home in /home/*; do
    [ -d "${user_home}" ] && su - $(basename ${user_home}) bash -c 'history -c' 2>/dev/null || true
    [ -f "${user_home}/.bash_history" ] && shred -u "${user_home}/.bash_history" 2>/dev/null || true
    [ -f "${user_home}/.zsh_history" ] && shred -u "${user_home}/.zsh_history" 2>/dev/null || true
  done
}

# 执行清理操作
perform_cleanup() {
  log_info "执行系统清理..."
  clean_apt
  clean_logs
  clean_temp
  clean_user_cache
  clean_history
}

# 执行 Miniforge 清理操作
miniforge_cleanup() {
  # 清理 Miniforge 缓存和安装包，这个命令在某些 linux 系统环境里似乎具有破坏性
  # 清理 jupyter runtime 缓存（非必须）
  #rm -frv ~/.local/share/jupyter/runtime/*

  log_info "miniforge Cleaning up..."
  # 清理 conda 缓存包和 index
  ${MAMBA_ROOT_PREFIX}/bin/conda clean -afy
  ${MAMBA_ROOT_PREFIX}/bin/conda clean --tarballs --index-cache --packages --yes
  find ${MAMBA_ROOT_PREFIX} -follow -type f -name '*.a' -delete
  find ${MAMBA_ROOT_PREFIX} -follow -type f -name '*.pyc' -delete
  ${MAMBA_ROOT_PREFIX}/bin/conda clean --force-pkgs-dirs --all --yes
}

# 主逻辑
perform_cleanup
miniforge_cleanup

exit 0
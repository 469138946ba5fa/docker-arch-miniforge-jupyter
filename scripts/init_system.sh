#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting system initialization..."

# 设置 DEBIAN_FRONTEND 为 noninteractive，这样 tzdata 就不会进入交互模式
# export DEBIAN_FRONTEND=noninteractive
# 设置时区
# TZ='Asia/Shanghai'

# linux 包 apt 安装带重试逻辑
retry_linux_apt_install_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Installing linux packages in bulk (attempt ${i}/${retries})"
    if apt -y install --no-install-recommends "${pkgs[@]}"; then
      log_info "All linux packages installed successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to install linux packages, retrying after ${sleep_seconds}s..."
      sleep $sleep_seconds
    fi
  done
  log_error "Failed to install linux packages after ${retries} attempts."
  exit 1
}

# linux 包 eatmydata aptitude 安装带重试逻辑
retry_linux_eatmydata_aptitude_install_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Installing linux packages in bulk (attempt ${i}/${retries})"
    if eatmydata aptitude --without-recommends -o APT::Get::Fix-Missing=true -y install "${pkgs[@]}"; then
      log_info "All linux packages installed successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to install linux packages, retrying after ${sleep_seconds}s..."
      sleep $sleep_seconds
    fi
  done
  log_error "Failed to install linux packages after ${retries} attempts."
  exit 1
}

# 额外的APT工具和性能优化工具列表
apt_packages=(
  apt-transport-https    # 允许 APT 使用 HTTPS 协议访问软件仓库，提高传输安全性
  ca-certificates        # 根证书包，用于验证 SSL/TLS 链接，确保 HTTPS 通信安全
  aptitude               # APT 的文本界面前端工具，功能比 apt-get 更强大，也便于交互式使用（部分环境下可替代 apt-get）
  eatmydata              # 通过禁用 fsync 操作来加速软件安装过程，适用于临时构建环境以提高性能
)

# 所需系统软件包列表（基础系统工具和常用工具）
eatmydata_aptitude_packages=(
  tini               # 一个极简的 init 程序，用于容器中正确管理僵尸进程和信号转发
  bzip2              # 压缩和解压缩工具，用于处理 .bz2 格式的文件
  systemd            # 系统和服务管理器，有时用于基于 systemd 的容器或系统服务管理（在容器中用得较少，但有些基础镜像仍包含）
  tzdata             # 时区数据包，确保系统时间显示正确，并支持多时区设置
  locales            # 本地化支持包，提供各种语言环境，用于设置系统语言和字符编码
  perl               # Perl 脚本解释器，部分工具脚本可能依赖 Perl
  cron               # 定时任务调度工具，用于管理和执行定时任务
  git                # 分布式版本控制系统，用于代码管理和拉取远程仓库
  build-essential    # 一组构建工具（如 gcc、make 等），用于编译编译 C/C++ 等语言的代码
  curl               # 命令行 HTTP 请求工具，用于获取 URL 内容和进行网络调试
)

# 更新 apt 并安装所需软件包
apt update

# 一次性安装全部包
log_info "Installing linux packages individually with retries..."
retry_linux_apt_install_bulk "${apt_packages[@]}"

# 循环安装各软件包
#for pkg in "${apt_packages[@]}"; do
#  log_info "Installing linux packages individually with retries..."
#  retry_linux_apt_install_bulk "${pkg}"
#done

# 使用 eatmydata 提高安装效率
eatmydata aptitude --without-recommends -o APT::Get::Fix-Missing=true -y update

# 一次性安装全部包
log_info "Installing linux packages individually with retries..."
retry_linux_eatmydata_aptitude_install_bulk "${eatmydata_aptitude_packages[@]}"

# 循环安装各软件包
#for pkg in "${eatmydata_aptitude_packages[@]}"; do
#  log_info "Installing linux packages individually with retries..."
#  retry_linux_eatmydata_aptitude_install_bulk "${pkg}"
#done

ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
timedatectl set-timezone ${TZ} || true
timedatectl set-ntp true || true

# 比较当前时间与上海时间
compare_time() {
    current_time=$(date '+%Y-%m-%d %T')
    shanghai_time=$(TZ=${TZ} date '+%Y-%m-%d %T')
    echo "当前时间: ${current_time} <-> 上海时间: ${shanghai_time}"
}
compare_time

# 配置简体中文环境
sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_CTYPE=zh_CN.UTF-8

# 将激活环境及 locale 配置写入配置文件中，保留长期有效
# 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
cat << '469138946ba5fa' | tee -a /etc/default/locale /etc/environment "${HOME}/.profile"
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
469138946ba5fa

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -qEi 'LANG|LC_ALL|LANGUAGE|LC_CTYPE' "${HOME}/.bashrc"; then
      log_info "Initializing LANG|LC_ALL|LANGUAGE|LC_CTYPE for bash..."
      # 固化 LANG|LC_ALL|LANGUAGE|LC_CTYPE 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
469138946ba5fa
    fi
    ;;
  zsh)
    if ! grep -qEi 'LANG|LC_ALL|LANGUAGE|LC_CTYPE' "${HOME}/.zshrc"; then
      log_info "Initializing LANG|LC_ALL|LANGUAGE|LC_CTYPE for zsh..."
      # 固化 LANG|LC_ALL|LANGUAGE|LC_CTYPE 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
469138946ba5fa
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "System initialization completed."
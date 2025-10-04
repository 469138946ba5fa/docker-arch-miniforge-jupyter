# ubuntu 滚动版，追求新颖，不稳定
FROM docker.io/library/ubuntu:rolling

# 构建参数，只有构建阶段有效，构建完成后消失
# init_system.sh 所需临时环境变量
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ='Asia/Shanghai'
# install_miniforge.sh install_jupyter.sh 所需临时环境变量
ARG CONDA_CHANNELS=defaults
ARG PIP_CHANNELS='https://pypi.org/simple'
ARG PY_VERSION=3.12.10
ARG CONDA_PY_ENV=py${PY_VERSION}
# install_jdk.sh 所需临时环境变量
ARG JDK_VERSION=25
# ENV 需要固化的临时环境
ARG BUILD_HOME=/root
ARG MAMBA_ROOT_PREFIX=/opt/Miniforge
ARG JAVA_HOME=${BUILD_HOME}/.jbang/currentjdk
ARG CLASSPATH=.:${JAVA_HOME}/lib
ARG PATH=${MAMBA_ROOT_PREFIX}/bin:${BUILD_HOME}/.jbang/bin:${JAVA_HOME}/bin:${PATH}

# 固化运行环境变量，全局构建和容器运行都可用，字符支持，安装目录，以及启动路径
# init_system.sh 所需固化环境 LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_CTYPE=zh_CN.UTF-8
# install_miniforge.sh install_jupyter.sh clean.sh 所需固化环境 MAMBA_ROOT_PREFIX=/opt/Miniforge PATH=${MAMBA_ROOT_PREFIX}/bin:${PATH}
# install_jbang.sh 所需固化环境 PATH=$HOME/.jbang/bin:${PATH}
# install_jdk.sh 所需固化环境 JAVA_HOME=$HOME/.jbang/currentjdk CLASSPATH=.:$JAVA_HOME/lib PATH=$PATH:$JAVA_HOME/bin
# start_jupyter.sh 所需全部固化环境
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN.UTF-8 \
    LC_CTYPE=zh_CN.UTF-8 \
    MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX} \
    JAVA_HOME=${JAVA_HOME} \
    CLASSPATH=${CLASSPATH} \
    CONDA_PY_ENV=${CONDA_PY_ENV} \
    PATH=${PATH}

# 添加常用LABEL（根据需要修改）添加标题 版本 作者 代码仓库 镜像说明，方便优化
LABEL org.opencontainers.image.description="miniforge 安装 jupyter notebook 封装特殊需求自用 python 测试容器." \
      org.opencontainers.image.title="Miniforge Jupyter" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="469138946ba5fa <af5ab649831964@gmail.com>" \
      org.opencontainers.image.source="https://github.com/469138946ba5fa/docker-arch-miniforge-jupyter" \
      org.opencontainers.image.licenses="MIT"

# 设置工作目录 /notebook 仅用于 Notebook 数据挂载（保持干净）
WORKDIR /notebook

# 复制所有脚本到 /usr/local/bin（保持工作目录干净）
# 执行安装与配置脚本（全部以 root 执行）
COPY scripts/ /usr/local/bin/

# 执行 初始化 安装 清理 三大流程
# 移除残留脚本 init_system.sh install_miniforge.sh install_jupyter.sh install_jbang.sh install_jdk.sh clean.sh
# 保留日志脚本 common.sh
# 启动脚本 start_jupyter.sh
# analyze_size.sh 检查安装前、后与清理后的镜像大小记录变化，不过镜像似乎无法优化了，😮‍💨
# 总结：似乎镜像无法优化了，已到绝处，无法逢生，在绝对的力量面前任何优化手段都毫无意义😮‍💨
# analyze_size.sh after-install before-install
# analyze_size.sh after-clean after-install
RUN cd /usr/local/bin/ && \
    chmod -v a+x *.sh && \
    analyze_size.sh before-install && \
    init_system.sh && \
    install_miniforge.sh && \
    install_jupyter.sh && \
    install_jbang.sh && \
    install_jdk.sh && \
    analyze_size.sh after-install && \
    clean.sh && \
    rm -fv init_system.sh install_miniforge.sh install_jupyter.sh install_jbang.sh install_jdk.sh clean.sh && \
    analyze_size.sh after-clean

# 固化端口
EXPOSE 8888
# 健康检查
HEALTHCHECK CMD curl -f http://localhost:8888 || exit 1

# 使用 tini 作为入口，调用 entrypoint 脚本或者直接启动 /usr/local/bin/start_jupyter.sh
ENTRYPOINT ["tini", "--"]
# 脚本执行
CMD [ "/usr/local/bin/start_jupyter.sh" ]
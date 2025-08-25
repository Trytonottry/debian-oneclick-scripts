# Base image
FROM debian:12-slim

# Автор
LABEL maintainer="reverse-engineer@example.com"

# Не интерактивный режим
ENV DEBIAN_FRONTEND=noninteractive

# Установка зависимостей и инструментов
RUN apt update && apt upgrade -y && \
    apt install -y \
        openjdk-17-jre \
        openjdk-17-jdk \
        wget \
        unzip \
        git \
        p7zip-full \
        python3-pip \
        curl \
        libgtk-3-0 \
        libwebkit2gtk-4.0-37 \
        libfuse2 \
        xdg-utils \
        libxtst6 \
        libxrender1 \
        libxrandr2 \
        libgtk-3-0 \
        libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /home/tools
ENV HOME=/home/tools
ENV PATH=${PATH}:/home/tools/bin

# Установка инструментов
RUN mkdir -p /home/tools/bin

# 1. JADX
RUN wget -q https://github.com/skylot/jadx/releases/download/v1.5.0/jadx-1.5.0.zip && \
    unzip jadx-1.5.0.zip && \
    mv jadx-1.5.0 jadx && \
    ln -s /home/tools/jadx/bin/jadx /home/tools/bin/jadx && \
    ln -s /home/tools/jadx/bin/jadx-gui /home/tools/bin/jadx-gui && \
    rm jadx-1.5.0.zip

# 2. APKTool
RUN wget -O /home/tools/bin/apktool.jar https://bitbucket.org/iBotPeaches/apktool/downloads/apktool-2.9.3.jar && \
    echo '#!/bin/bash' > /home/tools/bin/apktool && \
    echo 'java -jar /home/tools/bin/apktool.jar "$@"' >> /home/tools/bin/apktool && \
    chmod +x /home/tools/bin/apktool

# 3. dex2jar
RUN git clone --depth 1 https://github.com/pxb1988/dex2jar.git && \
    chmod +x dex2jar/*.sh && \
    ln -s /home/tools/dex2jar/d2j-dex2jar.sh /home/tools/bin/dex2jar

# 4. radare2
RUN apt update && apt install -y radare2

# 5. Ghidra
RUN wget -O ghidra.zip https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20230614.zip && \
    7z x ghidra.zip && rm ghidra.zip && \
    mv ghidra_* ghidra && \
    ln -s /home/tools/ghidra/ghidraRun /home/tools/bin/ghidra

# 6. Frida & Objection
RUN pip3 install frida-tools objection

# 7. MobSF
RUN git clone --depth 1 https://github.com/MobSF/Mobile-Security-Framework-MobSF.git && \
    cd Mobile-Security-Framework-MobSF && \
    pip3 install -r requirements.txt

# Скрипт запуска
COPY start.sh /home/tools/start.sh
RUN chmod +x /home/tools/start.sh

# Объём для APK
VOLUME /home/tools/apks

# Expose MobSF web port
EXPOSE 8000

# Запуск
CMD ["/home/tools/start.sh"]
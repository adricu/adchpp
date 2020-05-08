FROM python:2.7.18-buster

ENV DEBIAN_FRONTEND noninteractive
ENV HOME /root

RUN apt-get update && \
    apt-get install curl swig ruby scons \
    build-essential libreadline-dev libssl-dev \
    lua5.1 liblua5.1-0 pwgen -yq

RUN mkdir -p /usr/src/adchpp

WORKDIR /usr/src/adchpp

ADD . .
RUN scons mode=release arch=x64
RUN cd build && \
    cp -rp release-default-x64 /opt/adchpp && \
    cp -rp /usr/src/adchpp/plugins/Script/examples /opt/adchpp/Scripts && \
    mkdir -p /usr/local/lib/lua/5.1 && \
    ln -s /opt/adchpp/bin/luadchpp.so /usr/local/lib/lua/5.1/luadchpp.so

WORKDIR /opt/adchpp

ADD start.sh /opt/adchpp/start.sh
RUN chmod +x /opt/adchpp/start.sh

VOLUME ["/data"]

EXPOSE 2780

CMD ["./start.sh"]

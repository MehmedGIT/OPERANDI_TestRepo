FROM ubuntu:18.04
MAINTAINER OPERANDI
ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONIOENCODING utf8
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

WORKDIR /OPERANDI_TestRepo

COPY . .
RUN chmod -R 765 .

RUN apt-get update
RUN apt-get -y install \
	ca-certificates \
	software-properties-common \
	python3-dev \
	python3-pip \
	make \
	wget \
	time \
	curl \
	sudo \
	git \
	&& make deps-ubuntu \
	&& pip3 install --upgrade pip setuptools \
	&& pip3 install -r requirements_test.txt \
	&& make install 

# Install the RabbitMQ Server (required for the priority_queue)
RUN ./src/priority_queue/repo_setup.deb.sh	
RUN ./src/priority_queue/install.sh

# No entry point for the docker image
CMD /bin/bash

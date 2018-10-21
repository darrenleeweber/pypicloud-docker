FROM phusion/baseimage:0.11
MAINTAINER Steven Arcangeli <stevearc@stevearc.com>
MAINTAINER Darren Weber <dweber.consulting@gmail.com>

ENV PYPICLOUD_VERSION 1.0.9

EXPOSE 8080

# Get security updates etc. - adds approx 25Mb
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -qq && \
    apt-get -qy autoremove && \
    apt-get -qy autoclean && \
    rm -rf /tmp/* /var/tmp/*

# Install python3
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get install -qq -y --no-install-recommends python3-dev python3-pip python3-setuptools python3-wheel && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/*

# Set python3 as the default python
RUN update-alternatives --install /usr/bin/python python $(which python3) 2 && \
    update-alternatives --install /usr/bin/python-config python-config $(which python3-config) 2 && \
    update-alternatives --install /usr/bin/pydoc pydoc $(which pydoc3) 2 && \
    update-alternatives --install /usr/bin/pip pip $(which pip3) 2 && \
    update-alternatives --auto python && \
    update-alternatives --auto python-config && \
    update-alternatives --auto pydoc && \
    update-alternatives --auto pip

# Install application run-time dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy \
     libldap2-dev libsasl2-dev libmysqlclient-dev libffi-dev libssl-dev

# pip >= 10.x breaks a lot of package installations.
# Until we can trust that pip > 9.x is working well, lets stick with 9.0.3.
# For more details on pip releases, see https://pip.pypa.io/en/stable/news/
RUN pip install --upgrade pip==9.0.3

# Python application run-time dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends gcc && \
    pip install pypicloud[all_plugins]==$PYPICLOUD_VERSION requests uwsgi pastescript mysqlclient psycopg2-binary && \
    rm -rf ~/.cache/pip/* && \
    DEBIAN_FRONTEND=noninteractive apt-get remove -qq -y gcc python3-pip python3-setuptools python3-wheel && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create the pypicloud user
RUN groupadd -r pypicloud && \
    useradd -r -g pypicloud -d /var/lib/pypicloud -m pypicloud

# Make sure this directory exists for the baseimage init
RUN mkdir -p /etc/my_init.d

# Add the startup service
ADD pypicloud-uwsgi.sh /etc/my_init.d/pypicloud-uwsgi.sh

# Add the pypicloud config file
RUN mkdir -p /etc/pypicloud
ADD config.ini /etc/pypicloud/config.ini

# Create a working directory for pypicloud
VOLUME /var/lib/pypicloud

# Add the command for easily creating config files
ADD make-config.sh /usr/local/bin/make-config

# Add an environment variable that pypicloud-uwsgi.sh uses to determine which
# user to run as
ENV UWSGI_USER pypicloud

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

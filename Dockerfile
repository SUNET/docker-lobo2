FROM ubuntu
MAINTAINER Leif Johansson <leifj@sunet.se>
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get -q update
RUN apt-get -y upgrade
RUN apt-get install -y git-core libyaml-dev python-dev build-essential libz-dev python-virtualenv apache2 libapache2-mod-shib2 ssl-cert libapache2-mod-wsgi libjpeg-dev
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod shib2
RUN a2enmod headers
RUN a2enmod wsgi
RUN virtualenv /usr/lobo2
RUN mkdir -p /var/run/lobo2
WORKDIR /var/run/lobo2
ENV VENV /usr/lobo2
RUN virtualenv /usr/lobo2
ADD invenv.sh /invenv.sh
RUN chmod a+x /invenv.sh
ADD start.sh /start.sh
RUN chmod a+x /start.sh
RUN /invenv.sh pip install --upgrade -r https://raw.githubusercontent.com/SUNET/lobo2/master/requirements.txt
RUN /invenv.sh pip install --upgrade git+git://github.com/SUNET/lobo2.git#egg=lobo2
RUN rm -f /etc/apache2/sites-available/*
RUN rm -f /etc/apache2/sites-enabled/*
ADD md-signer.crt /etc/shibboleth/md-signer.crt
ADD attribute-map.xml /etc/shibboleth/attribute-map.xml
ENV SP_HOSTNAME datasets.sunet.se
ENV SP_CONTACT noc@sunet.se
ENV SP_ABOUT /about
ENV METADATA_SIGNER md-signer.crt
COPY apache2.conf /etc/apache2/
EXPOSE 443
EXPOSE 80
ENTRYPOINT ["/start.sh"]

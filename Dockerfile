FROM ubuntu
MAINTAINER Leif Johansson <leifj@sunet.se>
RUN apt-get update
RUN apt-get install -y git-core libyaml-dev python-dev build-essential libz-dev python-virtualenv
RUN virtualenv /usr/lobo2
RUN mkdir -p /var/run/lobo2
WORKDIR /var/run/lobo2
ENV VENV /usr/pyff
ENV BASE_URL http://localhost:8080
ADD invenv.sh /invenv.sh
RUN chmod a+x /invenv.sh
ADD invenv.sh /start.sh
RUN chmod a+x /start.sh
RUN /invenv.sh pip install --upgrade git+git://github.com/leifj/lobo2.git#egg=lobo2
EXPOSE 8080
ENTRYPOINT ["/start.sh"]

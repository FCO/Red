FROM gitpod/workspace-full
USER root
RUN apt-get update                                                 \
  && apt-get install -y build-essential uuid-dev sqlite3

USER gitpod
RUN git clone https://github.com/tadzik/rakudobrew ~/.rakudobrew
#RUN zef install --/test App::Mi6 DBIish
USER gitpod

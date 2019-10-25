FROM gitpod/workspace-full
USER root
RUN apt-get update                                                 \
  && apt-get install -y build-essential uuid-dev sqlite3

USER gitpod
RUN git clone http://github.com/rakudo/rakudo && cd rakudo && ./Configure.pl --gen-moar --gen-nqp && make install && cd -
RUN ls && ls rakudo
RUN git clone http://github.com/ugexe/zef && cd zef && perl6 -I. bin/zef install .
RUN zef install --/test App::Mi6 DBIish

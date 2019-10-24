FROM jjmerelo/alpine-perl6
COPY META6.json .
RUN  apk add gcc libc-dev libuuid sqlite-libs
RUN  zef install "NativeLibs:ver<0.0.7>:auth<github:salortiz>" --/force
RUN  zef install Config Config::Parser::json --/force
RUN  zef install --deps-only . --/force
RUN  zef install -v .

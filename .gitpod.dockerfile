FROM jjmerelo/alpine-perl6
COPY META6.json .
RUN  apk add gcc libc-dev libuuid sqlite-libs
RUN  zef install "NativeLibs:ver<0.0.7>:auth<github:salortiz>" --force-test
RUN  zef install Config Config::Parser::json
RUN  zef install --deps-only .
RUN  zef install -v .

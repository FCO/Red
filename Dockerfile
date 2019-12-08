FROM        registry.gitlab.com/tyil/docker-perl6:alpine-latest
WORKDIR     /code
COPY        META6.json .
RUN         apk add git gcc libc-dev libuuid sqlite-libs
RUN         zef install "NativeLibs:ver<0.0.7>:auth<github:salortiz>" --force-test
RUN         zef install Config Config::Parser::json
RUN         zef install --deps-only .
ENTRYPOINT  zef install -v .
VOLUME      /code

FROM rakudo-star:alpine
WORKDIR /code
COPY . .
ENV PATH="/usr/share/raku/site/bin:/usr/local/share/raku/site/bin:/usr/share/perl6/site/bin:/usr/local/share/perl6/site/bin:${PATH}"
RUN apk add --no-cache git gcc libc-dev libuuid sqlite-libs postgresql-dev postgresql-libs openssl-dev make bash
RUN zef install --/test Config Config::Parser::json App::Prove6
RUN zef install --/test --test-depends --deps-only .
ENTRYPOINT ["zef","install","-v","."]

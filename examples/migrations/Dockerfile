FROM rakudo-star:2026.09-bookworm
COPY --from=docker:28-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:28-cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
USER root
RUN apt-get update && apt-get install -y git curl neovim libpq-dev postgresql-client sqlite3 default-mysql-client uuid-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/red
COPY META6.json README.md ./
RUN zef install --/test Cro::HTTP App::Prove6 DB::Pg UUID Configuration
ARG PG_DRIVER_REVISION=6615b55d109db7ea7ca3469364080e873f1bf9a5
RUN curl -fsSL --retry 3 "https://codeload.github.com/FCO/Red-Driver-Pg/tar.gz/${PG_DRIVER_REVISION}" -o /tmp/pg.tar.gz \
    && mkdir /tmp/pg && tar -xzf /tmp/pg.tar.gz -C /tmp/pg --strip-components=1
COPY lib lib
COPY bin bin
RUN zef install --/test . && zef install --/test /tmp/pg
COPY examples/migrations/template /opt/workshop/template
COPY examples/migrations/Workshop.rakumod examples/migrations/guide.raku examples/migrations/start-dev.raku /opt/workshop/
COPY examples/migrations/workshop.raku examples/migrations/compose.yaml /opt/workshop/
COPY examples/migrations/workshop-command.raku /usr/local/bin/workshop
RUN chmod +x /usr/local/bin/workshop
RUN raku /opt/workshop/guide.raku init /opt/workshop/initial
WORKDIR /workspace
CMD ["raku", "/opt/workshop/start-dev.raku"]

FROM gitpod/workspace-full
USER root
RUN apt-get update && apt-get install -y build-essential uuid-dev sqlite3

USER gitpod
RUN git clone https://github.com/tadzik/rakudobrew ~/.rakudobrew
RUN command ~/.rakudobrew/bin/rakudobrew internal_hooked "build" "moar"
RUN command ~/.rakudobrew/bin/rakudobrew internal_hooked "global" "moar-2019.07.1"
RUN command ~/.rakudobrew/bin/rakudobrew internal_hooked "build" "zef"
USER gitpod

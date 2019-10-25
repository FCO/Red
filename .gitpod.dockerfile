FROM gitpod/workspace-full
USER root
RUN apt-get update                                                 \
  && apt-get install -y build-essential uuid-dev sqlite3 perl6

USER gitpod
RUN zef install --/test App::Mi6 DBIish
ENV PATH /home/gitpod/.pyenv/plugins/pyenv-virtualenv/shims:/home/gitpod/.pyenv/shims:/workspace/.cargo/bin:/workspace/.pip-modules/bin:/workspace/.rvm/bin:/home/gitpod/.cargo/bin:/home/gitpod/.rvm/gems/ruby-2.6.3/bin:/home/gitpod/.rvm/gems/ruby-2.6.3@global/bin:/home/gitpod/.rvm/rubies/ruby-2.6.3/bin:/home/gitpod/.sdkman/candidates/maven/current/bin:/home/gitpod/.sdkman/candidates/java/current/bin:/home/gitpod/.sdkman/candidates/gradle/current/bin:/home/gitpod/.pyenv/bin:/home/gitpod/.pyenv/shims:/home/gitpod/.nvm/versions/node/v10.15.3/bin:/workspace/go/bin:/home/gitpod/go/bin:/home/gitpod/go-packages/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin/:/home/gitpod/.rvm/bin:/home/gitpod/.rvm/bin:/home/gitpod/.perl6
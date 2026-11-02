ARG DEV_IMAGE=red-migrations-dev:local
FROM ${DEV_IMAGE}
WORKDIR /workspace
COPY . .
CMD ["raku", "-Ilib", "app.raku"]

FROM crystallang/crystal:1.16.3-alpine AS builder

RUN apk add --no-cache sqlite-static yaml-static
# we dont need dos2unix becuase i already converted the files
ARG release

WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/

# Required for fetching player dependencies
COPY ./scripts/ ./scripts/
COPY ./assets/ ./assets/
COPY ./videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all \
    --link-flags "-lxml2 -llzma"    
RUN  if [[ "${release}" == 1 ]] ; then \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM alpine:3.21
RUN apk add --no-cache rsvg-convert ttf-opensans tini tzdata

WORKDIR /invidious

# Create invidious user
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious

# Copy static assets
COPY ./config/config.yml ./config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .

# Adjust permissions
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]

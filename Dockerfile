FROM ethereum/client-go AS geth-builder
FROM node:8-alpine

RUN apk add --no-cache git bash curl
COPY --from=geth-builder /usr/local/bin/geth /usr/local/bin/geth

# FIXME: This is required to install the experimental abi web3 package
# Once it gets released on npm, we will probably not need this
RUN apk add --no-cache python make g++
RUN yarn global add lerna

WORKDIR /app

# Install only the dependencies so they can be cached as a docker layer
COPY package.json ./
COPY package-lock.json ./
RUN yarn install

COPY . .

ENV CONTRACT_INFO_PATH "/contract"
RUN mkdir /contract

ENV RPC_URL "http://127.0.0.1:8545"
RUN yarn run init ; yarn run geth & yarn start ; pkill -f geth

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD [ -f /contract/address ] && curl http://localhost:8546 || exit 1

EXPOSE 8545 8546
CMD [ "yarn", "run", "geth" ]

from rust

WORKDIR /usr/src/Wallet
COPY . .

RUN cargo install --path .

CMD ["Wallet"]


# Runtime image
FROM debian:buster-slim

EXPOSE 9876/tcp

COPY --from=0 /usr/src/Wallet/target/release/Wallet /usr/local/bin/Wallet

CMD ["Wallet"]
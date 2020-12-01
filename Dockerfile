# Build the manager binary
FROM golang:1.15-alpine as builder

WORKDIR /workspace

# copy modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Copy this, which should not change often; and, needs to be in place
# before `go mod download`.
COPY api/ api/

# cache modules
RUN go mod download

# copy source code
COPY main.go main.go
COPY controllers/ controllers/
COPY internal/ internal/

# build without giving the arch, so that it gets it from the machine
RUN CGO_ENABLED=0 go build -a -o image-reflector-controller main.go

FROM alpine:3.12

LABEL org.opencontainers.image.source="https://github.com/fluxcd/image-reflector-controller"

# Create minimal nsswitch.conf file to prioritize the usage of /etc/hosts over DNS queries.
# https://github.com/gliderlabs/docker-alpine/issues/367#issuecomment-354316460
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

RUN apk add --no-cache ca-certificates tini

COPY --from=builder /workspace/image-reflector-controller /usr/local/bin/

RUN addgroup -S controller && adduser -S -g controller controller

USER controller

ENTRYPOINT [ "/sbin/tini", "--", "image-reflector-controller" ]

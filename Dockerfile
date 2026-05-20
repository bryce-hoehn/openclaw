FROM nixos/nix:latest AS builder
RUN printf "extra-experimental-features = nix-command flakes\n" >> /etc/nix/nix.conf

ARG REPO=podmania/<%= name %>
RUN nix build "github:${REPO}#<%= name %>" --impure --out-link /build/result
RUN mkdir -p /rootfs/nix/store && \
    for path in $(nix-store -qR /build/result); do \
      cp -a "$path" "/rootfs$path"; \
    done && \
    cp -aL /build/result "/rootfs/nix/store/app"

FROM ghcr.io/podmania/base:latest
COPY --from=builder /rootfs /
ENTRYPOINT ["/nix/store/app/bin/<%= main_program or name %>"<% for arg in cmd_args %>, "<%= arg %>"<% endfor %>]

FROM caddy:builder AS builder

# Clone caddy-dns/cloudflare and patch token validation to accept new cfut_ format
RUN git clone --depth=1 https://github.com/caddy-dns/cloudflare.git /tmp/caddy-dns-cf

# Replace validation condition with false — block stays (keeps fmt valid) but never runs
RUN sed -i.bak 's/if !validCloudflareToken(p.Provider.APIToken)/if false/' \
    /tmp/caddy-dns-cf/cloudflare.go && \
    grep -n "validCloudflare\|if false" /tmp/caddy-dns-cf/cloudflare.go

RUN xcaddy build --with github.com/caddy-dns/cloudflare=/tmp/caddy-dns-cf

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

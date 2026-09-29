FROM alpine:3.24

RUN apk add --no-cache ca-certificates \
 && addgroup -g 1000 pocketbase \
 && adduser -D -H -u 1000 -G pocketbase pocketbase

WORKDIR /pb

COPY --chmod=755 pocketbase /pb/pocketbase

# PocketBase's default dirs; owned by the app user so named volumes inherit it
RUN mkdir pb_data pb_public pb_hooks pb_migrations \
 && chown pocketbase:pocketbase pb_data pb_public pb_hooks pb_migrations \
 && ./pocketbase --version

# Runs once on a fresh database: first superuser from env vars, if set
COPY --chown=pocketbase:pocketbase <<'EOF' /pb/pb_migrations/0_superuser_from_env.js
migrate((app) => {
  const email = $os.getenv("PB_SUPERUSER_EMAIL")
  const password = $os.getenv("PB_SUPERUSER_PASSWORD")
  if (!email || !password || app.countRecords("_superusers") > 0) return

  const record = new Record(app.findCollectionByNameOrId("_superusers"))
  record.set("email", email)
  record.set("password", password)
  app.save(record)
})
EOF

USER pocketbase

EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8090/api/health || exit 1

ENTRYPOINT ["/pb/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090", "--encryptionEnv=PB_ENCRYPTION_KEY"]

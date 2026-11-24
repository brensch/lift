#!/bin/sh
# Copy the certificate Caddy keeps for each domain to where its backend reads
# it for its own TLS listener (src/tls.rs): Caddy's copy is readable only by
# Caddy. Run by schlift-tls-sync.service whenever Caddy's certificates change
# (schlift-tls-sync.path) and once at boot; the backend notices the new files
# within ten minutes. Arguments: pairs of DOMAIN DEST_DIR OWNER.
set -eu
caddy_certs=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory
while [ "$#" -ge 3 ]; do
	domain=$1 dest=$2 owner=$3
	shift 3
	src=$caddy_certs/$domain
	[ -f "$src/$domain.crt" ] && [ -f "$src/$domain.key" ] || {
		echo "no certificate for $domain yet" >&2
		continue
	}
	install -d -m 700 -o "$owner" "$dest"
	install -m 644 -o "$owner" "$src/$domain.crt" "$dest/$domain.crt.new"
	install -m 600 -o "$owner" "$src/$domain.key" "$dest/$domain.key.new"
	# The key first: a backend reloading between the two renames reads the
	# new certificate only once its key is in place.
	mv "$dest/$domain.key.new" "$dest/$domain.key"
	mv "$dest/$domain.crt.new" "$dest/$domain.crt"
done

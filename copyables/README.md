# Running the vpn command inside copyables to use the vpncmd-funcs.sh to create users:

Create an .env file with the following values:

```bash
ADMIN_PASS=<admin_server_pass>
VPN_HOST=172.15.0.91
VPN_PORT=5555
USERS=<username>:<pass>;<username>:<pass>;matthew.blades:<pass>;<username>:<pass>
```

Then run the following in that directory:

```bash
docker run --rm -it -v $(pwd):/data --entrypoint=sh  --env-file=.env siomiz/softethervpn /data/vpncmd-funcs.sh
```


# Eclipse render worker

A small container that lends a machine, and its graphics card, to an Eclipse
studio for rendering video.

- **Setup page:** https://vilkam.github.io/eclipse-remote-worker/
- **Instructions for an AI agent on the machine:** [docs/agent.txt](docs/agent.txt)
- **Image:** `ghcr.io/vilkam/eclipse-remote-worker:0.1.0`
  (`sha256:742e30c9675fa06826dde0cbcf308d27d35d2e991619bf1eab70852dc2c56e19`)

## What is in the image

`Dockerfile` and `entrypoint.sh` in this repository are the whole image:
ffmpeg, Python with NumPy, Pillow, OpenCV and SciPy, and an SSH server that
accepts one ed25519 key given in `ECLIPSE_WORKER_KEY`. It holds no application
code, font, model, credential or footage. Each job brings what it needs and
takes its result back.

## What the key allows

The studio that holds the matching private key can copy files into the
container's `/workspace` and run programs inside the container. It cannot log in
with a password, forward connections, or reach files outside the container's
volume.

## Start one

```sh
docker run -d --name eclipse-worker --restart unless-stopped --gpus all \
  -p 2222:22 -v eclipse-worker:/workspace \
  -e ECLIPSE_WORKER_KEY="ssh-ed25519 AAAA... eclipse-studio" \
  ghcr.io/vilkam/eclipse-remote-worker:0.1.0
docker logs eclipse-worker   # shows the host key line the studio needs
```

The setup page covers RunPod, a Linux server and a Windows PC, and how to keep
the port off the public internet.

## Remove it

```sh
docker rm -f eclipse-worker
docker volume rm eclipse-worker
docker rmi ghcr.io/vilkam/eclipse-remote-worker:0.1.0
```

## Versions

A published version is never replaced. A change to the image raises `VERSION` in
`.github/workflows/image.yml`, and the workflow refuses to push over an existing
one.

dev:
    docker build -f Dockerfile.dev -t magic-tmux-dev .
    docker run --rm --name magic-tmux-dev -it magic-tmux-dev

fullbuild:
    docker build -t magic-tmux -o output .

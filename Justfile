dev *DEVARGS:
    docker compose build dev
    docker compose run --rm dev {{DEVARGS}}

fullbuild:
    docker build -t magic-tmux -o output .

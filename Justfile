export UID := `id -u`

refresh-builder:
    docker compose build builder

create-output-dir:
    mkdir -p ./output

dev *DEVARGS: refresh-builder
    docker compose run --rm dev {{DEVARGS}}

build +TO_BUILD: refresh-builder create-output-dir
    docker compose run --rm builder {{TO_BUILD}}

fullbuild: refresh-builder create-output-dir
    docker compose run --rm builder

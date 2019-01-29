# JDP

Extensible, semi-automated, test review and reporting development
environment. Initially targeted at SUSE's QA Kernel & Networking team's
requirements, but this is intended to have general applicability at least
within SUSE QA.

# Install

The goal is to do this in a single command, but for now it takes a few more.

## Docker

You can install using Docker by doing the following from the directory where
you cloned this repo. This is probably the easiest way if you just want to
quickly try it out.

```sh
docker build -t jdp:latest -f install/Dockerfile .
```

Or you can substitute the build command for the following which will get a
pre-built image from hub.docker.com (it may not be up to date).

```sh
docker pull suserichiejp/jdp:latest
```

Then you can inject the access details for the data cache server if you have
them. Using the data cache can save a lot of time.

```sh
docker build -t jdp:latest -f install/Dockerfile-slave \
             --build-arg REDIS_MASTER_HOST=ip-or-name \
             --build-arg REDIS_MASTER_AUTH=password .
```

Then run it
```sh
docker run -it -p 8889:8889 jdp:latest
```

With a bit of luck you will see a message from Jupyter describing what to do
next. The Docker image also contains two volumes which you may mount. See the
Dockerfile for more info.

You can use the Docker image for developing JDP itself by mounting the `src`
volume. However this is probably not a good long term solution.

## Other

You can use install/Dockerfile as a guide. Also check `conf/*.toml`.

You can run JDP directly from the git checkout. Just install the deps listed
in the Dockerfile and modify the conf files (which should include there own
documentation).

# Usage

## With Jupyter

If you are using the Docker image then just browse to
[localhost:8889](http://localhost:8889). If not then start Jupyter yourself.

Open either the `notebooks/Report-DataFrames.ipynb` or `notebooks/Propagate
Bug Tags.ipynb` Jupyter notebooks which are (hopefully) self documenting. I
have only tested them with Jupyter itself, but there are fancier alternatives
such as JupyterLab and, of course, Emacs.

## Other

You can also use the library from a Julia REPL or another project. For example
in a julia REPL you could run

```julia
include("src/init.jl")
```

Also the `run` directory contains scripts which are intended to automate
various tasks. These can be executed with Julia in a similar way to `julia
run/all.jl`.

## Automation

JDP is automated using SUSE's internal Gitlab CI instance. Which automates
building and testing the containers as well as deployment and the execution of
various scripts/services. See `install/gitlab-ci.*`.

# Documentation

Further documentation can be found here:
https://richiejp.github.io/jdp/docs/build/index.html

You can also find documentation at the Julia REPL by typing `?` followed by an
identifier or in a notebook you can type `@doc identifier` in a code cell.

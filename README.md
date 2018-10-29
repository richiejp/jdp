# JDP

Extensible, semi-automated, test review and reporting development
environment. Initially targeted at SUSE's QA Kernel & Networking team's
requirements, but this is intended to have general applicability at least
within SUSE QA.

See [report.ipynb](https://github.com/richiejp/jdp/blob/master/notebooks/report.ipynb)
to get a better idea of what this is about.

This is work in progress. We desperately need to create a central data cache
because fetching it from OpenQA and Bugzilla is too slow. However fetching a
few builds worth of data is OK, so you can try this out now.

# Install

The goal is to do this in a single command, but for now it takes a few more.

## Docker

You can install using Docker by doing the following from the directory where
you cloned this repo.

```sh
docker build -t jdp -f install/Dockerfile .
docker run -it -p 8889:8889 jdp
```

Or you can substitute the build command for the following which will get a
pre-built image from hub.docker.com (it may not be up to date).

```sh
docker pull suserichiejp/jdp
```

With a bit of luck you will see a message from Jupyter describing what to do
next. The Docker image also contains two volumes which you may mount. See the
Dockerfile for more info.

## Other

You can use install/Dockerfile as a guide. Also check `conf/data.toml`.

# Usage

## With Jupyter

Open either the `report.ipynb` or `bugrefs.ipynb` Jupyter notebooks which are
(hopefully) self documenting. I have only tested them with Jupyter itself, but
there are fancier alternatives such as JupyterLab and, of course, Emacs.

## Other

You can also use the library from a Julia REPL or another project. For example
in a julia REPL you could run

```julia
include("src/startup.jl")
```

# Documentation

Further documentation can be found here:
https://richiejp.github.io/jdp/docs/build/index.html

You can also find documentation at the Julia REPL by typing `?` followed by an
identifier or in a notebook you can type `@doc identifier` in a code cell.

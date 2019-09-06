# JDP

In simple terms; JDP makes creating test result reports (amongst other things)
easy.

In less simple terms, JDP is an Extensible, sometimes automated, test/bug
review and reporting development environment. The broader aim is to *make
prototyping arbitrary reporting and inter-tool workflows cheap* so that
experimentation in this area has a convex payoff.

* JDP may be used as a library in a larger project or as an
  application/service[^1].
* JDP is not a polished product for non-technical users, but you can use it to
  make that.
* JDP makes data from multiple sources/trackers easily accessible, but it is
  [not a source of truth](development/index.html#Not-a-source-of-truth-1).
* JDP can post back to trackers; it can automate workflows other than
  reporting.
* JDP is intended to fit *into* a CI/CD pipeline or take over unusual sections
  of a pipeline, it is not intended as a replacement for Jenkins, GoCD,
  GitlabCI, etc.

Initially JDP is targeted at SUSE's QA Kernel & Networking team's
requirements, however it is a general purpose tool at its core. It could be
used with any type of data for most any type of workflow or reporting.

![Video Presentation (internal)](https://w3.suse.cz/~rpalethorpe/jdp-poc-pres.webm)
[Video Presentation (external)](https://youtu.be/Nzha4itchg8)

!!! tip

    This README is best viewed through the [docs site](https://rpalethorpe.io.suse.de/jdp/) ([public
    mirror](https://palethorpe.gitlab.io/jdp)).
    Otherwise *admonition blocks* like this will be misinterpreted as literal
    blocks.

[^1]:

    In the sense that the JDP project comes bundled with some scripts for
    using it with Jupyter amongst other things.

# Install

I don't recommend using Docker for development or regular use on your
workstation (see installing from Git). However it is very useful for
deployment to an automated production environment.

!!! note

    SUSE employees and associates should view this at:
    [gitlab.suse.de/rpalethorpe/jdp](https://gitlab.suse.de/rpalethorpe/jdp)

## Docker

You can install using Docker by doing the following from the directory where
you cloned this repo.

```sh
docker build -t jdp:latest -f install/Dockerfile .
```

Or you can substitute the build command for the following which will get a
pre-built image from hub.docker.com (it may not be up to date).

```sh
docker pull suserichiejp/jdp:latest
```

Then you can inject the access details for a central data cache server if you
have them.

```sh
docker build -t jdp:latest -f install/Dockerfile-slave \
             --build-arg REDIS_MASTER_HOST=ip-or-name \
             --build-arg REDIS_MASTER_AUTH=password .
```

!!! note

    If you pulled from dockerhub (or wherever) then you will need to change
    the tag name to suserichiejp/jdp:latest (or whatever).

Then run it
```sh
docker run -it -p 8889:8889 jdp:latest
```

With a bit of luck you will see a message from Jupyter describing what to do
next.

By default JDP will create a local Redis instance automatically inside the
container. Redis will save its data within the Docker volume
`/home/jdp/data`. Unless you mount this volume your data cache is likely to
get deleted. It is also possible to configure JDP to connect to an existing
Redis server; see `conf/data.toml` and `install/Dockerfile-production`.

You can use the Docker image for developing JDP itself by mounting the
`/home/jdp/src` volume.

## Git (from source)

Installing from source should be fairly easy, it just requires a few none
Julia based dependencies. What you need depends on the trackers you intend to
use and whether you want to use Jupyter.

!!! tip

	You can also use `install/Dockerfile(-base)` as a guide. Also check
	`conf/*.toml`.

You must install Redis unless you provide a remote Redis address in
`conf/data.toml`.

Generally speaking, if you want to use Jupyter 'notebooks', then you should
install Jupyter notebook and client packages. However there are alternatives
to Jupyter client, which may also load and edit Jupyter notebooks.

Also install the latest stable release of Julia. JDP currently bundles an
'upstream' version of Julia in the `install` directory. You will probably have
difficulties using your distribution's Julia version.

If you wish to use the OpenQA integration then install `openQA-client`. Same
goes for `mailx`.

Finally, if you installed Jupyter or equivalent, run `julia
install/install.jl` to setup `IJulia`. Otherwise this is not necessary.

# Usage

## With Jupyter

If you are using the Docker image then just browse to
[localhost:8889](http://localhost:8889). If not then run `jupyter notebook` in
the JDP directory.

Open either the `notebooks/Report-Status-Diff.ipynb` or `notebooks/Propagate
Bug Tags.ipynb` Jupyter notebooks which are (hopefully) self documenting. I
have only tested them with Jupyter itself, but there are fancier alternatives
such as JupyterLab.

## Other

You can also use the library from a Julia REPL or another project. For example
in a julia REPL you could run

```julia
include("src/init.jl")

using JDP: Repository, Trackers.OpenQA, ... etc.
```

Also the `run` directory contains scripts which are intended to automate
various tasks. These can be executed with Julia in a similar way to `julia
run/all.jl`.

## Automation

JDP is automated using SUSE's internal Gitlab CI instance. Which automates
building and testing the containers as well as deployment and the execution of
various scripts/services. See `install/gitlab-ci.*`.

There is also a [public pipeline](https://gitlab.com/Palethorpe/jdp/pipelines)
on GitLab.com, which publishes the public [documentation and
reports](https://palethorpe.gitlab.io/jdp/).

# Documentation

Further documentation can be found at
[palethorpe.gitlab.io/jdp](https://palethorpe.gitlab.io/jdp) or
[rpalethorpe.io.suse.de/jdp](https://rpalethorpe.io.suse.de/jdp)

You can also find documentation at the Julia REPL by typing `?` followed by an
identifier or in a notebook you can type `@doc identifier` in a code cell.

The following image may give you some intuition for what JDP is.

![Outer Architecture](outer_arch.svg)

# Contributors

Created and maintained by Richard Palethorpe (rpalethorpe@suse.com). Sebastian
Chlad (schlad@suse.com) is mainly responsible for it being a serious (I hope)
project.

Cyril has been asking for a result difference view and matrix for years.

## Ideas and feedback

Because it is not obvious who has contributed non-code or documentation
changes I will try to make a list. Please let me know if I have missed you
out or want to be removed.

* Sebastian Chlad
* Cyril Chrubis
* Yong Sun
* Anton Smorodskyi
* Sergio Lindo
* Petr Vorel
* Oliver Kurz
* Clemans Famulla-Conrad
* Jose Lausuch
* Petr Cervinka

## Code and documentation

See the github/lab stats.

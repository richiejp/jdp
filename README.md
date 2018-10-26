# Work in progress...

If you are feeling brave and want to try this out, then install the *official*
Julia 1.0 distro (SUSE's won't work because of some wierd issue with compiling
a maths library) somewhere in your path. Then see `src/startup.jl` for using
JDP from a REPL and `src/notebook.jl` for using it with Jupyter (recommended)
or try running the tests (I have no idea why you would want to do that, but it
is something you can do).

You will need to get the data from OpenQA somehow. This is possible by
following the instructions in `src/report.ipynb`, but I would advise against
downloading too many builds/results because you will die of old age before it
finishes. In the future we will create a central data cache to take the load
off OpenQA.

Note that if you have Jupyter installed you can probably view
`src/report.ipynb` without doing any other setup. You just won't be able to
rerun the code snippets.

# Install

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

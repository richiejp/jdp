#!BuildTag: JDP
FROM opensuse/tumbleweed:latest

LABEL name=jdp maintainer=rpalethorpe@suse.com description="JDP project with Jupyter"

ARG juliav=1.0.1
ARG tarurl=https://julialang-s3.julialang.org/bin/linux/x64/1.0/julia-${juliav}-linux-x86_64.tar.gz

# TODO: We should really install the official SUSE Julia package now, but some 3rd
# numerical libraries have compilation issues with other libraries and... well
# we just install from tar ball for now.
# RUN zypper in julia
RUN zypper in -y curl tar gzip bzip2 \
python3-jupyter python3-jupyter_nbconvert python3-jupyter_client \
python3-jupyter_notebook && \
zypper clean --all

# There is no default non-root user in the Tumbleweed image, so we create one
# because doing everything as root unecessarily is probably immoral or something
RUN useradd -m -g users jdp

# CD to the new user's home directory
WORKDIR /home/jdp

# Copy the whole project into the container
COPY --chown=jdp:users ./ ./src

# su jdp
USER jdp
# Put the user's bin dir in the path so that we do not have to touch any system files
ENV PATH=/home/jdp/bin:${PATH}

# Install julia from the official tarball. Obviously this is very naughty and should be
# replaced with the Julia package at some point
RUN mkdir julia
ADD --chown=jdp:users $tarurl julia/julia.tar.gz
RUN cd julia &&\
    tar -xzf julia.tar.gz &&\
    ln -s ../julia/julia-$juliav/bin/julia ~/bin/julia &&\
    rm julia.tar.gz

# Precompile and test JDP, plus ensure IJulia is registered with Jupyter
RUN ["julia", "src/src/install.jl"]

# Make the data and source folders accessible outside the container
RUN mkdir data
VOLUME [ "/home/jdp/data", "/home/jdp/src" ]

# Jupyter listens on port 8888 by default, but we will listen on port 8889
# so as not to conflict with an existing Jupyter installation
EXPOSE 8889

# Default command starts Jupyter in the directory where the notebooks are
WORKDIR /home/jdp/src/src
CMD [ "jupyter", "notebook", "--ip=0.0.0.0", "--port=8889" ]
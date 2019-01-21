#!BuildTag: JDP
FROM opensuse/tumbleweed:latest

LABEL name=jdp maintainer=rpalethorpe@suse.com description="JDP project with Jupyter"

ARG juliav=1.0.1
ARG tarurl=https://julialang-s3.julialang.org/bin/linux/x64/1.0/julia-${juliav}-linux-x86_64.tar.gz

RUN zypper in -y curl tar gzip bzip2 \
python3-jupyter python3-jupyter_nbconvert python3-jupyter_client \
python3-jupyter_notebook && \
julia && \
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

# Precompile and test JDP, plus ensure IJulia is registered with Jupyter
RUN ["julia", "src/src/install.jl"]

# Make the data and source folders accessible outside the container
RUN mkdir data
VOLUME [ "/home/jdp/data", "/home/jdp/src" ]

# Jupyter listens on port 8888 by default, but we will listen on port 8889
# so as not to conflict with an existing Jupyter installation
EXPOSE 8889

# Default command starts Jupyter in the directory where the notebooks are
WORKDIR /home/jdp/src/notebooks
CMD [ "jupyter", "notebook", "--ip=0.0.0.0", "--port=8889" ]

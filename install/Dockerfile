#!BuildTag: JDP
FROM jdp-base:latest

LABEL name=jdp maintainer=rpalethorpe@suse.com description="JDP project with Jupyter"

WORKDIR /home/jdp

# Refresh the project source
RUN rm -rf src
COPY --chown=jdp:users ./ ./src

# Precompile and test JDP, plus ensure IJulia is registered with Jupyter
RUN ["julia", "--color=yes", "src/install/install.jl"]

# Make the data and source folders accessible outside the container
VOLUME [ "/home/jdp/data", "/home/jdp/src", "/home/jdp/src/docs/build" ]

# Jupyter listens on port 8888 by default, but we will listen on port 8889
# so as not to conflict with an existing Jupyter installation
EXPOSE 8889

# Redis listens on this port by default. This is only used on master nodes.
EXPOSE 6379

# Default command starts Jupyter in the directory where the notebooks are
WORKDIR /home/jdp/src/notebooks
CMD [ "jupyter", "notebook", "--ip=0.0.0.0", "--port=8889" ]

# GitLab-CI VM or baremetal config

Unfortunately this is not automated.

## Install SUSE and Docker (or podman/cri-o/runc/kubernetes/whatever)

1. Install SUSE Leap/Kubic/SLE
2. Install Docker or whatever
3. Install git-core

I will assume there is a user called 'opensuse' becaue this is the default
user in our cloud images on https://engcloud.prv.suse.net/ at the time of
writting.

### Docker setup

1. Add opensuse to docker group: `usermod -aG docker opensuse`
2. Enable and start docker service.

## Install gitlab-ci runner

Follow instructions here:
https://docs.gitlab.com/runner/install/linux-manually.html

But:
1. Use opensuse user with install command
2. Allow root to find it with
   `sudo ln -s /usr/sbin/gitlab-runner /usr/local/bin/gitlab-runner`

## Configure runner

Where appropriate follow the instructions here for the shell runner:
https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-shell-executor



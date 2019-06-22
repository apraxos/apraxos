FROM debian:stable

MAINTAINER Derk Muenchhausen <derk@muenchhausen.de>

RUN apt-get update && apt-get install -y \
  rsync

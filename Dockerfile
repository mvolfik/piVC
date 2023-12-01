FROM python:3.12-bookworm

WORKDIR /piVC
RUN apt update && apt install -y --no-install-recommends ocaml openjdk-17-jdk-headless && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir z3-solver==4.12.2
COPY src src
RUN cd src && make
COPY conf conf
COPY include include
RUN mkdir log

ARG APP_DIR="/app"
ARG APP_VENV="/opt/venv"

# Build image
FROM python:3.9-alpine as build

ARG APP_DIR
ARG APP_VENV

RUN apk add --no-cache \
    autoconf \
    automake \
    build-base \
    cmake \
    g++ \
    libexecinfo-dev \
    libffi-dev \
    libtool \
    libxml2-dev \
    libxslt-dev \
    make

RUN mkdir -p ${APP_DIR}
WORKDIR ${APP_DIR}

RUN python -m venv ${APP_VENV}
ENV PATH="${APP_VENV}/bin:$PATH"

RUN pip install awslambdaric
COPY main.py ${APP_DIR}

# Lambda image
FROM python:3.9-alpine as lambda

ARG APP_DIR
ARG APP_VENV
ENV PATH="${APP_VENV}/bin:$PATH"

WORKDIR ${APP_DIR}

COPY --from=build ${APP_DIR} ${APP_DIR}
COPY --from=build ${APP_VENV} ${APP_VENV}

ENTRYPOINT [ "python", "-m", "awslambdaric" ]
CMD [ "main.handler" ]

FROM python:2.7.14-jessie
MAINTAINER cheryl.chiu

WORKDIR /usr/src/app

RUN apt-get update
RUN apt-get install jq


#COPY requirements.txt ./
ADD ./ ./
RUN pip install --no-cache-dir -r requirements.txt

ENV TERRAFORM_VERSION=0.10.8
ENV TERRAFORM_SHA256SUM=f991039e3822f10d6e05eabf77c9f31f3831149b52ed030775b6ec5195380999

RUN apt-get install -y git curl openssh-server unzip && \
    curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip > terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    echo "${TERRAFORM_SHA256SUM}  terraform_${TERRAFORM_VERSION}_linux_amd64.zip" > terraform_${TERRAFORM_VERSION}_SHA256SUMS && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /bin && \
    rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip
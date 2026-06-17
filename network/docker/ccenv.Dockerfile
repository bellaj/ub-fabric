# Custom chaincode builder for arm64: vendored Fabric chaincode needs libltdl headers.
FROM hyperledger/fabric-ccenv:2.5
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libltdl-dev \
    && rm -rf /var/lib/apt/lists/*
USER chaincode

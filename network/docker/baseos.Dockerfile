# Chaincode runtime image with libltdl for pkcs11-linked chaincode.
FROM hyperledger/fabric-baseos:2.5
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libltdl7 \
    && rm -rf /var/lib/apt/lists/*
USER chaincode

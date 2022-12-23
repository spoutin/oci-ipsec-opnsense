FROM python:3.11
ENV OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=true
WORKDIR /app

RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install oci-cli

RUN apt-get update && apt-get install -y jq

RUN useradd -m -d /app/ -s /bin/bash appuser

COPY src ./
COPY requirements.txt ./
RUN chown -R appuser:appuser /app

USER appuser
RUN chmod u+x entrypoint.sh && python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt && rm -f requirements.txt

EXPOSE 8888
ENTRYPOINT [ "./entrypoint.sh" ]
CMD python main.py

# dbt + Dagster in one small image. `dagster dev` runs the web UI and the scheduler in one process,
# which is enough for a single machine (production: see notebooks/04_architecture_and_automation.md).
#
# Build and run from the repository root:
#   docker build -f orchestration/Dockerfile -t lead-conversions .
#   docker run -p 3000:3000 lead-conversions        # then open http://localhost:3000

FROM python:3.13-slim

WORKDIR /app
ENV DAGSTER_HOME=/app/.dagster \
    PYTHONUNBUFFERED=1

COPY orchestration/requirements.txt orchestration/requirements.txt
RUN pip install --no-cache-dir -r orchestration/requirements.txt

COPY dbt/ dbt/
COPY orchestration/ orchestration/
# The CSV exports stand in for the source system; in production they would arrive in a mounted volume.
COPY data/raw/ data/raw/

# Install the dbt packages and parse the project, so the image ships with the manifest Dagster reads.
RUN cd dbt && dbt deps && dbt parse && mkdir -p "$DAGSTER_HOME"

EXPOSE 3000
CMD ["dagster", "dev", "--host", "0.0.0.0", "--port", "3000", "-m", "orchestration.definitions"]

"""Dagster orchestration of the dbt pipeline (Task 4).

Every dbt model and snapshot becomes a Dagster asset, every dbt test an asset check. One job runs
`dbt build` once a day; failed steps are retried, and a run that still fails is reported.

Run locally (from the repository root):  dagster dev -m orchestration.definitions
"""

from pathlib import Path

import dagster as dg
from dagster_dbt import DbtCliResource, DbtProject, build_schedule_from_dbt_selection, dbt_assets

DBT_PROJECT_DIR = Path(__file__).resolve().parent.parent / "dbt"

dbt_project = DbtProject(project_dir=DBT_PROJECT_DIR, profiles_dir=DBT_PROJECT_DIR)
# Under `dagster dev` this parses the dbt project; the Docker image parses it at build time instead.
dbt_project.prepare_if_dev()


@dbt_assets(
    manifest=dbt_project.manifest_path,
    # Transient problems (an export that arrives late, a locked database file) get two more tries,
    # 5 and 10 minutes later. A failing data test fails again and is then reported.
    retry_policy=dg.RetryPolicy(max_retries=2, delay=300, backoff=dg.Backoff.EXPONENTIAL),
)
def lead_conversions_dbt(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    # dbt build runs models, snapshots and tests in dependency order. A test with severity error
    # stops everything downstream of it, so the marts keep yesterday's correct data instead of
    # today's wrong data. The row counts are stored with each run, so a sudden drop stands out.
    yield from dbt.cli(["build"], context=context).stream().fetch_row_counts()


daily_build = build_schedule_from_dbt_selection(
    [lead_conversions_dbt],
    job_name="daily_dbt_build",
    cron_schedule="0 6 * * *",  # after the nightly export of the source system
    execution_timezone="Europe/Vienna",
)


@dg.run_failure_sensor
def report_failed_run(context: dg.RunFailureSensorContext) -> None:
    """Reports every failed run. In production this posts to the data team's Slack channel or
    sends an e-mail (e.g. with dagster-slack); here it writes an error to the Dagster log."""
    context.log.error(
        f"Run {context.dagster_run.run_id} of job {context.dagster_run.job_name} failed: "
        f"{context.failure_event.message}"
    )


defs = dg.Definitions(
    assets=[lead_conversions_dbt],
    schedules=[daily_build],
    sensors=[report_failed_run],
    resources={"dbt": DbtCliResource(project_dir=dbt_project)},
)
